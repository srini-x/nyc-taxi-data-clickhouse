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

printf  "Benchmarking ClickHouse ...\n\n"

for query in "${queries[@]}"; do
    printf "\n%s\n\n" "$query"
    sudo perf stat -r 10 clickhouse-client --query="$query" > /dev/null
done

# printf  "Benchmarking PostgreSQL ...\n\n"
# printf  "SELECT cab_type_id, count(*) FROM trips GROUP BY cab_type_id\n\n"
# sudo perf stat -r 2 sudo su - postgres -c 'psql "nyc-taxi-data" -c "SELECT cab_type_id, count(*) FROM trips GROUP BY cab_type_id"'
