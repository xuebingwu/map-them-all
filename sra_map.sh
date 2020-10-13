#!/bin/bash

# usage: ./sra_map.sh ../SRA IP username password

STAR_options="--runThreadN 4 --genomeLoad LoadAndKeep --limitBAMsortRAM 20000000000 --genomeDir /home/local/ARCS/xw2629/genomes/indexes/STAR/hg38 --outSAMtype BAM SortedByCoordinate --outWigType wiggle read1_5p --outFilterType BySJout --outFilterMultimapNmax 20 --alignSJoverhangMin 8 --alignSJDBoverhangMin 1 --outFilterMismatchNmax 999 --outFilterMismatchNoverReadLmax 0.04 --alignIntronMin 20 --alignIntronMax 1000000 --alignMatesGapMax 1000000"

chrsize=/home/local/ARCS/xw2629/genomes/sequences/hg38.chrom.sizes
bed_plus="/home/local/ARCS/xw2629/genomes/annotations/hg38refseq.processed+.bed"
bed_minus="/home/local/ARCS/xw2629/genomes/annotations/hg38refseq.processed-.bed"

# min uniquely mapped reads
minRead=5000000


# min number of lines in fastq file, divided by 4 is the number of reads
min_line=40000000

folder=$(realpath $1)
cd $folder
mkdir mapped

ip=$2
user=$3
pass=$4

while [ 1 ]
do
   # if no fastq file available
   if [ ! "$(ls -A downloaded)" ];then
       sleep $[ ( $RANDOM % 100 )  + 600 ]s
       if [ ! "$(ls -A downloading)" ];then # if no files being downloaded, stop
           echo [`date`]  "no fastq files. exit"
           exit
       fi
   fi

   fastq_files=`ls downloaded/*.fastq`

   # to avoid multiple threads working on the same file
   sleep .$[ ( $RANDOM % 10000 )  + 1 ]s

   for input in $fastq_files
   do 
      sample=$(echo $input | cut -d'/' -f 2 | cut -d '_' -f 1)
      if [ -d $sample ]; then # another STAR is processing the same file
              echo "$sample folder exist, may be another STAR is processing this file. skip "
              continue
      fi

      echo [`date`]  "mapping $sample"
      mkdir $sample
      mv $input $sample/input.fastq
      cd $sample

      nline=$(wc -l < input.fastq) 

      if [ $nline -lt $min_line ]
      then
	      echo [`date`]  "$sample has too few reads: " $nline
	      cd ..
	      rm -rf $sample
	      break
      fi

      STAR $STAR_options --readFilesIn input.fastq --outFileNamePrefix $sample.
      wigToBigWig $sample.Signal.UniqueMultiple.str1.out.wig $chrsize $sample.-.bw
      wigToBigWig $sample.Signal.UniqueMultiple.str2.out.wig $chrsize $sample.+.bw
      gzip $sample.SJ.out.tab --force

      # get number of uniquely mapped reads
      uniqReads=$(more $sample.Log.final.out | grep "Uniquely mapped reads number" | cut -f 2)
      if [ $uniqReads -lt $minRead ];then
        echo [`date`]  "$sample: not enough reads: $uniqReads"
      else
        echo [`date`]  "$sample: computing coverage"
        bigWigDensity $sample.+.bw $sample.-.bw $bed_plus $bed_minus $sample
        gzip $sample.coverage --force
      fi

      # if remote server info is not provided
      if [ -z $ip ] || [ -z $user ] || [ -z $pass ]; then
          mv $sample.?.bw $sample.Log.final.out $sample.SJ.out.tab.gz $sample.coverage.gz  ../mapped
      else
          # send data to remote server. if failed, save locally
          for file in $sample.?.bw $sample.Log.final.out $sample.SJ.out.tab.gz $sample.coverage.gz
          do
              sshpass -p "$pass" scp $file $user@$ip:~/SRA/mapped
              if [ $? == "1" ];then
                  mv $file ../mapped
                  echo [`date`]  "failed to transfer file $file to remote server"
              else
                  echo [`date`]  "$file transferred to remoter server"
              fi
          done
          mv $sample.Log.final.out ../mapped
      fi
      
      cd ..
      rm -rf $sample
      break # update file list
   done
done
