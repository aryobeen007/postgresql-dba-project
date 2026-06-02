-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    2 - Baseline Measurement and Diagnostics
-- Script:   03_baseline_queries.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-02
-- Purpose:  Run representative analytical queries against the
--           unoptimized database to establish baseline query
--           performance metrics before any indexing or
--           configuration changes are made.
--
-- Note:     EXPLAIN ANALYZE is used to capture actual
--           execution time and plan details. Results are
--           documented in the phase 2 documentation.
-- =============================================================

-- -------------------------------------------------------
-- Query 1: Provider lookup by NPI
-- Common operation — look up a single provider by NPI
-- -------------------------------------------------------
EXPLAIN ANALYZE
SELECT *
FROM cms.providers
WHERE rndrng_npi = '1003000126';

-- -------------------------------------------------------
-- Query 2: Services for a specific provider
-- Common operation — find all services billed by one provider
-- -------------------------------------------------------
EXPLAIN ANALYZE
SELECT *
FROM cms.provider_services
WHERE rndrng_npi = '1003000126';

-- -------------------------------------------------------
-- Query 3: Top 10 providers by total Medicare payments
-- Analytical query — aggregation across 9.6M rows
-- -------------------------------------------------------
EXPLAIN ANALYZE
SELECT
    p.rndrng_npi,
    p.first_name,
    p.last_org_name,
    p.provider_type,
    p.state_abbr,
    ROUND(SUM(ps.avg_mdcr_pymt_amt), 2) AS total_payments
FROM cms.providers p
JOIN cms.provider_services ps ON p.rndrng_npi = ps.rndrng_npi
GROUP BY p.rndrng_npi, p.first_name, p.last_org_name, p.provider_type, p.state_abbr
ORDER BY total_payments DESC
LIMIT 10;

-- -------------------------------------------------------
-- Query 4: Services by state and provider type
-- Analytical query — filter and aggregate by state
-- -------------------------------------------------------
EXPLAIN ANALYZE
SELECT
    p.state_abbr,
    p.provider_type,
    COUNT(DISTINCT p.rndrng_npi)            AS provider_count,
    ROUND(AVG(ps.avg_mdcr_pymt_amt), 2)    AS avg_payment
FROM cms.providers p
JOIN cms.provider_services ps ON p.rndrng_npi = ps.rndrng_npi
GROUP BY p.state_abbr, p.provider_type
ORDER BY p.state_abbr, avg_payment DESC;

-- -------------------------------------------------------
-- Query 5: High value procedures
-- Analytical query — find procedures with highest
-- average Medicare payments
-- -------------------------------------------------------
EXPLAIN ANALYZE
SELECT
    hcpcs_cd,
    hcpcs_desc,
    COUNT(*)                                AS provider_count,
    ROUND(AVG(avg_mdcr_pymt_amt), 2)       AS avg_payment,
    ROUND(MAX(avg_mdcr_pymt_amt), 2)       AS max_payment
FROM cms.provider_services
GROUP BY hcpcs_cd, hcpcs_desc
ORDER BY avg_payment DESC
LIMIT 20;