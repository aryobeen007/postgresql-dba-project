-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    5 - Security and Compliance
-- Script:   01_roles_and_access.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-03
-- Purpose:  Implement role-based access control (RBAC) for
--           the healthcare_dba database following the
--           principle of least privilege.
--
-- Roles Created:
--   - dba_admin     : Full database administration access
--   - analyst       : Read-only access to cms schema
--   - data_engineer : Read/write access to staging tables only
--   - app_readonly  : Minimal read access for applications
-- =============================================================

-- -------------------------------------------------------
-- 1. Create roles (no login — these are group roles)
-- -------------------------------------------------------
CREATE ROLE dba_admin;
CREATE ROLE analyst;
CREATE ROLE data_engineer;
CREATE ROLE app_readonly;

-- -------------------------------------------------------
-- 2. Grant privileges to dba_admin
--    Full control over the healthcare_dba database
-- -------------------------------------------------------
GRANT ALL PRIVILEGES ON DATABASE healthcare_dba TO dba_admin;
GRANT ALL PRIVILEGES ON SCHEMA cms TO dba_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cms TO dba_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA cms TO dba_admin;

-- -------------------------------------------------------
-- 3. Grant privileges to analyst
--    Read-only access to all cms tables
--    Typical for reporting and analytics users
-- -------------------------------------------------------
GRANT CONNECT ON DATABASE healthcare_dba TO analyst;
GRANT USAGE ON SCHEMA cms TO analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA cms TO analyst;

-- -------------------------------------------------------
-- 4. Grant privileges to data_engineer
--    Read/write on staging table only
--    Cannot modify providers or provider_services directly
-- -------------------------------------------------------
GRANT CONNECT ON DATABASE healthcare_dba TO data_engineer;
GRANT USAGE ON SCHEMA cms TO data_engineer;
GRANT SELECT, INSERT, UPDATE, DELETE ON cms.staging_raw TO data_engineer;
GRANT SELECT ON cms.providers TO data_engineer;
GRANT SELECT ON cms.provider_services TO data_engineer;

-- -------------------------------------------------------
-- 5. Grant privileges to app_readonly
--    Minimal read access for application connections
--    Restricted to providers and provider_services only
--    No access to staging_raw (raw/sensitive data)
-- -------------------------------------------------------
GRANT CONNECT ON DATABASE healthcare_dba TO app_readonly;
GRANT USAGE ON SCHEMA cms TO app_readonly;
GRANT SELECT ON cms.providers TO app_readonly;
GRANT SELECT ON cms.provider_services TO app_readonly;

-- -------------------------------------------------------
-- 6. Create login users and assign roles
-- -------------------------------------------------------
CREATE USER naseer_dba    WITH PASSWORD 'DBA$ecure2026!' LOGIN;
CREATE USER jane_analyst  WITH PASSWORD 'Analyst$2026!'  LOGIN;
CREATE USER etl_engineer  WITH PASSWORD 'Eng1neer$2026!' LOGIN;
CREATE USER app_user      WITH PASSWORD 'App$Read2026!'  LOGIN;

GRANT dba_admin     TO naseer_dba;
GRANT analyst       TO jane_analyst;
GRANT data_engineer TO etl_engineer;
GRANT app_readonly  TO app_user;

-- -------------------------------------------------------
-- 7. Verify roles and privileges
-- -------------------------------------------------------
SELECT
    r.rolname                           AS role_name,
    r.rolsuper                          AS is_superuser,
    r.rolcreatedb                       AS can_create_db,
    r.rolcreaterole                     AS can_create_role,
    r.rolcanlogin                       AS can_login
FROM pg_roles r
WHERE r.rolname IN (
    'dba_admin', 'analyst', 'data_engineer', 'app_readonly',
    'naseer_dba', 'jane_analyst', 'etl_engineer', 'app_user'
)
ORDER BY r.rolcanlogin, r.rolname;