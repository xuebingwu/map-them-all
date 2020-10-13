cd /home/local/ARCS/xw2629/xuebing/map-them-all
for i in {6..10}
do
    echo $i

     ./sra_download.sh -id_list cancer_tumor_sars_virus_infection.txt -output ../SRA -num_file $i &

     sleep 1s

     #./sra_map.sh ../SRA 10.115.56.200 xw2629 wulab@CUMC2018 &

done

# to terminate
# pkill sra_download.sh
# pkill sra_map.sh
