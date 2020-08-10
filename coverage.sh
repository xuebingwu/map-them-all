# script to get coverage of RAIL

# ./coverage.sh ../SRA/mapped RAIL RAIL.coverage

folder=$1
gene=$2
output=$3

files=`ls $folder/*.coverage.gz`

touch $output.tmp
for file in $files
do
   filename=$(basename $file)
   echo $filename $(zcat $file | grep $gene | cut -f 2-) >> $output.tmp
done
sort -grk 2 $output.tmp > $output
rm $output.tmp