-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    2 - Baseline Measurement and Diagnostics
-- Script:   04_diagnostics.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-02
-- Purpose:  Run diagnostic queries to identify missing indexes,
--           sequential scan patterns, and table bloat.
--           Results inform the optimization plan in Phase 3.
-- =============================================================

-- -------------------------------------------------------
-- 1. Sequential scan counts per table
-- High seq_scan count on large tables = missing indexes
-- -------------------------------------------------------
SELECT
    schemaname                          AS schema_name,
    relname                             AS table_name,
    seq_scan                            AS sequential_scans,
    seq_tup_read                        AS rows_read_by_seq_scan,
    idx_scan                            AS index_scans,
    idx_tup_fetch                       AS rows_fetched_by_index,
    n_live_tup                          AS estimated_live_rows
FROM pg_stat_user_tables
WHERE schemaname = 'cms'
ORDER BY seq_tup_read DESC;

-- -------------------------------------------------------
-- 2. Tables with no index scans (candidates for indexing)
-- -------------------------------------------------------
SELECT
    schemaname                          AS schema_name,
    relname                             AS table_name,
    seq_scan                            AS sequential_scans,
    idx_scan                            AS index_scans,
    n_live_tup                          AS estimated_rows
FROM pg_stat_user_tables
WHERE schemaname = 'cms'
AND (idx_scan = 0 OR idx_scan IS NULL)
ORDER BY seq_scan DESC;

-- -------------------------------------------------------
-- 3. Index usage statistics
-- Identifies unused indexes (overhead with no benefit)
-- -------------------------------------------------------
SELECT
    s.schemaname                        AS schema_name,
    s.relname                           AS table_name,
    s.indexrelname                      AS index_name,
    s.idx_scan                          AS times_used,
    s.idx_tup_read                      AS tuples_read,
    s.idx_tup_fetch                     AS tuples_fetched
FROM pg_stat_user_indexes s
WHERE s.schemaname = 'cms'
ORDER BY s.idx_scan DESC;

-- -------------------------------------------------------
-- 4. Cache hit ratio per table
-- Low ratio = too many disk reads, needs more work_mem
-- or better indexing
-- -------------------------------------------------------
SELECT
    relname                             AS table_name,
    heap_blks_read                      AS disk_reads,
    heap_blks_hit                       AS cache_hits,
    CASE WHEN (heap_blks_hit + heap_blks_read) > 0
        THEN ROUND(heap_blks_hit::NUMERIC /
             (heap_blks_hit + heap_blks_read) * 100, 2)
        ELSE 0
    END                                 AS cache_hit_ratio_pct
FROM pg_statio_user_tables
WHERE schemaname = 'cms'
ORDER BY disk_reads DESC;

-- -------------------------------------------------------
-- 5. Most time-consuming queries from pg_stat_statements
-- -------------------------------------------------------
SELECT
    ROUND(total_exec_time::NUMERIC, 2)  AS total_exec_ms,
    calls,
    ROUND(mean_exec_time::NUMERIC, 2)   AS avg_exec_ms,
    ROUND(stddev_exec_time::NUMERIC, 2) AS stddev_ms,
    LEFT(query, 120)                    AS query_preview
FROM pg_stat_statements
WHERE query ILIKE '%cms%'
ORDER BY total_exec_time DESC
LIMIT 10;


SELECT * FROM pg_stat_statements LIMIT 5;