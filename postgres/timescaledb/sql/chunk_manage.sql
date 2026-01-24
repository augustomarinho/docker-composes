-- Step 1: Identify a chunk that has fallen into the cold tier (older than 6 months).
SELECT *
FROM timescaledb_information.chunks c
WHERE c.hypertable_name = 'bank_statements'
  AND range_end < now() - interval '180 days'
ORDER BY range_end
LIMIT 5;

-- Step 2: Detach the coldest chunk from the hot hypertable so it becomes a standalone table.
-- Replace the placeholder chunk_name with the result above.
CALL detach_chunk('_timescaledb_internal.<your_chunk_name>');

-- Step 3: Back up the detached chunk for cold storage.
-- Example shell commands (run outside psql, from repo root):
--   mkdir -p postgres/timescaledb/backups
--   docker compose -f postgres/timescaledb/docker-compose.yml exec -T primary-db \
--     pg_dump -U postgres -d bankdb -t _timescaledb_internal.<your_chunk_name> -Fc \
--     -f /backups/cold-chunk.dump
--   pg_dump optionally compresses the output: gzip -c postgres/timescaledb/backups/cold-chunk.dump > postgres/timescaledb/backups/cold-chunk.dump.gz
--   OR use copy to export CSV:
--   docker compose -f postgres/timescaledb/docker-compose.yml exec -T primary-db \
--     psql -U postgres -d bankdb -c "\copy _timescaledb_internal.<your_chunk_name> TO STDOUT WITH CSV HEADER" \
--     > /tmp/cold-chunk.csv

-- Step 4: Restore and attach the chunk into the archival database.
-- 1) Load the dump/csv into the archival instance:
--    docker compose -f postgres/timescaledb/docker-compose.yml exec -T archival-db \
--      pg_restore -U postgres -d bankdb /backups/cold-chunk.dump
-- 2) Run the following in the archival database after the chunk table exists:
--    SELECT attach_chunk('bank_statements', '_timescaledb_internal.<your_chunk_name>');

-- Step 5: Optionally, confirm the chunk now belongs to the archival hypertable.
SELECT chunk_name, table_name
FROM show_chunks('bank_statements')
WHERE chunk_name LIKE '_timescaledb_internal.%'
ORDER BY range_start DESC
LIMIT 5;
