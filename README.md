# Benchmarking ClickHouse using 1.1 Billion NYC Taxi Rides

This is an exercise to understand and benchmark [ClickHouse][clickhouse], an
open source column-oriented database by following the instructions of Mark
Litwintschik from his blog
 [1.1 Billion Taxi Rides on ClickHouse & an Intel Core i5][mark-clickhouse].

[![benchmark-video-thumb][benchmark-thumb]][benchmark-video]


## Table of Contents

- [System Setup](#system-setup)  
- [Before we begin](#before-we-begin)  
- [Obtaining Data](#obtaining-data)  
- [Create ClickHouse Database Using Raw Data](#create-clickhouse-database-using-raw-data)  
- [Benchmarking](#benchmarking)  
- [APPENDIX A: AWS EC2 Instance](#appendix-a-aws-ec2-instance)  
- [APPENDIX B: Use Prepared Partitions from ClickHouse](#appendix-b-use-prepared-partitions-from-clickhouse)


## System Setup

There are two options available here. Use a local machine or an AWS EC2
instance. I explored both options. AWS is more practical, easily available
and it is easy to reproduce the benchmark results.

In this case, AWS instance is still in the process of exporting data from
PostgreSQL. So, I am using the data from local machine. All the commands are
same except for the paths and small differences due to the use of different
versions of Ubuntu, 14.04 and 18.04.

Details of AWS instance are listed in the [APPENDIX A: AWS EC2 Instance](#appendix-a-aws-ec2-instance)
section.

### Local Desktop Configuration

I have a local desktop with the following settings. This is faster than what
Mark used to do his benchmark. So, it should work. I also have
sufficient space on the SSD to fit all the data.

**CPU**: Intel i7-7700 4.5 GHz  
**Memory**: 32GB  
**Storage**: SSD with read/write speeds > 500 MB/s  
**OS**: Ubuntu 18.04.2 LTS  
**Software**: PostgreSQL-10, Postgis-2.4, ClickHouse 19.3.4  


## Before we begin

Following are the things to know for anyone that is following Mark's guide and
new to installing and managing PostgreSQL.

### Time and Storage Expectations

Mark did a good job of setting the expectations on how much storage space we
need and how long it might take. Following is the summary of my experience.

#### Raw dataset

**Size**: 259GB  
**Time to Download**: ~3 hours  

#### PostgreSQL Database

**Size**: 348GB  
**Time to create**: ~21 hours

#### Compressed `csv` files exported from PostgreSQL database:

**Size**: 82GB  
**Time to create**: 2 hours 48 minutes

#### ClickHouse database

**Size**: 106GB  
**Time to create**: 4 hours 40 minutes

### PostgreSQL Setup Notes

The guide that I am following skips the PostgreSQL installation steps
because, it is mostly trivial. However, there are a few issues I ran into and
the following are the steps to follow to avoid them.

#### 1. Preparing the PGDATA partition

Large storage space for me is available on a separate partition both on local
machine and on AWS. On local machine, it is `/mnt/PGDATA` and on AWS it is
`/Data/PGDATA`.

1. Make `postgres` the owner of the `data_directory`.

```bash
$ cd /mnt
$ sudo chown -R postgres:postgres PGDATA
```

2. Make sure that the permissions of the `data_directory` are `700`.

```bash
$ cd /mnt
$ sudo chmod 700 PGDATA
```

#### 2. Modifying the PostgreSQL configuration file

PostgreSQL uses `/var/lib/postgresql/10/main/` as it's data store by default.
This will cause the root partition to get full and the `./import_trip_data.sh`
will abort due to lack of space on disk.

We need to change the configuration file located in `/etc/postgresql/10/main/postgresql.conf`
to tell PostgreSQL to use the newly created partition to store it's data.


1. Stop PostgreSQL service

```bash
$ sudo systemctl stop postgresql
```

2. Copy everything from default `data_directory` to the new one.

```bash
$ sudo cp -av /var/lib/postgresql/10/main/* /mnt/PGDATA/
```

3. Modify the configuration

```bash
$ sudo vim `/etc/postgresql/10/main/postgresql.conf`
```

From my `/etc/postgresql/10/main/postgresql.conf`

```
#------------------------------------------------------------------------------
# FILE LOCATIONS
#------------------------------------------------------------------------------

# The default values of these variables are driven from the -D command-line
# option or PGDATA environment variable, represented here as ConfigDir.

data_directory = '/mnt/PGDATA'          # use data in another directory
                                        # (change requires restart)
```

4. Start PostgreSQL

```bash
$ sudo systemctl start postgresql
```


## Obtaining Data

Raw New York taxi trip data is available from [NYC Taxi and Limousine
Commission][raw-nyc-data].

Todd Schneider provided detailed instructions on how to
[download and clean the raw data][toddwschneider-nyc-taxi-data] in his blog
post [Analyzing 1.1 Billion NYC Taxi and Uber Trips, with a Vengeance][toddwschneider-blog].

Mark Litwintschik used this data to benchmark Redshift. In his blog [A Billion
Taxi Rides in Redshift][mark-redshift], Mark detailed how to export all the 1.1
Billion rows from PostgreSQL into compressed `csv` files. Approximately 50 to 60
`gz` files of size 2GB each.

Later, Mark used the same dataset to benchmark ClickHouse in his blog [1.1
Billion Taxi Rides on ClickHouse & an Intel Core i5][mark-clickhouse]. This
same procedure is also available in the [ClickHouse
documentation][clickhouse-docs].

Data can also be obtained in the form of prepared partitions available from
ClickHouse. The instructions to obtain data in this form are available in the
[APPENDIX B: Use Prepared Partitions from ClickHouse](#appendix-b-use-prepared-partitions-from-clickhouse) section.

**Below are the steps I followed to create the ClickHouse database, starting
with raw data on the local machine**:

### 1. Clone `toddwschneider/nyc-taxi-data`

```bash
$ git clone https://github.com/toddwschneider/nyc-taxi-data.git
```

### 2. Download and clean the raw data

```bash
$ cd nyc-taxi-data
$ ./download_raw_data.sh && ./remove_bad_rows.sh
```

### 3. Assign permissions to Ubuntu user account to work on PostgreSQL.

Replace `<ubuntu-user>` below with your Ubuntu username.

```bash
$ sudo su - postgres -c \
    "psql -c 'CREATE USER <ubuntu-user>; ALTER USER <ubuntu-user> WITH SUPERUSER;'"
```

### 4. Initialize the PostgreSQL database and setup schema

```bash
$ ./initialize_database.sh
```

### 5. Import taxi and FHV data

```bash
$ ./import_trip_data.sh
$ ./import_fhv_trip_data.sh
```

This process is going to take more than a day. So, we can do the following to
monitor the progress.

#### Count number of rows in the table `trips` in PostgreSQL

1. Connect to PostgreSQL

```bash
$ psql -d "nyc-taxi-data"

nyc-taxi-data=#
```

2. Check the number of rows

```sql
nyc-taxi-data=# select * from pg_stat_user_tables where relname='trips';
```

Almost a billion rows added, ~500 million to go.

![lines-in-trips-img]


**Check the status of `./import_trip_data.sh`**

![import-script-progress-img]


### 6. Download and import 2014 Uber data

```bash
$ ./download_raw_2014_uber_data.sh
$ ./import_2014_uber_trip_data.sh
```

### 7. A look at tables in PostgreSQL after downloading and importing all the data

1. Connect to PostgreSQL

```bash
$ psql "nyc-taxi-data"
```

2. Execute the query below

```sql
SELECT relname table_name,
       lpad(to_char(reltuples, 'FM9,999,999,999'), 13) row_count
FROM pg_class
LEFT JOIN pg_namespace
    ON (pg_namespace.oid = pg_class.relnamespace)
WHERE nspname NOT IN ('pg_catalog', 'information_schema')
AND relkind = 'r'
ORDER BY reltuples DESC;
```

![postgre-tables][postgre-row-counts-img]

### 8. Exporting the Data

#### 1. Create a directory with the right permissions to export the data from PostgreSQL.

```bash
$ mkdir -p /mnt/Sata6/nyc-taxi-data-trips
$ sudo chown -R postgres:postgres /mnt/Sata6/nyc-taxi-data-trips
```

#### 2. Connect to PostgreSQL and start the export.

1. Connect to `nyc-taxi-data`

```bash
$ psql -d "nyc-taxi-data"
```

2. Start the export

The following command has been modified from [Mark's guide][mark-redshift] to account for the changes in
latest data. Columns `pickup` and `dropoff` from Mark's guide are replaced by
`pickup_location_id` and `dropoff_location_id` in the latest schema used to
create the trips table. Their datatypes also changed from `String` to `Int`.

This process will take ~3 hours.

```sql
nyc-taxi-data=# COPY (
    SELECT trips.id,
           trips.vendor_id,
           trips.pickup_datetime,
           trips.dropoff_datetime,
           trips.store_and_fwd_flag,
           trips.rate_code_id,
           trips.pickup_longitude,
           trips.pickup_latitude,
           trips.dropoff_longitude,
           trips.dropoff_latitude,
           trips.passenger_count,
           trips.trip_distance,
           trips.fare_amount,
           trips.extra,
           trips.mta_tax,
           trips.tip_amount,
           trips.tolls_amount,
           trips.ehail_fee,
           trips.improvement_surcharge,
           trips.total_amount,
           trips.payment_type,
           trips.trip_type,
           trips.pickup_location_id pickup,
           trips.dropoff_location_id dropoff,

           cab_types.type cab_type,

           weather.precipitation,
           weather.snow_depth,
           weather.snowfall,
           weather.max_temperature,
           weather.min_temperature,
           weather.average_wind_speed,

           pick_up.gid pickup_nyct2010_gid,
           pick_up.ctlabel pickup_ctlabel,
           pick_up.borocode pickup_borocode,
           pick_up.boroname pickup_boroname,
           pick_up.ct2010 pickup_ct2010,
           pick_up.boroct2010 pickup_boroct2010,
           pick_up.cdeligibil pickup_cdeligibil,
           pick_up.ntacode pickup_ntacode,
           pick_up.ntaname pickup_ntaname,
           pick_up.puma pickup_puma,

           drop_off.gid dropoff_nyct2010_gid,
           drop_off.ctlabel dropoff_ctlabel,
           drop_off.borocode dropoff_borocode,
           drop_off.boroname dropoff_boroname,
           drop_off.ct2010 dropoff_ct2010,
           drop_off.boroct2010 dropoff_boroct2010,
           drop_off.cdeligibil dropoff_cdeligibil,
           drop_off.ntacode dropoff_ntacode,
           drop_off.ntaname dropoff_ntaname,
           drop_off.puma dropoff_puma
    FROM trips
    LEFT JOIN cab_types
        ON trips.cab_type_id = cab_types.id
    LEFT JOIN central_park_weather_observations weather
        ON weather.date = trips.pickup_datetime::date
    LEFT JOIN nyct2010 pick_up
        ON pick_up.gid = trips.pickup_nyct2010_gid
    LEFT JOIN nyct2010 drop_off
        ON drop_off.gid = trips.dropoff_nyct2010_gid
) TO PROGRAM
    'split -l 20000000 --filter="gzip > /mnt/Sata6/nyc-taxi-data-trips/trips_\$FILE.csv.gz"'
    WITH CSV;
```


## Create ClickHouse Database Using Raw Data


### Installing and Configuring ClickHouse

Steps detailing the installation of ClickHouse are skipped here. Please follow the [instructions from
documentation](https://clickhouse.yandex/docs/en/getting_started/#from-deb-packages).

#### 1. Create a new `data_directory` for ClickHouse

```bash
$ mkdir -p /mnt/Sata7/clickhouse
$ sudo chown -R clickhouse:clickhouse /mnt/Sata7/clickhouse
$ sudo chmod 700 /mnt/Sata7/clickhouse
```

#### 2. Modify ClickHouse configuration file

```bash
$ sudo vim /etc/clickhouse-server/config.xml
```

Contents of my `/etc/clickhouse-server/config.xml`

```xml
    <!-- Path to data directory, with trailing slash. -->
    <path>/mnt/Sata7/clickhouse/</path>
```

#### 3. Start ClickHouse

**1. Start the clickhouse server**

```bash
$ sudo service clickhouse-server start
```
**2. Verify by launching the client**

```bash
$ clickhouse-client

ClickHouse client version 19.3.4.
Connecting to localhost:9000 as user default.
Connected to ClickHouse server version 19.3.4 revision 54415.

:)
```


### Create trips table in ClickHouse


#### 1. Connect to ClickHouse

```bash
$ clickhouse-client

ClickHouse client version 19.3.4.
Connecting to localhost:9000 as user default.
Connected to ClickHouse server version 19.3.4 revision 54415.

:)
```

#### 2. Create `trips` table.

```sql
CREATE TABLE trips (
    trip_id                 UInt32,
    vendor_id               String,

    pickup_datetime         DateTime,
    dropoff_datetime        Nullable(DateTime),

    store_and_fwd_flag      Nullable(FixedString(1)),
    rate_code_id            Nullable(UInt8),
    pickup_longitude        Nullable(Float64),
    pickup_latitude         Nullable(Float64),
    dropoff_longitude       Nullable(Float64),
    dropoff_latitude        Nullable(Float64),
    passenger_count         Nullable(UInt8),
    trip_distance           Nullable(Float64),
    fare_amount             Nullable(Float32),
    extra                   Nullable(Float32),
    mta_tax                 Nullable(Float32),
    tip_amount              Nullable(Float32),
    tolls_amount            Nullable(Float32),
    ehail_fee               Nullable(Float32),
    improvement_surcharge   Nullable(Float32),
    total_amount            Nullable(Float32),
    payment_type            Nullable(String),
    trip_type               Nullable(UInt8),
    pickup                  Nullable(UInt32),
    dropoff                 Nullable(UInt32),

    cab_type                Nullable(String),

    precipitation           Nullable(Float32),
    snow_depth              Nullable(Float32),
    snowfall                Nullable(Float32),
    max_temperature         Nullable(Int8),
    min_temperature         Nullable(Int8),
    average_wind_speed      Nullable(Float32),

    pickup_nyct2010_gid     Nullable(Int8),
    pickup_ctlabel          Nullable(String),
    pickup_borocode         Nullable(Int8),
    pickup_boroname         Nullable(String),
    pickup_ct2010           Nullable(String),
    pickup_boroct2010       Nullable(String),
    pickup_cdeligibil       Nullable(FixedString(1)),
    pickup_ntacode          Nullable(String),
    pickup_ntaname          Nullable(String),
    pickup_puma             Nullable(String),

    dropoff_nyct2010_gid    Nullable(UInt8),
    dropoff_ctlabel         Nullable(String),
    dropoff_borocode        Nullable(UInt8),
    dropoff_boroname        Nullable(String),
    dropoff_ct2010          Nullable(String),
    dropoff_boroct2010      Nullable(String),
    dropoff_cdeligibil      Nullable(String),
    dropoff_ntacode         Nullable(String),
    dropoff_ntaname         Nullable(String),
    dropoff_puma            Nullable(String)
) ENGINE = Log;
```

#### 3. Create `trans.py`

```python
#!/usr/bin/env python

import sys


for line in sys.stdin:
    print ','.join([item if len(item.strip()) else '\N'
                    for item in line.strip().split(',')])
```

![importing-into-clickhouse-img]

#### 4. Import the data into `trips` table

```bash
time (for filename in /mnt/Sata6/nyc-taxi-data-trips-srini/trips_x*.csv.gz; do
            echo "$filename\n"
            gunzip -ck $filename | \
            python trans.py | \
            clickhouse-client --query="INSERT INTO trips FORMAT CSV"
        done)
```

![clickhouse-import-complete-img][clickhouse-import-complete-img]

#### 5. Create `trips_mergetree` table


```bash
$ clickhouse-client

:)
```

```sql
CREATE TABLE trips_mergetree
ENGINE = MergeTree(pickup_date, pickup_datetime, 8192)
AS SELECT
    trip_id,
    CAST(vendor_id AS Enum8('1' = 1, '2' = 2, '3' = 3, '4' = 4, 'CMT' = 5, 'VTS' = 6, 'DDS' = 7, 'B02512' = 10, 'B02598' = 11, 'B02617' = 12, 'B02682' = 13, 'B02764' = 14)) AS vendor_id,
    toDate(pickup_datetime) AS pickup_date,
    ifNull(pickup_datetime, toDateTime(0)) AS pickup_datetime,
    toDate(dropoff_datetime) AS dropoff_date,
    ifNull(dropoff_datetime, toDateTime(0)) AS dropoff_datetime,
    assumeNotNull(store_and_fwd_flag) IN ('Y', '1', '2') AS store_and_fwd_flag,
    assumeNotNull(rate_code_id) AS rate_code_id,
    assumeNotNull(pickup_longitude) AS pickup_longitude,
    assumeNotNull(pickup_latitude) AS pickup_latitude,
    assumeNotNull(dropoff_longitude) AS dropoff_longitude,
    assumeNotNull(dropoff_latitude) AS dropoff_latitude,
    assumeNotNull(passenger_count) AS passenger_count,
    assumeNotNull(trip_distance) AS trip_distance,
    assumeNotNull(fare_amount) AS fare_amount,
    assumeNotNull(extra) AS extra,
    assumeNotNull(mta_tax) AS mta_tax,
    assumeNotNull(tip_amount) AS tip_amount,
    assumeNotNull(tolls_amount) AS tolls_amount,
    assumeNotNull(ehail_fee) AS ehail_fee,
    assumeNotNull(improvement_surcharge) AS improvement_surcharge,
    assumeNotNull(total_amount) AS total_amount,
    CAST((assumeNotNull(payment_type) AS pt) IN ('CSH', 'CASH', 'Cash', 'CAS', 'Cas', '1') ? 'CSH' : (pt IN ('CRD', 'Credit', 'Cre', 'CRE', 'CREDIT', '2') ? 'CRE' : (pt IN ('NOC', 'No Charge', 'No', '3') ? 'NOC' : (pt IN ('DIS', 'Dispute', 'Dis', '4') ? 'DIS' : 'UNK'))) AS Enum8('CSH' = 1, 'CRE' = 2, 'UNK' = 0, 'NOC' = 3, 'DIS' = 4)) AS payment_type_,
    assumeNotNull(trip_type) AS trip_type,
    assumeNotNull(pickup) AS pickup,
    assumeNotNull(dropoff) AS dropoff,
    CAST(assumeNotNull(cab_type) AS Enum8('yellow' = 1, 'green' = 2, 'uber' = 3)) AS cab_type,
    assumeNotNull(pickup_nyct2010_gid) AS pickup_nyct2010_gid,
    toFloat32(ifNull(pickup_ctlabel, '0')) AS pickup_ctlabel,
    assumeNotNull(pickup_borocode) AS pickup_borocode,
    assumeNotNull(pickup_boroname) AS pickup_ct2010,
    toFixedString(ifNull(pickup_boroct2010, '0000000'), 7) AS pickup_boroct2010,
    assumeNotNull(ifNull(pickup_cdeligibil, ' ')) AS pickup_cdeligibil,
    toFixedString(ifNull(pickup_ntacode, '0000'), 4) AS pickup_ntacode,
    assumeNotNull(pickup_ntaname) AS pickup_ntaname,
    toUInt16(ifNull(pickup_puma, '0')) AS pickup_puma,
    assumeNotNull(dropoff_nyct2010_gid) AS dropoff_nyct2010_gid,
    toFloat32(ifNull(dropoff_ctlabel, '0')) AS dropoff_ctlabel,
    assumeNotNull(dropoff_borocode) AS dropoff_borocode,
    assumeNotNull(dropoff_boroname) AS dropoff_ct2010,
    toFixedString(ifNull(dropoff_boroct2010, '0000000'), 7) AS dropoff_boroct2010,
    assumeNotNull(ifNull(dropoff_cdeligibil, ' ')) AS dropoff_cdeligibil,
    toFixedString(ifNull(dropoff_ntacode, '0000'), 4) AS dropoff_ntacode,
    assumeNotNull(dropoff_ntaname) AS dropoff_ntaname,
    toUInt16(ifNull(dropoff_puma, '0')) AS dropoff_puma
FROM trips
```


## Benchmarking

#### Query 1

**Query**:

```sql
SELECT cab_type, count(*) FROM trips_mergetree GROUP BY cab_type
```

**Perf test**:

```bash
$ query="SELECT cab_type, count(*) FROM trips_mergetree GROUP BY cab_type"
$ sudo perf stat -r 10 clickhouse-client --query=$query

1.15206 +- 0.00993 seconds time elapsed  ( +-  0.86% )
```

![query1 screenshot][query1]


#### Query 2

**Query**:

```sql
SELECT passenger_count, avg(total_amount) FROM trips_mergetree GROUP BY passenger_count
```

**Perf test**:

```bash
$ query="SELECT passenger_count, avg(total_amount) FROM trips_mergetree GROUP BY passenger_count"
$ sudo perf stat -r 10 clickhouse-client --query=$query

3.59093 +- 0.00919 seconds time elapsed  ( +-  0.26% )
```

![query2 screenshot][query2]


#### Query 3

**Query**:

```sql
SELECT passenger_count, toYear(pickup_date) AS year, count(*)
FROM trips_mergetree
GROUP BY passenger_count, year
```

**Perf test**:

```bash
$ query="SELECT passenger_count, toYear(pickup_date) AS year, count(*) \
FROM trips_mergetree \
GROUP BY passenger_count, year"
$ sudo perf stat -r 10 click-house-client --query=$query

5.62999 +- 0.00618 seconds time elapsed  ( +-  0.11% )
```

![query3 screenshot][query3]


#### Query 4

**Query**:

```sql
SELECT passenger_count, toYear(pickup_date) AS year,
       round(trip_distance) AS distance, count(*)
FROM trips_mergetree
GROUP BY passenger_count, year, distance
ORDER BY year, count(*) DESC
```

**Perf test**:

```bash
$ query="SELECT passenger_count, toYear(pickup_date) AS year, \
round(trip_distance) AS distance, count(*) \
FROM trips_mergetree \
GROUP BY passenger_count, year, distance \
ORDER BY year, count(*) DESC"
$ sudo perf stat -r 10 click-house-client --query=$query

8.745 +- 0.233 seconds time elapsed  ( +-  2.66% )
```

![query4 screenshot][query4]



## APPENDIX A: AWS EC2 Instance

Same steps from the above section are followed on the EC2 instance.
This section has screenshots and video showing the configuration details and progress
on AWS.

AWS EC2 is the more practical and ubiquitous option. This is also helpful in
reproducing the benchmark results by others by following my process.

### AWS EC2 Configuration

**Instance Type**: m5.xlarge  
**vCPUs**: 4  
**Memory(GiB)**: 16  
**Internal Storage(GB)**: 8  
**Additional Storage(GB)**: 1000  
**Network Performance**: 10 Gigabit  
**OS**: Ubuntu 14.04 LTS  
**Software**: Postgresql-10, Postgis-2.4  


**AWS EC2 Instance Config**

![ec2-instance-img]

**AWS Disk Usage Chart**

![aws-data-usage-img]


**Screencast of me checking the status on AWS**

I uploaded the screencast to YouTube. The following image is the link to a 2 min
video. YouTube link: https://www.youtube.com/watch?v=OCzhcYz-YG4

[![aws-video-thumb]][aws-video]


## APPENDIX B: Use Prepared Partitions from ClickHouse

ClickHouse followed [Mark's guide][mark-redshift] and obtained the gzipped csv
files and stored them in an Amazon S3 bucket.

The data that is ready to be imported into ClickHouse database can be
downloaded by following the instructions from [ClickHouse documentation][clickhouse-docs].

Following are the steps to download prepared partitions from ClickHouse.

#### 1. Download the prepared data in compressed format from ClickHouse

```bash
$ curl -O https://clickhouse-datasets.s3.yandex.net/trips_mergetree/partitions/trips_mergetree.tar
```

![prepared-data-status-img]


#### 2. Create a ClickHouse database from the downloaded files.

When the download is complete, we extract the files into ClickHouse `data_directory`.

```bash
$ tar xvf trips_mergetree.tar -C /var/lib/clickhouse # path to ClickHouse data directory
```

_check permissions of unpacked data, fix if required._

#### 3. Restart the ClickHouse server and verify the contents of the new table

```bash
$ sudo service clickhouse-server restart
$ clickhouse-client --query "select count(*) from datasets.trips_mergetree"
```


[mark-clickhouse]: https://tech.marksblogg.com/billion-nyc-taxi-clickhouse.html
[mark-redshift]: https://tech.marksblogg.com/billion-nyc-taxi-rides-redshift.html
[toddwschneider-blog]: https://toddwschneider.com/posts/analyzing-1-1-billion-nyc-taxi-and-uber-trips-with-a-vengeance/
[toddwschneider-nyc-taxi-data]: https://github.com/toddwschneider/nyc-taxi-data
[raw-nyc-data]: https://www1.nyc.gov/site/tlc/about/tlc-trip-record-data.page
[clickhouse-docs]: https://clickhouse.yandex/docs/en/getting_started/example_datasets/nyc_taxi/
[clickhouse]: https://clickhouse.yandex/
[prepared-data-status-img]: ./img/prepared_data_status.png
[aws-video]: https://www.youtube.com/watch?v=OCzhcYz-YG4
[aws-video-thumb]: https://img.youtube.com/vi/OCzhcYz-YG4/default.jpg
[aws-data-usage-img]: ./img/aws_data_usage.png
[ec2-instance-img]: ./img/ec2_instance.png
[lines-in-trips-img]: ./img/lines_in_trips.png
[import-script-progress-img]: ./img/import_script_progress.png
[query1]: ./img/query1.png
[query2]: ./img/query2.png
[query3]: ./img/query3.png
[query4]: ./img/query4.png
[postgre-row-counts-img]: ./img/postgres_row_counts.png
[benchmark-thumb]: ./img/benchmark_thumb.png  "click here to watch on Youtube"
[benchmark-video]: https://www.youtube.com/watch?v=GVnK_JhxFCs
[clickhouse-import-complete-img]: ./img/clickhouse_import_complete.png
[importing-into-clickhouse-img]: ./img/importing_into_clickhouse.png
