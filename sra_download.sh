#!/bin/bash

# script to download all RNA-seq data in SRA as of 7/17/2020
# one file a time, once completed, move the fastq file to ./downloaded
# which will be mapped by another script sra2bw_fast
# when processed (bigwig file, junciton file, and log), remove the fastq file
# pause downloading if there are >10 downloaded fastq files to be processed
# only use the first 40 million reads of each data, minimum 10 million reads

# required tools: 
# sra-tools: sra-stat, prefetch, fastq-dump, 

# usage: sra_download.sh acc_list_file [options]

help () {
 echo ""
 echo "Usage: sra_download.sh -id_list acc_list_file [options]"
 echo ""
 echo "Input:"
 echo "    -id_list        A text file with each line being a SRA ID (SRR****)"
 echo "Options:"
 echo "    -output <folder>   Output path/folder name. Default: SRA"
 echo "    -thread <N>     Number of threads for parallel-fastq-dump. Default: 1"
 echo "    -max_read <N>   The max number of reads to download. Default: 40000000"
 echo "                    The rest of the reads in the data set will be skipped" 
 echo "    -min_read <N>   Skip a data set if too few reads. Default: 10000000"
 echo "    -disk_space <N> Max disk space (KB) for fastq files (default: 0)"
 echo "    -num_file <N>   Max num of fastq files to store (default: 10)"
 echo "                    Downloading will pause when both -disk_space and -num_file"
 echo "                    exceed the limit."
 echo ""
 echo "Output:"
 echo "    downloaded      Fastq files that have been downloaded"
 echo "    small	       Empty files of SRA IDs with too few reads (< min_read)"
 echo "    fail_download   Empty files of SRA IDs with too large *.sra files"
 echo ""
 echo "Required to run:"
 echo "    sra-tools (sra-stat, prefetch, fastq-dump)"
 echo ""
 echo "Example:"
 echo "    sra_download.sh -id_list acc_list_file -output ../SRA -num_file 10"
}

input=""
thread="1"
output="SRA"
min_read=10000000
max_read=40000000
disk_space=0 #50000000 # set small number to inactivate this parameter
num_file=10

# parse commandline arguments
while [ $# -gt 0 ]
do
    case "$1" in
	-id_list) input="$2"; shift;;
        -thread) thread="$2"; shift;;
        -max_read) max_read="$2"; shift;;
        -min_read) min_read="$2"; shift;;
        -disk_space) disk_space=$2; shift;;
        -output) output=$2; shift;;
        -num_file) num_file=$2; shift;;
        -h) help;exit 0;;
        --help) help;exit 0;;
	--) shift; break;;
	-*)
	    echo [`date`] '';echo [`date`]  "****** unknown option: $1 ******";echo ''; 1>&2; help; exit 1;;
	*)  break;;	# terminate while loop
    esac
    shift
done

if [ -z "$input" ];then
	echo [`date`] "ERROR: -id_list file required"
	help
	exit 
elif [ ! -f "$input" ];then
	echo [`date`] "The SRA ID list file does not exist: " $input
	exit
fi

# all RNA-seq data ID (SRR***) as of 7/17
# access: public; source:RNA; platform:illumina, filetype: fastq
# input="SraAccList.txt"

# to maximize diversity at the begining, shuffle the data
#shuf SraAccList.txt > SraAccList_shuffled.txt
# input="SraAccList_shuffled.txt"

input=$(realpath $input) #

output=$(realpath $output)

mkdir $output
cd $output

mkdir downloading # fastq files being downloaded
mkdir downloaded # fastq files

# each line is an SRA ID
while IFS= read -r sra_id
do

	    # if more than 10 files in the queue
    while [ $(du downloaded | cut -f 1) -ge $disk_space ] && [ $(ls downloaded | wc -l) -gt $num_file ]
    do
        # to avoid multiple threads working on the same file
        sleep .$[ ( $RANDOM % 10000 )  + 1 ]s
    done

    	# this is needed because sra file transfer frequently stopped
    if [ $(ls ~/ncbi/public/sra | grep ".sra.lock" | wc -l) -gt 0 ]; then 
        rm ~/ncbi/public/sra/*.sra.lock
    fi

    if [ $(du ~/ncbi/public/sra/ | cut -f 1) -ge $disk_space ];then
        if [ $(ls ~/ncbi/public/sra | grep ".sra.cache" | wc -l) -gt 0 ]; then 
            rm ~/ncbi/public/sra/*.sra.cache
        fi
        find ~/ncbi/public/sra/* -mtime +1 -exec rm {} \; # remove any file older than 1 day
        # note that some sra files can be years old even if just downloaded 
    fi

    # if another thread already started 
    if [ -f downloading/$sra_id ];then
        continue
    fi
  
    # this marks a thread has started downloading the data
    touch downloading/$sra_id
  
    # if already processed (if this script was aborted and started again)
    if [ -f "mapped/$sra_id.Log.final.out" ] || [ -f "mapped/$sra_id.small" ] || [ -f "mapped/$sra_id.failed" ] || [ -d $sra_id ] || [ -f downloaded/$sra_id\_1.fastq ] ;then
        echo [`date`] "$sra_id already processed. skipping"
        rm downloading/$sra_id
        continue
    fi

    echo [`date`] $sra_id ": checking total number of reads/spots"
    # note there might be error here if sra-stat failed
    num_spot=$(sra-stat --meta --quick $sra_id | cut -d'|' -f 3 | cut -d':' -f 1 | awk '{s+=$1} END {print s}')

    if [ $num_spot -lt $min_read ];then
        echo [`date`] "$sra_id has too few reads: " $num_spot
        rm downloading/$sra_id
        touch mapped/$sra_id.small
        continue
    fi

    echo [`date`] "prefetch $sra_id" 
    prefetch $sra_id
    # note here that if the sra file is too large, it will not be downloaded and will show up in failed_download

    if [ -f ~/ncbi/public/sra/$sra_id.sra ]; then
        # convert to fastq using multi thread. fasterqdump isn't working
        if [ $thread -gt 1 ]; then
            echo [`date`] "parallel-fastq-dump $sra_id"
            ~/software/parallel-fastq-dump/parallel-fastq-dump --sra-id $sra_id --threads $thread --split-files --maxSpotId $max_read
        else
            fastq-dump $sra_id --split-files --maxSpotId $max_read
        fi
      
        # move downloaded fastq file:
        if [ -f $sra_id\_1.fastq ] && [ -f $sra_id\_2.fastq ]; then # if paired end and both files exist, use the larger one
            size1=$(du $sra_id\_1.fastq| cut -f 1)
            size2=$(du $sra_id\_2.fastq| cut -f 1)
            if [ $size2 -gt $size1 ]; then
                mv $sra_id\_2.fastq $sra_id\_1.fastq
            fi
        elif [ -f $sra_id\_2.fastq ]; then # only _2 exists
            mv $sra_id\_2.fastq $sra_id\_1.fastq
        elif [ -f $sra_id.fastq ]; then
            mv $sra_id.fastq $sra_id\_1.fastq
        fi
    fi

    if [ -f $sra_id\_1.fastq ];then
        mv $sra_id\_1.fastq downloaded 
    else
        touch mapped/$sra_id.failed 
    fi

    # remove other files
    rm $sra_id*.fastq
    rm ~/ncbi/public/sra/$sra_id* 

    rm downloading/$sra_id

done < "$input"

