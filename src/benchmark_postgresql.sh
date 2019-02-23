#!/usr/bin/env bash

log_dir='../bm_logs'
mkdir -p "${log_dir}"
log_name="${log_dir}/clickhouse_bm_$(date +%F_%H-%M-%S).log"

printf  "Benchmarking PostgreSQL ...\n\n"

printf  "SELECT cab_type_id, count(*) FROM trips GROUP BY cab_type_id\n\n"
sudo perf stat -r 1 sudo su - postgres -c 'psql "nyc-taxi-data" -c "SELECT cab_type_id, count(*) FROM trips GROUP BY cab_type_id"' > /dev/null
