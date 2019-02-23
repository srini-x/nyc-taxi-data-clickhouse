#!/usr/bin/env bash

log_dir='../bm_logs'
script_dir='bm_scripts'

# stop postgreSQL if running
sudo systemctl stop postgresql

# wait 5 sec
sleep 5

clickhouse_benchmarks=(
    "benchmark_clickhouse"
)

# create logs dir if it doesn't exist
mkdir -p "${log_dir}"

for bm_script in "${clickhouse_benchmarks[@]}"; do
    printf "\nRunning %s ...\n\n" "$bm_script"
    log_name="${log_dir}/${bm_script}_$(date +%F_%H-%M-%S).log"
    bash "${script_dir}/${bm_script}.sh" 2>&1 | tee ${log_name}
done
