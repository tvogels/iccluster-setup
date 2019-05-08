#!/bin/bash

# script_path=/mlodata1/gpu-monitor/scripts
script_path=$(dirname "$0")
data_path=/mlodata1/gpu-monitor/data

mkdir -p $data_path

if [ "$1" -eq "1" ]; then
    nvidia-smi --format=csv,noheader,nounits --query-gpu=index,uuid,name,memory.used,memory.total,utilization.gpu,utilization.memory,temperature.gpu,timestamp -l 20 > $data_path/${HOST}_gpus.pre
fi

if [ "$1" -eq "2" ]; then
    nvidia-smi --format=csv,noheader,nounits --query-compute-apps=timestamp,gpu_uuid,used_gpu_memory,process_name,pid -l 20 > $data_path/${HOST}_processes.pre
fi

if [ "$1" -eq "3" ]; then
    while true; do
        df | grep "/dev/sda1" > $data_path/${HOST}_status.csv
        free -m | grep "Mem" >> $data_path/${HOST}_status.csv
		#top -b -n 1 | grep %Cpu >> $data_path/${HOST}_status.csv
		ps -A -o pcpu | tail -n+2 | paste -sd+ | bc >> $data_path/${HOST}_status.csv
		nproc >> $data_path/${HOST}_status.csv

        python $script_path/gpu-processes.py $data_path/${HOST}_processes.pre > $data_path/${HOST}_users.csv
        echo $(uptime | grep -o -P ': \K[0-9]*[,]?[0-9]*')\;$(nproc) > $data_path/${HOST}_cpus.csv
        tail -n 20 $data_path/${HOST}_gpus.pre > $data_path/${HOST}_gpus.csv
        tail -n 40 $data_path/${HOST}_processes.pre > $data_path/${HOST}_processes.csv

        sleep 10
   done
fi
