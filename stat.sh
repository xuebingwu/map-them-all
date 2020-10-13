cd /home/local/ARCS/xw2629/xuebing/SRA
# check progress
echo $(ls downloading | wc -l) downloading
echo $(ls downloaded | wc -l) downloaded
echo $(find mapped/  -mtime 0 | wc -l) proccessed in past 24hrs

echo $(find mapped/ | wc -l) processed in total

# mapped=$(ls -lt mapped/*out | sed 's/ \+/ /g' | grep "$(date | sed 's/ \+/ /g' | cut -d' ' -f 2,3)" | wc -l) 

# processed=$(ls -lt mapped/*out small fail* | sed 's/ \+/ /g' | grep "$(date | sed 's/ \+/ /g' | cut -d' ' -f 2,3)" | wc -l)

# echo $mapped mapped today
# echo $processed processed today

# hour=$(date | sed 's/ \+/ /g' | sed 's/:/ /g' | cut -d' '  -f 4)
# minute=$(date | sed 's/ \+/ /g' | sed 's/:/ /g' | cut -d' '  -f 5)
# echo $(calc $(echo "$mapped/($hour+$minute/60.0)*24")) to be mapped today
# echo $(calc $(echo "$processed/($hour+$minute/60.0)*24")) to be processed today

# echo $(ls -lt mapped/*out | wc -l) mapped total
# echo $(ls mapped/*.out small fail* | wc -l) processed total

echo $(df | grep ubuntu | cut -d' ' -f 6-) space used
