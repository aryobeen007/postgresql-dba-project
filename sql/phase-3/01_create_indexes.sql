-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    3 - Performance Optimization
-- Script:   01_create_indexes.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-03
-- Purpose:  Create targeted indexes based on the diagnostic
--           findings from Phase 2. Each index is justified
--           by specific query patterns identified during
--           baseline measurement.
--
-- Indexes Created:
--   1. provider_services(rndrng_npi) — supports provider
--      service lookups and joins to providers table
--   2. provider_services(hcpcs_cd) — supports procedure
--      level aggregations and filtering
--   3. providers(state_abbr) — supports geographic filtering
--      and group-by operations
--   4. providers(provider_type) — supports specialty filtering
--      and group-by operations
--   5. providers(state_abbr, provider_type) — composite index
--      supporting Q4 which groups by both columns together
-- =============================================================

-- -------------------------------------------------------
-- Index 1: provider_services on rndrng_npi
-- Phase 2 finding: Q2 scanned 3.2M rows to return 7 records
-- because no index existed on this join/filter column
-- -------------------------------------------------------
CREATE INDEX CONCURRENTLY idx_provider_services_npi
    ON cms.provider_services (rndrng_npi);

-- -------------------------------------------------------
-- Index 2: provider_services on hcpcs_cd
-- Phase 2 finding: Q5 did a full seq scan and sorted
-- 9.6M rows to aggregate by procedure code
-- -------------------------------------------------------
CREATE INDEX CONCURRENTLY idx_provider_services_hcpcs
    ON cms.provider_services (hcpcs_cd);

-- -------------------------------------------------------
-- Index 3: providers on state_abbr
-- Phase 2 finding: Q4 scanned all providers with no
-- index support for state-level filtering
-- -------------------------------------------------------
CREATE INDEX CONCURRENTLY idx_providers_state
    ON cms.providers (state_abbr);

-- -------------------------------------------------------
-- Index 4: providers on provider_type
-- Phase 2 finding: Q4 grouped by provider_type with
-- no index to support that operation
-- -------------------------------------------------------
CREATE INDEX CONCURRENTLY idx_providers_type
    ON cms.providers (provider_type);

-- -------------------------------------------------------
-- Index 5: providers composite index on state + type
-- Supports Q4 which filters and groups by both columns
-- together — more efficient than two separate indexes
-- for this specific query pattern
-- -------------------------------------------------------
CREATE INDEX CONCURRENTLY idx_providers_state_type
    ON cms.providers (state_abbr, provider_type);