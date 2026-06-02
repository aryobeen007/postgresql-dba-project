# Phase 2: Baseline Measurement and Diagnostics

## Overview

In this phase I established baseline performance metrics for the healthcare_dba 
database before making any optimization changes. The goal was to measure how the 
database performs in its unoptimized state so that every improvement made in 
Phase 3 is backed by real before-and-after data.

---

## What I Measured

- Database and table storage sizes
- Index inventory and usage statistics
- Sequential scan patterns
- Cache hit ratios
- Query execution times and plans for five representative analytical queries

---

## Environment Configuration

Before running any diagnostics I enabled the `pg_stat_statements` extension to 
track query execution statistics across all sessions. This required two steps:

1. Creating the extension inside the database:
```sql
   CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

2. Adding `pg_stat_statements` to `shared_preload_libraries` in `postgresql.conf` 
   and restarting the PostgreSQL service. This is required because the extension 
   must be loaded at server startup to instrument all queries from the beginning 
   of each session.

---

## Storage Baseline

### Database Size

| Database | Size |
|----------|------|
| healthcare_dba | 5,383 MB |

### Table Sizes

| Table | Total Size | Table Size | Index Size |
|-------|-----------|------------|------------|
| staging_raw | 3,305 MB | 3,304 MB | 0 bytes |
| provider_services | 1,772 MB | 1,564 MB | 207 MB |
| providers | 298 MB | 263 MB | 35 MB |

The staging table carries no indexes — expected since it is a temporary landing 
zone for raw data. Both `providers` and `provider_services` have only their 
primary key indexes at this point. No analytical indexes exist yet.

### Average Row Size

| Table | Estimated Rows | Avg Row Size |
|-------|---------------|--------------|
| provider_services | 9,660,882 | 169 bytes |
| providers | 1,175,243 | 234 bytes |
| staging_raw | 9,659,647 | 358 bytes |

The staging table's larger average row size reflects the fact that all columns 
are stored as VARCHAR, which is less efficient than the typed columns in the 
final tables.

---

## Index Inventory

At baseline, only two indexes exist across the entire cms schema — both are 
primary key indexes created automatically by PostgreSQL:

| Table | Index | Size | Times Used |
|-------|-------|------|------------|
| providers | pk_providers | 35 MB | 9,660,661 |
| provider_services | pk_provider_services | 207 MB | 2 |

The `pk_providers` index is heavily used because every join from 
`provider_services` to `providers` on NPI hits it. The `pk_provider_services` 
index on the surrogate `id` column is essentially unused for analytical queries 
— it has been accessed only twice.

There are no indexes on any analytical columns such as `rndrng_npi` in 
`provider_services`, `state_abbr`, `provider_type`, or `hcpcs_cd`. This means 
every analytical query is doing a full sequential scan.

---

## Sequential Scan Analysis

| Table | Sequential Scans | Rows Read by Seq Scan | Index Scans |
|-------|-----------------|----------------------|-------------|
| provider_services | 20 | 106,267,117 | 2 |
| providers | 11 | 7,051,686 | 9,660,661 |
| staging_raw | 7 | 57,963,887 | 0 |

`provider_services` had 20 sequential scans reading over 106 million rows — 
a clear signal that analytical queries are not being supported by any indexes.

---

## Cache Hit Ratios

| Table | Disk Reads | Cache Hits | Cache Hit Ratio |
|-------|-----------|------------|-----------------|
| providers | 325,273 | 30,230,075 | 98.94% |
| provider_services | 2,644,297 | 19,828,181 | 88.23% |
| staging_raw | 2,997,554 | 1,796,009 | 37.47% |

The `providers` table is almost entirely served from memory at 98.94%. The 
`provider_services` table is at 88.23% which is acceptable but leaves room for 
improvement. The `staging_raw` table's low ratio of 37.47% is expected given 
its size and the full sequential scans being run against it.

---

## Baseline Query Performance

I ran five representative queries against the unoptimized database using 
`EXPLAIN ANALYZE` to capture actual execution plans and timings. These queries 
represent typical workloads for a healthcare analytics database.

### Results Summary

| Query | Description | Execution Time |
|-------|-------------|---------------|
| Q1 | Provider lookup by NPI | 1ms |
| Q2 | Services for a specific provider | 455ms |
| Q3 | Top 10 providers by total payments | 10,701ms |
| Q4 | Services by state and provider type | 25,190ms |
| Q5 | High value procedures | 9,821ms |

### Key Findings

**Q1 — Provider lookup by NPI (1ms)**
Fast because it uses the primary key index on `rndrng_npi`. This is the only 
query currently supported by an index.

**Q2 — Services for a specific provider (455ms)**
Despite filtering on NPI — the same column that is indexed on `providers` — 
this query does a full parallel sequential scan on `provider_services` because 
there is no index on `rndrng_npi` in that table. PostgreSQL launched 2 parallel 
workers and scanned through 3,220,213 rows to return 7 records.

**Q3 — Top 10 providers by total payments (10,701ms)**
Full sequential scans on both tables. The aggregation spilled to disk with 
external merge sorts consuming 41–51 MB per worker and hash aggregation 
consuming 228–257 MB per worker on disk.

**Q4 — Services by state and provider type (25,190ms)**
The slowest query in the baseline. Full sequential scans plus external merge 
sorts spilling 149–163 MB per worker to disk. All 9.6 million service rows 
had to be processed to produce 4,796 result rows.

**Q5 — High value procedures (9,821ms)**
Full sequential scan on `provider_services` with external merge sorts spilling 
252–295 MB per worker to disk for the group-by aggregation on HCPCS code.

---

## Diagnostic Summary

The baseline diagnostics tell a clear story. The database has no analytical 
indexes, causing every non-primary-key query to perform full sequential scans 
through millions of rows. Large aggregation and sort operations are spilling to 
disk because the available memory is insufficient to hold intermediate results 
in memory. These are the two primary areas I will address in Phase 3.

**Root causes identified:**
- Missing index on `provider_services.rndrng_npi`
- Missing indexes on filter and group-by columns (`state_abbr`, `provider_type`, `hcpcs_cd`)
- Insufficient `work_mem` causing sort and hash operations to spill to disk

---

## Scripts

| Script | Purpose |
|--------|---------|
| `sql/phase-2/01_enable_statistics.sql` | Enable pg_stat_statements extension |
| `sql/phase-2/02_baseline_sizes.sql` | Capture storage and size metrics |
| `sql/phase-2/03_baseline_queries.sql` | Baseline query execution plans |
| `sql/phase-2/04_diagnostics.sql` | Sequential scan and cache diagnostics |

---

## Next Phase

In Phase 3 I will implement targeted indexes on the columns identified in this 
diagnostic phase, tune `work_mem` and other configuration parameters to reduce 
disk spill, and re-run the same five baseline queries to measure the improvement.