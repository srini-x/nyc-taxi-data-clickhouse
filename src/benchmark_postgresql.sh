#!/usr/bin/env bash

script_dir=$(dirname $(readlink -f $0))
log_dir="${script_dir}/../bm_logs"
mkdir -p "${log_dir}"
num_repeats=${1:-1}
log_name="${log_dir}/postgresql_bm_${num_repeats}r_$(date +%F_%H-%M-%S).log"

printf  "Benchmarking PostgreSQL ...\n\n"

printf  "SELECT cab_type_id, count(*) FROM trips GROUP BY cab_type_id\n\n"
sudo perf stat -r "${num_repeats}" -o "${log_name}" --append sudo su - postgres -c 'psql "nyc-taxi-data" -c "SELECT cab_type_id, count(*) FROM trips GROUP BY cab_type_id"' > /dev/null
