-- =============================================================
-- Project:  PostgreSQL DBA
-- Phase:    5 - Security and Compliance
-- Script:   02_row_level_security.sql
-- Author:   Naseer Aryobee
-- Date:     2026-06-03
-- Purpose:  Implement Row-Level Security (RLS) on the
--           providers table to restrict data access based
--           on the connected user's role.
--
-- RLS Policy Design:
--   - app_readonly users can only see providers in their
--     assigned state (simulates multi-tenant restriction)
--   - analyst users can see all providers
--   - dba_admin bypasses RLS entirely
--
-- Note: RLS is a powerful PostgreSQL feature that enforces
--       data access rules transparently at the row level,
--       regardless of how the query is written.
-- =============================================================

-- -------------------------------------------------------
-- 1. Create a state access control table
--    Maps users to the states they are allowed to see
-- -------------------------------------------------------
CREATE TABLE cms.user_state_access (
    username        VARCHAR(50)     NOT NULL,
    state_abbr      VARCHAR(2)      NOT NULL,
    CONSTRAINT pk_user_state_access PRIMARY KEY (username, state_abbr)
);

-- Assign state access to app_user (Virginia and Maryland only)
INSERT INTO cms.user_state_access (username, state_abbr) VALUES
    ('app_user', 'VA'),
    ('app_user', 'MD');

-- Assign full access to jane_analyst (all states)
-- Handled via policy bypass below

-- -------------------------------------------------------
-- 2. Enable RLS on the providers table
-- -------------------------------------------------------
ALTER TABLE cms.providers ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------
-- 3. Create RLS policy for app_readonly role
--    app_user can only see providers in their assigned states
-- -------------------------------------------------------
CREATE POLICY app_state_access ON cms.providers
    FOR SELECT
    TO app_readonly
    USING (
        state_abbr IN (
            SELECT state_abbr
            FROM cms.user_state_access
            WHERE username = current_user
        )
    );

-- -------------------------------------------------------
-- 4. Create RLS policy for analyst role
--    Analysts can see all providers
-- -------------------------------------------------------
CREATE POLICY analyst_full_access ON cms.providers
    FOR SELECT
    TO analyst
    USING (true);

-- -------------------------------------------------------
-- 5. Create RLS policy for dba_admin role
--    DBA has unrestricted access
-- -------------------------------------------------------
CREATE POLICY dba_full_access ON cms.providers
    FOR ALL
    TO dba_admin
    USING (true);

-- -------------------------------------------------------
-- 6. Verify RLS is enabled and policies are in place
-- -------------------------------------------------------
SELECT
    schemaname                          AS schema_name,
    tablename                           AS table_name,
    rowsecurity                         AS rls_enabled
FROM pg_tables
WHERE schemaname = 'cms'
AND tablename = 'providers';

-- -------------------------------------------------------
-- 7. View all RLS policies
-- -------------------------------------------------------
SELECT
    schemaname                          AS schema_name,
    tablename                           AS table_name,
    policyname                          AS policy_name,
    roles                               AS applies_to,
    cmd                                 AS command,
    qual                                AS using_expression
FROM pg_policies
WHERE schemaname = 'cms'
ORDER BY tablename, policyname;