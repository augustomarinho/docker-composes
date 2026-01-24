# TimescaleDB hypertable demo

Simple setup to demonstrate hot/warm/cold chunk lifecycle on a TimescaleDB hypertable backed by UUID keys.

## What this stack does

1. Spins up two TimescaleDB containers: a primary (hot/warm) and an archival (cold) instance.
2. Initializes both with the same `bank_statements` schema and hypertable (time column: `transaction_time`).
3. Seeds the primary with five years of synthetic data (every six hours, accounts 1000–1200).
4. Lets you detach chunks from the primary, export them, and attach them to the archival instance.

## Quick start

```sh
# from repo root
cd postgres/timescaledb
docker compose up --build
```

This will create two containers:

- `primary-db` on host port `5432` preloaded with the hypertable and data.
- `archival-db` on host port `5433` ready to receive attached chunks.

Use `docker compose down` to stop and clean containers (volumes persist the data).
If you need to rerun the schema/data scripts (for example because you stopped and restarted after the data script failed), remove the named volumes first (`docker compose down -v`) so the init scripts execute again, or run the SQL file manually via `docker compose exec primary-db psql -U postgres -d bankdb -f /docker-entrypoint-initdb.d/03-data.sql`.

## Connect to the primary

You can connect with `psql` from your shell (Postgres user `postgres`, password `changeme`):

```sh
psql -h localhost -p 5432 -U postgres bankdb
```

## Chunk lifecycle workflow

### Inspect and detach (primary)

Once connected to the primary, try:

```sql
-- inspect hypertable chunks
SELECT chunk_name, range_start, range_end FROM show_chunks('bank_statements') ORDER BY range_start;

-- detach an aged chunk for cold storage (replace chunk_name)
CALL detach_chunk('_timescaledb_internal.<chunk_name>');
```

### Dump and restore (host + containers)

Example dump/restore commands (run from repo root):

```sh
mkdir -p postgres/timescaledb/backups

docker compose exec -T primary-db \
  pg_dump -U postgres -d bankdb -t _timescaledb_internal.<chunk_name> -Fc \
  -f /backups/cold-chunk.dump

docker compose exec -T archival-db \
  pg_restore -U postgres -d bankdb /backups/cold-chunk.dump
```

### Attach (archival)

After restoring, attach the chunk in the archival DB:

```sql
CALL attach_chunk('bank_statements', '_timescaledb_internal.<chunk_name>', '{"transaction_time": ["2020-12-04 00:00:00.000000 +00:00","2021-01-03 00:00:00.000000 +00:00"]}');
```

## Validate the restore

Use these checks in the archival DB to confirm the chunk is attached and queryable:

```sql
-- chunk should be visible in the archival DB
SELECT chunk_name, range_start, range_end
FROM show_chunks('bank_statements')
ORDER BY range_start;

-- optional: verify rows are queryable via the hypertable
SELECT count(*) FROM bank_statements;
```

## Chunk sizes

To list chunk sizes (across all hypertables):

```sql
SELECT
  c.hypertable_schema,
  c.hypertable_name,
  c.chunk_schema,
  c.chunk_name,
  pg_size_pretty(pg_total_relation_size(format('%I.%I', c.chunk_schema, c.chunk_name))) AS total_size
FROM timescaledb_information.chunks c
ORDER BY pg_total_relation_size(format('%I.%I', c.chunk_schema, c.chunk_name)) DESC;
```

## Connect to the archival instance

After a chunk is restored there:

```sh
psql -h localhost -p 5433 -U postgres bankdb
```

The `sql/chunk_manage.sql` file provides the same steps with additional comments and backup hints; use it to script the detach/backup/attach workflow.
