-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    3 - Performance Optimization
-- Script:   03_optimized_queries.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-03
-- Purpose:  Re-run the five baseline queries from Phase 2
--           after indexes and configuration tuning have been
--           applied. Results are compared against baseline
--           to measure optimization impact.
--
-- Changes applied before this run:
--   - 5 indexes created on key filter/join/group-by columns
--   - work_mem increased from 4MB to 256MB
--   - random_page_cost reduced from 4.0 to 1.5
-- =============================================================

-- Apply session tuning before running queries
SET work_mem = '256MB';
SET random_page_cost = 1.5;

-- -------------------------------------------------------
-- Query 1: Provider lookup by NPI
-- -------------------------------------------------------
EXPLAIN ANALYZE
SELECT *
FROM cms.providers
WHERE rndrng_npi = '1003000126';

-- -------------------------------------------------------
-- Query 2: Services for a specific provider
-- -------------------------------------------------------
EXPLAIN ANALYZE
SELECT *
FROM cms.provider_services
WHERE rndrng_npi = '1003000126';

-- -------------------------------------------------------
-- Query 3: Top 10 providers by total Medicare payments
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