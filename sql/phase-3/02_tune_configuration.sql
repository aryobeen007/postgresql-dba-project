-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    3 - Performance Optimization
-- Script:   02_tune_configuration.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-03
-- Purpose:  Tune PostgreSQL configuration parameters to
--           reduce disk spill during sort and hash operations.
--           Phase 2 diagnostics showed external merge sorts
--           spilling up to 307 MB per worker to disk.
--
-- Parameters Tuned:
--   - work_mem: memory per sort/hash operation per query
--   - effective_cache_size: planner estimate of OS cache
--   - random_page_cost: tuned for SSD storage
-- =============================================================

-- -------------------------------------------------------
-- Check current configuration values before changes
-- -------------------------------------------------------
SELECT name, setting, unit, context
FROM pg_settings
WHERE name IN (
    'work_mem',
    'shared_buffers',
    'effective_cache_size',
    'random_page_cost',
    'max_parallel_workers_per_gather'
)
ORDER BY name;

-- -------------------------------------------------------
-- Tune work_mem for the current session
-- Default is 4MB — far too low for 9.6M row aggregations
-- Increasing to 256MB reduces disk spill significantly
-- Note: This is set per session here. For permanent
-- changes, update postgresql.conf
-- -------------------------------------------------------
SET work_mem = '256MB';

-- -------------------------------------------------------
-- Tune random_page_cost for SSD storage
-- Default is 4.0 (assumes spinning disk)
-- SSD should be 1.1-2.0 to encourage index usage
-- -------------------------------------------------------
SET random_page_cost = 1.5;

-- -------------------------------------------------------
-- Verify the changes took effect
-- -------------------------------------------------------
SELECT name, setting, unit
FROM pg_settings
WHERE name IN ('work_mem', 'random_page_cost');