-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    1 - Schema Design and Data Loading
-- Script:   03_validate_data.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-02
-- Purpose:  Validate data integrity and quality after load.
--           Confirms row counts, checks for nulls in key
--           columns, and verifies referential integrity
--           between providers and provider_services.
-- =============================================================

-- -------------------------------------------------------
-- 1. Row counts across all tables
-- -------------------------------------------------------
SELECT 'staging_raw'       AS table_name, COUNT(*) AS row_count FROM cms.staging_raw
UNION ALL
SELECT 'providers'         AS table_name, COUNT(*) AS row_count FROM cms.providers
UNION ALL
SELECT 'provider_services' AS table_name, COUNT(*) AS row_count FROM cms.provider_services;

-- -------------------------------------------------------
-- 2. Check for null NPIs in providers
-- -------------------------------------------------------
SELECT COUNT(*) AS null_npi_count
FROM cms.providers
WHERE rndrng_npi IS NULL;

-- -------------------------------------------------------
-- 3. Check for orphaned service rows
-- (services with no matching provider)
-- -------------------------------------------------------
SELECT COUNT(*) AS orphaned_services
FROM cms.provider_services ps
LEFT JOIN cms.providers p ON ps.rndrng_npi = p.rndrng_npi
WHERE p.rndrng_npi IS NULL;

-- -------------------------------------------------------
-- 4. Check for nulls in key service columns
-- -------------------------------------------------------
SELECT
    COUNT(*) FILTER (WHERE hcpcs_cd IS NULL)        AS null_hcpcs,
    COUNT(*) FILTER (WHERE tot_benes IS NULL)        AS null_tot_benes,
    COUNT(*) FILTER (WHERE avg_mdcr_pymt_amt IS NULL) AS null_payment
FROM cms.provider_services;

-- -------------------------------------------------------
-- 5. Provider type distribution
-- -------------------------------------------------------
SELECT
    provider_type,
    COUNT(*) AS provider_count
FROM cms.providers
GROUP BY provider_type
ORDER BY provider_count DESC
LIMIT 10;

-- -------------------------------------------------------
-- 6. Top 10 states by provider count
-- -------------------------------------------------------
SELECT
    state_abbr,
    COUNT(*) AS provider_count
FROM cms.providers
GROUP BY state_abbr
ORDER BY provider_count DESC
LIMIT 10;

-- -------------------------------------------------------
-- 7. Payment summary statistics
-- -------------------------------------------------------
SELECT
    ROUND(MIN(avg_mdcr_pymt_amt), 2)  AS min_payment,
    ROUND(MAX(avg_mdcr_pymt_amt), 2)  AS max_payment,
    ROUND(AVG(avg_mdcr_pymt_amt), 2)  AS avg_payment,
    ROUND(SUM(avg_mdcr_pymt_amt), 2)  AS total_payment
FROM cms.provider_services;