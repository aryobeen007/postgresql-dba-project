# Phase 3: Performance Optimization

## Overview

In this phase I implemented targeted performance optimizations based on the 
diagnostic findings from Phase 2. My approach was to first add indexes on the 
columns identified as missing index candidates, then tune key configuration 
parameters to reduce disk spill during large aggregation operations. After each 
change I re-ran the same five baseline queries to measure the impact.

---

## Optimization Strategy

Phase 2 identified two root causes of poor performance:

1. **Missing indexes** on filter, join, and group-by columns causing full 
   sequential scans through millions of rows
2. **Insufficient work_mem** (4MB default) causing sort and hash aggregation 
   operations to spill large amounts of data to disk

I addressed both in sequence — indexes first, then memory configuration.

---

## Indexes Created

I created five indexes using `CREATE INDEX CONCURRENTLY` to avoid locking the 
tables during index builds. This is the production-safe approach for adding 
indexes to live tables.

| Index | Table | Column(s) | Size | Build Time |
|-------|-------|-----------|------|------------|
| idx_provider_services_npi | provider_services | rndrng_npi | 100 MB | ~16s |
| idx_provider_services_hcpcs | provider_services | hcpcs_cd | 64 MB | 16s |
| idx_providers_state | providers | state_abbr | 8 MB | 1s |
| idx_providers_type | providers | provider_type | 8 MB | 1.4s |
| idx_providers_state_type | providers | state_abbr, provider_type | 8.5 MB | 2.3s |

### Index Design Rationale

**idx_provider_services_npi** — The most critical index. Phase 2 showed that 
looking up services for a specific provider required a full parallel sequential 
scan through 3.2 million rows to return 7 records. This index directly supports 
the join between `provider_services` and `providers` on NPI.

**idx_provider_services_hcpcs** — Supports procedure-level aggregations and 
filtering. Q5 in the baseline was sorting all 9.6M rows by HCPCS code with no 
index support.

**idx_providers_state and idx_providers_type** — Support geographic and specialty 
filtering on the providers table. Both are low-cost indexes on a 1.17M row table.

**idx_providers_state_type** — A composite index supporting Q4 which groups by 
both state and provider type together. More efficient than two separate indexes 
for this specific query pattern.

---

## Configuration Tuning

### work_mem

The default `work_mem` of 4MB was the primary cause of disk spill in Phase 2. 
I tested with 256MB at the session level during optimization testing, which 
confirmed that the disk spill was memory-related. However, setting `work_mem` 
too high globally has unintended consequences — it can suppress parallel query 
execution because PostgreSQL becomes cautious about total memory usage across 
all workers.

After testing I settled on **64MB** as the permanent global setting. This 
eliminates disk spill for most analytical queries while preserving parallel 
execution for the heaviest workloads.

| Parameter | Before | After |
|-----------|--------|-------|
| work_mem | 4MB | 64MB |
| random_page_cost | 4.0 | 1.5 |

### random_page_cost

I reduced `random_page_cost` from 4.0 (the default, tuned for spinning disk) 
to 1.5 to reflect the SSD storage on this system. This tells the PostgreSQL 
query planner that random page access is relatively cheap, encouraging it to 
favor index scans over sequential scans where appropriate.

---

## Performance Results

I re-ran all five baseline queries after applying the indexes and configuration 
changes. Results compared against the Phase 2 baseline:

| Query | Description | Baseline | Optimized | Improvement |
|-------|-------------|----------|-----------|-------------|
| Q1 | Provider lookup by NPI | 1ms | 0.053ms | 19x faster |
| Q2 | Services for a specific provider | 455ms | 0.110ms | 4,136x faster |
| Q3 | Top 10 providers by payments | 10,701ms | 8,795ms | 18% faster |
| Q4 | Services by state and provider type | 25,190ms | 25,082ms | Marginal |
| Q5 | High value procedures | 9,821ms | 5,527ms | 44% faster |

### Query-by-Query Analysis

**Q1 — Provider lookup by NPI (1ms → 0.053ms)**
Already fast at baseline due to the primary key index. Slight improvement from 
the reduced `random_page_cost` encouraging the planner to use the index more 
aggressively.

**Q2 — Services for a specific provider (455ms → 0.110ms)**
The most dramatic improvement in the project. Before optimization PostgreSQL 
launched 2 parallel workers and scanned 3,220,213 rows to return 7 records. 
After adding `idx_provider_services_npi` the query uses a single index scan 
reading 4 buffer pages. This is a 4,136x improvement driven entirely by a 
single missing index.

**Q3 — Top 10 providers by total payments (10,701ms → 8,795ms)**
18% improvement. The external merge sorts that were spilling 41–51 MB per worker 
to disk are eliminated — the hash aggregation now runs entirely in memory using 
491MB. The query still requires a full scan of both tables since every provider's 
total payments need to be computed before the top 10 can be identified.

**Q4 — Services by state and provider type (25,190ms → 25,082ms)**
Marginal improvement. This query is the most honest finding in the project. 
It requires processing all 9.6 million service rows, joining to all 1.17 million 
providers, and sorting the entire result set by state and provider type. There 
is no selective filter to exploit — every row must be touched. I also discovered 
during testing that setting work_mem too high (256MB) actually made this query 
slower by suppressing parallel execution. The final 64MB setting restores 
parallel workers while reducing disk spill compared to the 4MB baseline.

**Q5 — High value procedures (9,821ms → 5,527ms)**
44% improvement. The hash aggregation on HCPCS code now runs entirely in memory 
(21MB) with no disk spill. Parallel workers were not needed — a single process 
handled the full scan and aggregation cleanly within the available memory.

---

## Key Takeaways

**Indexes matter most for selective queries.** Q2's 4,136x improvement 
demonstrates what happens when a high-cardinality column used for filtering and 
joining has no index. The fix was a single `CREATE INDEX` statement.

**Memory tuning eliminates disk spill but requires balance.** Increasing 
`work_mem` removed disk spill from Q3 and Q5, but setting it too high suppressed 
parallel execution in Q4. A DBA must test the impact of memory changes across 
the full query workload, not just the query being optimized.

**Some queries have an optimization floor.** Q4 processes every row in both 
tables with no selective filter. No amount of indexing or memory tuning can 
eliminate the cost of reading and sorting 9.6 million rows. The honest 
documentation of this finding is as important as the dramatic improvements 
elsewhere.

---

## Scripts

| Script | Purpose |
|--------|---------|
| `sql/phase-3/01_create_indexes.sql` | Create five targeted indexes |
| `sql/phase-3/02_tune_configuration.sql` | Capture baseline config and apply tuning |
| `sql/phase-3/03_optimized_queries.sql` | Re-run baseline queries after optimization |

---

## Next Phase

In Phase 4 I will implement operational procedures including backup and recovery 
strategies, connection pooling configuration, and high availability planning.