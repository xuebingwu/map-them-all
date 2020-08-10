# script to get summary of an input interval

#
# ./query.sh ./ newlinc.bed

bw_file_folder=$1
interval=$2

bw_files=`ls $bw_file_folder/*.bw`

for file in $bw_files
do
   filename=$(basename $file)
   bigWigAverageOverBed $file $interval $sample.tmp
   echo $filename $(cat $sample.tmp | cut -f 4)
   rm $sample.tmp
done
