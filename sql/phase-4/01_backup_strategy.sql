-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    4 - Operations and High Availability
-- Script:   01_backup_strategy.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-03
-- Purpose:  Document and implement the backup strategy for
--           the healthcare_dba database. Covers logical
--           backups using pg_dump and physical backups
--           using pg_basebackup.
--
-- Backup Types:
--   1. Logical backup (pg_dump) — schema + data, portable
--   2. Physical backup (pg_basebackup) — full cluster copy
--
-- Note: pg_dump and pg_basebackup are command-line tools
--       run from PowerShell, not from within psql.
--       This script documents the commands and provides
--       companion queries to verify backup readiness.
-- =============================================================

-- -------------------------------------------------------
-- 1. Check database size before backup
--    Used to estimate backup duration and storage needed
-- -------------------------------------------------------
SELECT
    datname                                         AS database_name,
    pg_size_pretty(pg_database_size(datname))       AS database_size
FROM pg_database
WHERE datname = 'healthcare_dba';

-- -------------------------------------------------------
-- 2. Check current WAL configuration
--    WAL archiving is required for point-in-time recovery
-- -------------------------------------------------------
SELECT name, setting, unit, context
FROM pg_settings
WHERE name IN (
    'wal_level',
    'archive_mode',
    'archive_command',
    'max_wal_senders',
    'wal_keep_size'
)
ORDER BY name;

-- -------------------------------------------------------
-- 3. Check active connections before backup
--    Useful to confirm no long-running transactions
--    that could affect backup consistency
-- -------------------------------------------------------
SELECT
    pid,
    usename                                         AS username,
    application_name,
    state,
    query_start,
    LEFT(query, 80)                                 AS current_query
FROM pg_stat_activity
WHERE datname = 'healthcare_dba'
AND state != 'idle'
ORDER BY query_start;

-- -------------------------------------------------------
-- 4. Verify table statistics are current before backup
--    Ensures ANALYZE has been run recently
-- -------------------------------------------------------
SELECT
    schemaname                                      AS schema_name,
    relname                                         AS table_name,
    last_analyze,
    last_autoanalyze,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE schemaname = 'cms'
ORDER BY relname;