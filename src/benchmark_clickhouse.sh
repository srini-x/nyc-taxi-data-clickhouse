#!/usr/bin/env bash

queries=(
"SELECT cab_type, count(*) FROM trips_mergetree GROUP BY cab_type"
"SELECT passenger_count, avg(total_amount) FROM trips_mergetree GROUP BY passenger_count"
"SELECT passenger_count, toYear(pickup_date) AS year, count(*) \
FROM trips_mergetree \
GROUP BY passenger_count, year"
"SELECT passenger_count, toYear(pickup_date) AS year, \
round(trip_distance) AS distance, count(*) \
FROM trips_mergetree \
GROUP BY passenger_count, year, distance \
ORDER BY year, count(*) DESC"
)

script_dir=$(dirname $(readlink -f $0))
log_dir="${script_dir}/../bm_logs"
mkdir -p "${log_dir}"
num_repeats=${1:-1}
log_name="${log_dir}/clickhouse_bm_${num_repeats}r_$(date +%F_%H-%M-%S).log"

printf "\nBenchmarking ClickHouse ...\n\n"

for query in "${queries[@]}"; do
    printf "%s\n\n" "$query"
    sudo perf stat -r "${num_repeats}" -o "${log_name}" --append clickhouse-client --query="${query}" > /dev/null
done
