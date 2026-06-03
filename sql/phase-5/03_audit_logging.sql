-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    5 - Security and Compliance
-- Script:   03_audit_logging.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-03
-- Purpose:  Implement audit logging to track data access
--           and modifications in the healthcare_dba database.
--           In a HIPAA-adjacent environment, audit trails
--           are essential for compliance and forensics.
--
-- Approach:
--   - Create an audit log table to capture DML events
--   - Create a trigger function to log INSERT, UPDATE,
--     DELETE operations on sensitive tables
--   - Log who did what, when, and what changed
-- =============================================================

-- -------------------------------------------------------
-- 1. Create audit schema and log table
-- -------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE audit.data_access_log (
    log_id          BIGSERIAL       NOT NULL,
    log_timestamp   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    db_user         VARCHAR(100)    NOT NULL,
    client_addr     INET,
    application     VARCHAR(100),
    schema_name     VARCHAR(50)     NOT NULL,
    table_name      VARCHAR(100)    NOT NULL,
    operation       VARCHAR(10)     NOT NULL,
    old_data        JSONB,
    new_data        JSONB,
    CONSTRAINT pk_data_access_log PRIMARY KEY (log_id)
);

-- Index for efficient log queries by user and timestamp
CREATE INDEX idx_audit_log_timestamp ON audit.data_access_log (log_timestamp DESC);
CREATE INDEX idx_audit_log_user ON audit.data_access_log (db_user);
CREATE INDEX idx_audit_log_table ON audit.data_access_log (schema_name, table_name);

-- -------------------------------------------------------
-- 2. Create the audit trigger function
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION audit.log_data_changes()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit.data_access_log (
        db_user,
        client_addr,
        application,
        schema_name,
        table_name,
        operation,
        old_data,
        new_data
    )
    VALUES (
        current_user,
        inet_client_addr(),
        current_setting('application_name'),
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        TG_OP,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE')
            THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE')
            THEN to_jsonb(NEW) ELSE NULL END
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -------------------------------------------------------
-- 3. Attach audit trigger to providers table
-- -------------------------------------------------------
CREATE TRIGGER trg_audit_providers
    AFTER INSERT OR UPDATE OR DELETE
    ON cms.providers
    FOR EACH ROW
    EXECUTE FUNCTION audit.log_data_changes();

-- -------------------------------------------------------
-- 4. Attach audit trigger to provider_services table
-- -------------------------------------------------------
CREATE TRIGGER trg_audit_provider_services
    AFTER INSERT OR UPDATE OR DELETE
    ON cms.provider_services
    FOR EACH ROW
    EXECUTE FUNCTION audit.log_data_changes();

-- -------------------------------------------------------
-- 5. Test the audit trigger with a sample update
-- -------------------------------------------------------
UPDATE cms.providers
SET credentials = 'M.D.'
WHERE rndrng_npi = '1003000126';

-- Rollback the test change
UPDATE cms.providers
SET credentials = 'M.D.'
WHERE rndrng_npi = '1003000126';

-- -------------------------------------------------------
-- 6. Verify audit log captured the events
-- -------------------------------------------------------
SELECT
    log_id,
    log_timestamp,
    db_user,
    table_name,
    operation,
    new_data->>'rndrng_npi'     AS npi,
    new_data->>'credentials'    AS new_credentials,
    old_data->>'credentials'    AS old_credentials
FROM audit.data_access_log
ORDER BY log_timestamp DESC
LIMIT 5;