# use this script to move fastq files back to downloaded folder if STAR is killed
cd /home/local/ARCS/xw2629/xuebing/SRA
for dir in SRR* ERR*; do mv $dir/input.fastq downloaded/$dir\_1.fastq; rm -rf $dir; done
