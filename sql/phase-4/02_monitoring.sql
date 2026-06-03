-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    4 - Operations and High Availability
-- Script:   02_monitoring.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-03
-- Purpose:  Ongoing database health monitoring queries.
--           These queries provide visibility into database
--           activity, performance, and health indicators
--           that a DBA would review regularly in production.
-- =============================================================

-- -------------------------------------------------------
-- 1. Database uptime and server information
-- -------------------------------------------------------
SELECT
    version()                                       AS pg_version,
    pg_postmaster_start_time()                      AS server_start_time,
    NOW() - pg_postmaster_start_time()              AS uptime,
    pg_size_pretty(pg_database_size('healthcare_dba')) AS database_size;

-- -------------------------------------------------------
-- 2. Active connections summary
-- -------------------------------------------------------
SELECT
    state,
    COUNT(*)                                        AS connection_count,
    MAX(NOW() - query_start)                        AS longest_running
FROM pg_stat_activity
WHERE datname = 'healthcare_dba'
GROUP BY state
ORDER BY connection_count DESC;

-- -------------------------------------------------------
-- 3. Long running queries (over 5 minutes)
-- -------------------------------------------------------
SELECT
    pid,
    usename                                         AS username,
    application_name,
    state,
    ROUND(EXTRACT(EPOCH FROM (NOW() - query_start))::NUMERIC, 2) AS duration_seconds,
    LEFT(query, 100)                                AS query_preview
FROM pg_stat_activity
WHERE datname = 'healthcare_dba'
AND state != 'idle'
AND NOW() - query_start > INTERVAL '5 minutes'
ORDER BY duration_seconds DESC;

-- -------------------------------------------------------
-- 4. Table bloat indicators
-- High n_dead_tup means VACUUM is needed
-- -------------------------------------------------------
SELECT
    schemaname                                      AS schema_name,
    relname                                         AS table_name,
    n_live_tup                                      AS live_rows,
    n_dead_tup                                      AS dead_rows,
    CASE WHEN n_live_tup > 0
        THEN ROUND(n_dead_tup::NUMERIC / n_live_tup * 100, 2)
        ELSE 0
    END                                             AS dead_row_pct,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE schemaname = 'cms'
ORDER BY n_dead_tup DESC;

-- -------------------------------------------------------
-- 5. Index health — unused indexes
-- Indexes with zero scans waste storage and slow writes
-- -------------------------------------------------------
SELECT
    s.schemaname                                    AS schema_name,
    s.relname                                       AS table_name,
    s.indexrelname                                  AS index_name,
    s.idx_scan                                      AS times_used,
    pg_size_pretty(pg_relation_size(
        quote_ident(s.schemaname) || '.' ||
        quote_ident(s.indexrelname)))               AS index_size
FROM pg_stat_user_indexes s
WHERE s.schemaname = 'cms'
AND s.idx_scan = 0
ORDER BY pg_relation_size(
    quote_ident(s.schemaname) || '.' ||
    quote_ident(s.indexrelname)) DESC;

-- -------------------------------------------------------
-- 6. Cache hit ratio — should be above 95%
-- -------------------------------------------------------
SELECT
    relname                                         AS table_name,
    heap_blks_read                                  AS disk_reads,
    heap_blks_hit                                   AS cache_hits,
    CASE WHEN (heap_blks_hit + heap_blks_read) > 0
        THEN ROUND(heap_blks_hit::NUMERIC /
             (heap_blks_hit + heap_blks_read) * 100, 2)
        ELSE 0
    END                                             AS cache_hit_ratio_pct
FROM pg_statio_user_tables
WHERE schemaname = 'cms'
ORDER BY disk_reads DESC;

-- -------------------------------------------------------
-- 7. Replication status
-- -------------------------------------------------------
SELECT
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    sync_state
FROM pg_stat_replication;

-- -------------------------------------------------------
-- 8. Top 5 slowest queries from pg_stat_statements
-- -------------------------------------------------------
SELECT
    ROUND(mean_exec_time::NUMERIC, 2)               AS avg_exec_ms,
    calls,
    ROUND(total_exec_time::NUMERIC, 2)              AS total_exec_ms,
    LEFT(query, 100)                                AS query_preview
FROM pg_stat_statements
WHERE query ILIKE '%cms%'
ORDER BY mean_exec_time DESC
LIMIT 5;