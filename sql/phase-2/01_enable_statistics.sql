-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    2 - Baseline Measurement and Diagnostics
-- Script:   01_enable_statistics.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-02
-- Purpose:  Enable pg_stat_statements extension to track
--           query execution statistics. This is the foundation
--           for all baseline measurements in this phase.
-- =============================================================

-- Enable the pg_stat_statements extension
-- This must be run as a superuser
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Verify the extension is active
SELECT name, default_version, installed_version
FROM pg_available_extensions
WHERE name = 'pg_stat_statements';