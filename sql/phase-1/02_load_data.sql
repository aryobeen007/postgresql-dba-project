-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    1 - Schema Design and Data Loading
-- Script:   02_load_data.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-02
-- Purpose:  Load CMS Medicare Physician & Other Practitioners
--           data into the cms schema using a staged approach.
--
-- Load Strategy:
--   - Data is loaded into a staging table first to allow
--     validation and deduplication before inserting into
--     the normalized provider and service tables.
--   - COPY command is used for bulk loading performance.
--   - Provider rows are deduplicated on NPI before insert
--     since one provider appears on multiple service rows.
--   - NULLIF used on numeric columns to gracefully handle
--     empty strings in the source CSV.
--
-- Results:
--   - Staging rows loaded:       9,660,647
--   - Unique providers loaded:   1,175,281
--   - Service rows loaded:       9,660,647
-- =============================================================

-- -------------------------------------------------------
-- Step 1: Create staging table to receive raw CSV data
-- -------------------------------------------------------
DROP TABLE IF EXISTS cms.staging_raw;

CREATE TABLE cms.staging_raw (
    rndrng_npi              VARCHAR(10),
    last_org_name           VARCHAR(100),
    first_name              VARCHAR(50),
    middle_initial          VARCHAR(5),
    credentials             VARCHAR(50),
    entity_code             VARCHAR(5),
    street1                 VARCHAR(100),
    street2                 VARCHAR(100),
    city                    VARCHAR(50),
    state_abbr              VARCHAR(2),
    state_fips              VARCHAR(3),
    zip5                    VARCHAR(5),
    ruca                    VARCHAR(10),
    ruca_desc               TEXT,
    country                 VARCHAR(5),
    provider_type           VARCHAR(100),
    medicare_participating  VARCHAR(1),
    hcpcs_cd                VARCHAR(10),
    hcpcs_desc              TEXT,
    hcpcs_drug_ind          VARCHAR(1),
    place_of_service        VARCHAR(1),
    tot_benes               VARCHAR(20),
    tot_srvcs               VARCHAR(20),
    tot_bene_day_srvcs      VARCHAR(20),
    avg_sbmtd_chrg          VARCHAR(20),
    avg_mdcr_alowd_amt      VARCHAR(20),
    avg_mdcr_pymt_amt       VARCHAR(20),
    avg_mdcr_stdzd_amt      VARCHAR(20)
);

-- -------------------------------------------------------
-- Step 2: Bulk load raw CSV into staging table
-- Note: File copied to C:\temp\ to allow PostgreSQL server
--       process to read it (avoids Windows permission issue
--       with user profile directories)
-- Load time: 57 seconds | Rows loaded: 9,660,647
-- -------------------------------------------------------
COPY cms.staging_raw
FROM 'C:\temp\MUP_PHY_R25_P05_V20_D23_Prov_Svc.csv'
WITH (
    FORMAT CSV,
    HEADER true,
    DELIMITER ',',
    QUOTE '"',
    ENCODING 'WIN1252'
);

-- -------------------------------------------------------
-- Step 3: Verify staging load
-- -------------------------------------------------------
SELECT COUNT(*) FROM cms.staging_raw;

-- -------------------------------------------------------
-- Step 4: Load providers dimension table
-- Deduplicate on NPI using DISTINCT ON so each provider
-- appears exactly once regardless of how many services
-- they have in the source data.
-- Load time: 42 seconds | Rows loaded: 1,175,281
-- -------------------------------------------------------
INSERT INTO cms.providers (
    rndrng_npi,
    last_org_name,
    first_name,
    middle_initial,
    credentials,
    entity_code,
    street1,
    street2,
    city,
    state_abbr,
    state_fips,
    zip5,
    ruca,
    ruca_desc,
    country,
    provider_type,
    medicare_participating
)
SELECT DISTINCT ON (rndrng_npi)
    rndrng_npi,
    last_org_name,
    first_name,
    middle_initial,
    credentials,
    entity_code,
    street1,
    street2,
    city,
    state_abbr,
    state_fips,
    zip5,
    NULLIF(ruca, '')::NUMERIC(4,1),
    ruca_desc,
    country,
    provider_type,
    medicare_participating
FROM cms.staging_raw
WHERE rndrng_npi IS NOT NULL
ORDER BY rndrng_npi;

-- -------------------------------------------------------
-- Step 5: Load provider services fact table
-- All 9.6M service rows inserted with type casting
-- applied to numeric columns.
-- Load time: 2 minutes 59 seconds | Rows loaded: 9,660,647
-- -------------------------------------------------------
INSERT INTO cms.provider_services (
    rndrng_npi,
    hcpcs_cd,
    hcpcs_desc,
    hcpcs_drug_ind,
    place_of_service,
    tot_benes,
    tot_srvcs,
    tot_bene_day_srvcs,
    avg_sbmtd_chrg,
    avg_mdcr_alowd_amt,
    avg_mdcr_pymt_amt,
    avg_mdcr_stdzd_amt
)
SELECT
    rndrng_npi,
    hcpcs_cd,
    hcpcs_desc,
    hcpcs_drug_ind,
    place_of_service,
    NULLIF(tot_benes, '')::INTEGER,
    NULLIF(tot_srvcs, '')::NUMERIC(10,2),
    NULLIF(tot_bene_day_srvcs, '')::NUMERIC(10,2),
    NULLIF(avg_sbmtd_chrg, '')::NUMERIC(12,2),
    NULLIF(avg_mdcr_alowd_amt, '')::NUMERIC(12,2),
    NULLIF(avg_mdcr_pymt_amt, '')::NUMERIC(12,2),
    NULLIF(avg_mdcr_stdzd_amt, '')::NUMERIC(12,2)
FROM cms.staging_raw
WHERE rndrng_npi IS NOT NULL;