-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    2 - Baseline Measurement and Diagnostics
-- Script:   02_baseline_sizes.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-02
-- Purpose:  Capture baseline storage metrics for the
--           healthcare_dba database, including database size,
--           table sizes, and index sizes before any
--           optimization work is performed.
-- =============================================================

-- -------------------------------------------------------
-- 1. Total database size
-- -------------------------------------------------------
SELECT
    pg_database.datname                            AS database_name,
    pg_size_pretty(pg_database_size(datname))      AS database_size
FROM pg_database
WHERE datname = 'healthcare_dba';

-- -------------------------------------------------------
-- 2. Table sizes including indexes and toast
-- -------------------------------------------------------
SELECT
    schemaname                                         AS schema_name,
    tablename                                          AS table_name,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname || '.' || tablename))       AS table_size,
    pg_size_pretty(pg_indexes_size(schemaname || '.' || tablename))        AS index_size
FROM pg_tables
WHERE schemaname = 'cms'
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC;

-- -------------------------------------------------------
-- 3. Row counts and average row size
-- -------------------------------------------------------
SELECT
    relname                             AS table_name,
    n_live_tup                          AS estimated_rows,
    pg_size_pretty(pg_relation_size('cms.' || relname)) AS table_size,
    CASE WHEN n_live_tup > 0
        THEN pg_relation_size('cms.' || relname) / n_live_tup
        ELSE 0
    END                                 AS avg_row_bytes
FROM pg_stat_user_tables
WHERE schemaname = 'cms'
ORDER BY n_live_tup DESC;

-- -------------------------------------------------------
-- 4. Index inventory
-- -------------------------------------------------------
SELECT
    schemaname                          AS schema_name,
    tablename                           AS table_name,
    indexname                           AS index_name,
    pg_size_pretty(pg_relation_size(indexname::text)) AS index_size,
    indexdef                            AS index_definition
FROM pg_indexes
WHERE schemaname = 'cms'
ORDER BY tablename, indexname;