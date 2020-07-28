-- This file and its contents are licensed under the Timescale License.
-- Please see the included NOTICE for copyright information and
-- LICENSE-TIMESCALE for a copy of the license.

---------------------------------------------------
-- Test views and size_utils functions on distributed hypertable
---------------------------------------------------
\c :TEST_DBNAME :ROLE_CLUSTER_SUPERUSER

SET client_min_messages TO ERROR;
DROP DATABASE IF EXISTS data_node_1;
DROP DATABASE IF EXISTS data_node_2;
DROP DATABASE IF EXISTS data_node_3;
SELECT * FROM add_data_node('data_node_1', host => 'localhost',
                            database => 'data_node_1');
SELECT * FROM add_data_node('data_node_2', host => 'localhost',
                            database => 'data_node_2');
SELECT * FROM add_data_node('data_node_3', host => 'localhost',
                            database => 'data_node_3');

GRANT USAGE ON FOREIGN SERVER data_node_1, data_node_2, data_node_3 TO :ROLE_1;
SET client_min_messages TO NOTICE;
SET ROLE :ROLE_1;
SELECT setseed(1);

CREATE TABLE dist_table(time timestamptz, device int, temp float);
SELECT create_distributed_hypertable('dist_table', 'time', 'device', replication_factor => 2);
INSERT INTO dist_table SELECT t, (abs(timestamp_hash(t::timestamp)) % 10) + 1, 80
FROM generate_series('2018-03-02 1:00'::TIMESTAMPTZ, '2018-03-04 1:00', '1 hour') t;
ALTER TABLE dist_table SET (timescaledb.compress, timescaledb.compress_segmentby='device', timescaledb.compress_orderby = 'time DESC');

-- Test that compression is rolled back on aborted transaction
BEGIN;
SELECT compress_chunk(chunk)
FROM show_chunks('dist_table') AS chunk
ORDER BY chunk
LIMIT 1;

SELECT * FROM timescaledb_information.hypertables
WHERE table_name = 'dist_table';
SELECT * from timescaledb_information.chunks 
ORDER BY hypertable_name, chunk_name;
SELECT * from timescaledb_information.dimensions 
ORDER BY hypertable_name, dimension_number;

SELECT * FROM chunks_detailed_size('dist_table'::regclass) 
ORDER BY chunk_name, node_name;
SELECT * FROM hypertable_detailed_size('dist_table'::regclass);

---tables with special characters in the name ----
CREATE TABLE "quote'tab" ( a timestamp,  b integer);
SELECT create_distributed_hypertable( '"quote''tab"', 'a', 'b', replication_factor=>2, chunk_time_interval=>INTERVAL '1 day');
INSERT into "quote'tab" select generate_series( '2020-02-02 10:00', '2020-02-05 10:00' , '1 day'::interval), 10;
SELECT * FROM  chunks_detailed_size( '"quote''tab"') ORDER BY chunk_name, node_name;

CREATE TABLE "special#tab" ( a timestamp,  b integer);
SELECT create_hypertable( 'special#tab', 'a', 'b', replication_factor=>2, chunk_time_interval=>INTERVAL '1 day');
INSERT into "special#tab" select generate_series( '2020-02-02 10:00', '2020-02-05 10:00' , '1 day'::interval), 10;
SELECT * FROM  chunks_detailed_size( '"special#tab"') ORDER BY chunk_name, node_name;
