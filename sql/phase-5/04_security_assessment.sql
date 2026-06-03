-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    5 - Security and Compliance
-- Script:   04_security_assessment.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-03
-- Purpose:  Security assessment queries to validate the
--           security posture of the healthcare_dba database.
--           Covers user privileges, RLS status, SSL config,
--           and superuser account inventory.
-- =============================================================

-- -------------------------------------------------------
-- 1. Superuser inventory
--    Any unexpected superusers are a security risk
-- -------------------------------------------------------
SELECT
    rolname                             AS role_name,
    rolsuper                            AS is_superuser,
    rolcreatedb                         AS can_create_db,
    rolcreaterole                       AS can_create_role,
    rolcanlogin                         AS can_login,
    rolvaliduntil                       AS password_expires
FROM pg_roles
WHERE rolsuper = true
ORDER BY rolname;

-- -------------------------------------------------------
-- 2. Login users and their assigned roles
-- -------------------------------------------------------
SELECT
    u.rolname                           AS username,
    ARRAY_AGG(g.rolname)               AS assigned_roles,
    u.rolvaliduntil                     AS password_expires
FROM pg_roles u
LEFT JOIN pg_auth_members m ON u.oid = m.member
LEFT JOIN pg_roles g ON m.roleid = g.oid
WHERE u.rolcanlogin = true
GROUP BY u.rolname, u.rolvaliduntil
ORDER BY u.rolname;

-- -------------------------------------------------------
-- 3. Tables with RLS enabled
-- -------------------------------------------------------
SELECT
    schemaname                          AS schema_name,
    tablename                           AS table_name,
    rowsecurity                         AS rls_enabled
FROM pg_tables
WHERE schemaname = 'cms'
ORDER BY tablename;

-- -------------------------------------------------------
-- 4. All RLS policies in the cms schema
-- -------------------------------------------------------
SELECT
    schemaname                          AS schema_name,
    tablename                           AS table_name,
    policyname                          AS policy_name,
    roles                               AS applies_to,
    cmd                                 AS command
FROM pg_policies
WHERE schemaname = 'cms'
ORDER BY tablename, policyname;

-- -------------------------------------------------------
-- 5. SSL configuration
-- -------------------------------------------------------
SELECT name, setting
FROM pg_settings
WHERE name IN ('ssl', 'ssl_cert_file', 'ssl_key_file', 'ssl_ca_file')
ORDER BY name;

-- -------------------------------------------------------
-- 6. Current connection encryption status
-- -------------------------------------------------------
SELECT
    pid,
    usename                             AS username,
    application_name,
    client_addr,
    ssl
FROM pg_stat_ssl
JOIN pg_stat_activity USING (pid)
WHERE datname = 'healthcare_dba';

-- -------------------------------------------------------
-- 7. Privilege audit — who can access cms tables
-- -------------------------------------------------------
SELECT
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'cms'
ORDER BY grantee, table_name, privilege_type;

-- -------------------------------------------------------
-- 8. Audit log summary
-- -------------------------------------------------------
SELECT
    db_user,
    table_name,
    operation,
    COUNT(*)                            AS event_count,
    MIN(log_timestamp)                  AS first_event,
    MAX(log_timestamp)                  AS last_event
FROM audit.data_access_log
GROUP BY db_user, table_name, operation
ORDER BY event_count DESC;