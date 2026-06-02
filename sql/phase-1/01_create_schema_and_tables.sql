-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    1 - Schema Design and Data Loading
-- Script:   01_create_schema_and_tables.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-02
-- Purpose:  Create the cms schema and core tables for the
--           Medicare Physician & Other Practitioners dataset.
--
-- Design Decisions:
--   - Separate schema (cms) to isolate project objects from
--     the public schema, reflecting production best practices.
--   - Providers table normalized away from services to avoid
--     repeating provider attributes on every service row.
--   - NPI stored as VARCHAR(10) — it is an identifier, not
--     a value used in calculations.
--   - RUCA stored as NUMERIC(4,1) to accommodate decimal codes.
--   - Payment/charge columns use NUMERIC(12,2) for precision.
--   - BIGSERIAL surrogate key on provider_services since the
--     natural key (NPI + HCPCS) is not enforced as unique in
--     the source data.
-- =============================================================

-- Create schema
CREATE SCHEMA IF NOT EXISTS cms;

-- Drop tables if re-running this script
DROP TABLE IF EXISTS cms.provider_services;
DROP TABLE IF EXISTS cms.providers;

-- Provider dimension table
CREATE TABLE cms.providers (
    rndrng_npi              VARCHAR(10)     NOT NULL,
    last_org_name           VARCHAR(100)    NOT NULL,
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
    ruca                    NUMERIC(4,1),
    ruca_desc               TEXT,
    country                 VARCHAR(5),
    provider_type           VARCHAR(100),
    medicare_participating  VARCHAR(1),
    CONSTRAINT pk_providers PRIMARY KEY (rndrng_npi)
);

-- Service fact table
CREATE TABLE cms.provider_services (
    id                      BIGSERIAL       NOT NULL,
    rndrng_npi              VARCHAR(10)     NOT NULL,
    hcpcs_cd                VARCHAR(10)     NOT NULL,
    hcpcs_desc              TEXT,
    hcpcs_drug_ind          VARCHAR(1),
    place_of_service        VARCHAR(1),
    tot_benes               INTEGER,
    tot_srvcs               NUMERIC(10,2),
    tot_bene_day_srvcs      NUMERIC(10,2),
    avg_sbmtd_chrg          NUMERIC(12,2),
    avg_mdcr_alowd_amt      NUMERIC(12,2),
    avg_mdcr_pymt_amt       NUMERIC(12,2),
    avg_mdcr_stdzd_amt      NUMERIC(12,2),
    CONSTRAINT pk_provider_services PRIMARY KEY (id),
    CONSTRAINT fk_provider_services_npi FOREIGN KEY (rndrng_npi)
        REFERENCES cms.providers (rndrng_npi)
);
