# script to get summary of all transcripts

bw_folder="/home/local/ARCS/xw2629/xuebing/SRA/mapped"
bed_plus="/home/local/ARCS/xw2629/genomes/annotations/hg38refseq.processed+.bed"
bed_minus="/home/local/ARCS/xw2629/genomes/annotations/hg38refseq.processed-.bed"

minRead=5000000

cd $bw_folder 

bw_files=`ls *.+.bw`

for file in $bw_files
do	
   filename=$(basename $file)
   sraid=$(echo $filename | cut -d'.' -f 1)

   if [ -f $sraid.coverage ]; then
     echo "skip $sraid"
     continue
   fi

   #check if both +/- strand bigwig files are available
   if [ ! -f $bw_folder/$sraid.-.bw ];then
      echo "missing $bw_folder/$sraid.-.bw"
      continue
   fi

   # get number of uniquely mapped reads
   uniqReads=$(more $sraid.Log.final.out | grep "Uniquely mapped reads number" | cut -f 2)
   if [ $uniqReads -lt $minRead ];then
	echo "$sraid: not enough reads: $uniqReads"
	continue
   fi

   echo "$sraid: computing coverage"
   bigWigDensity $sraid.+.bw $sraid.-.bw $bed_plus $bed_minus $sraid
done
