-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    4 - Operations and High Availability
-- Script:   03_maintenance.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-03
-- Purpose:  Routine maintenance procedures for the
--           healthcare_dba database. Covers VACUUM, ANALYZE,
--           index maintenance, and bloat management.
-- =============================================================

-- -------------------------------------------------------
-- 1. Manual VACUUM ANALYZE on all cms tables
--    VACUUM reclaims dead row space
--    ANALYZE updates planner statistics
-- -------------------------------------------------------
VACUUM ANALYZE cms.providers;
VACUUM ANALYZE cms.provider_services;
VACUUM ANALYZE cms.staging_raw;

-- -------------------------------------------------------
-- 2. Check autovacuum configuration
-- -------------------------------------------------------
SELECT name, setting, unit
FROM pg_settings
WHERE name IN (
    'autovacuum',
    'autovacuum_vacuum_threshold',
    'autovacuum_analyze_threshold',
    'autovacuum_vacuum_scale_factor',
    'autovacuum_analyze_scale_factor',
    'autovacuum_vacuum_cost_delay'
)
ORDER BY name;

-- -------------------------------------------------------
-- 3. Index maintenance — rebuild bloated indexes
--    REINDEX CONCURRENTLY rebuilds without locking
-- -------------------------------------------------------
REINDEX INDEX CONCURRENTLY cms.idx_provider_services_npi;
REINDEX INDEX CONCURRENTLY cms.idx_provider_services_hcpcs;
REINDEX INDEX CONCURRENTLY cms.idx_providers_state;
REINDEX INDEX CONCURRENTLY cms.idx_providers_type;
REINDEX INDEX CONCURRENTLY cms.idx_providers_state_type;

-- -------------------------------------------------------
-- 4. Check index sizes after reindex
-- -------------------------------------------------------
SELECT
    indexname                           AS index_name,
    tablename                           AS table_name,
    pg_size_pretty(pg_relation_size(
        quote_ident('cms') || '.' ||
        quote_ident(indexname)))        AS index_size
FROM pg_indexes
WHERE schemaname = 'cms'
ORDER BY tablename, indexname;

-- -------------------------------------------------------
-- 5. Database-wide statistics reset (use with caution)
--    Only run when resetting monitoring baselines
-- -------------------------------------------------------
-- SELECT pg_stat_reset();  -- Uncomment only when needed

-- -------------------------------------------------------
-- 6. Check for table and index bloat
-- -------------------------------------------------------
SELECT
    schemaname                          AS schema_name,
    relname                             AS table_name,
    n_live_tup                          AS live_rows,
    n_dead_tup                          AS dead_rows,
    n_mod_since_analyze                 AS modified_since_analyze,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'cms'
ORDER BY n_dead_tup DESC;