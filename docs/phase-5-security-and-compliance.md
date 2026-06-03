# Phase 5: Security and Compliance

## Overview

In this phase I implemented a layered security model for the healthcare_dba 
database. Given that this project uses CMS Medicare data — the same category 
of data that falls under HIPAA regulations in production healthcare environments 
— I treated security as a first-class concern throughout. The approach follows 
the principle of least privilege at every level: roles, table access, and 
row-level visibility.

---

## Role-Based Access Control (RBAC)

I designed four group roles representing distinct job functions, each with 
carefully scoped privileges.

### Role Design

| Role | Purpose | Privileges |
|------|---------|------------|
| dba_admin | Full database administration | All privileges on database, schema, tables, sequences |
| analyst | Reporting and analytics | SELECT on all cms tables |
| data_engineer | ETL and data loading | Full DML on staging_raw, SELECT on providers and provider_services |
| app_readonly | Application read access | SELECT on providers and provider_services only |

### Design Rationale

**dba_admin** has full control but is not a superuser. Superuser access is 
reserved for the `postgres` system account. This separation means dba_admin 
can manage the database without being able to modify system-level PostgreSQL 
configuration.

**analyst** has read-only access to all cms tables. Analysts need visibility 
across the full dataset for reporting but should never be able to modify data.

**data_engineer** has write access only to `staging_raw`. This is intentional 
— in the data pipeline, engineers load raw data into staging and transformation 
is handled by controlled processes. They cannot modify the curated provider or 
service tables directly.

**app_readonly** has the most restricted access — SELECT on `providers` and 
`provider_services` only. Crucially, it has no access to `staging_raw` which 
contains unvalidated raw data. This role also interacts with Row-Level Security 
policies that further restrict what rows are visible.

### Login Users Created

| User | Role | Purpose |
|------|------|---------|
| naseer_dba | dba_admin | Database administrator |
| jane_analyst | analyst | Analytics and reporting |
| etl_engineer | data_engineer | ETL pipeline user |
| app_user | app_readonly | Application connection |

### Privilege Verification

I verified all role assignments using `pg_roles` and confirmed the privilege 
matrix using `information_schema.role_table_grants`. Every role has exactly 
the privileges it needs — nothing more.

---

## Row-Level Security (RLS)

I implemented Row-Level Security on the `cms.providers` table to demonstrate 
how PostgreSQL can enforce data visibility rules transparently at the row level.

### Access Control Table

I created a `cms.user_state_access` table that maps users to the states they 
are permitted to see:

```sql
INSERT INTO cms.user_state_access (username, state_abbr) VALUES
    ('app_user', 'VA'),
    ('app_user', 'MD');
```

### RLS Policies

| Policy | Role | Rule |
|--------|------|------|
| app_state_access | app_readonly | Can only see providers in assigned states |
| analyst_full_access | analyst | Can see all providers |
| dba_full_access | dba_admin | Unrestricted access to all rows |

### RLS Test Results

I validated the policies by switching roles within the session:

| User | Query | Rows Returned |
|------|-------|---------------|
| postgres (superuser) | SELECT COUNT(*) FROM cms.providers | 1,175,281 |
| app_user | SELECT COUNT(*) FROM cms.providers | 54,351 |

The `app_user` account, restricted to Virginia and Maryland, sees only 54,351 
of the 1,175,281 total providers — a 95% reduction in visible data. This 
restriction is enforced transparently regardless of how the query is written. 
The user cannot bypass it by changing the query.

---

## Audit Logging

I implemented a trigger-based audit logging system to capture all data 
modifications on sensitive tables.

### Audit Schema

I created a dedicated `audit` schema with a `data_access_log` table that 
captures:

- Timestamp of the event (microsecond precision)
- Database user who performed the action
- Client IP address
- Application name
- Schema and table affected
- Operation type (INSERT, UPDATE, DELETE)
- Old data (for UPDATE and DELETE)
- New data (for INSERT and UPDATE) stored as JSONB

### Audit Trigger

I created a trigger function `audit.log_data_changes()` using `SECURITY DEFINER` 
so it runs with the privileges of the function owner regardless of which user 
triggers it. The trigger is attached to both `cms.providers` and 
`cms.provider_services`.

### Audit Log Validation

I tested the audit trigger with two UPDATE operations on provider NPI 
`1003000126` and verified both events were captured in the audit log with 
full before/after data recorded.

| Log ID | Timestamp | User | Table | Operation |
|--------|-----------|------|-------|-----------|
| 1 | 2026-06-03 20:18:18 | postgres | providers | UPDATE |
| 2 | 2026-06-03 20:18:18 | postgres | providers | UPDATE |

In a production environment this audit log would be the foundation for 
compliance reporting, forensic investigation, and access reviews.

---

## Security Assessment

I ran a full security assessment covering superuser inventory, SSL 
configuration, RLS status, and privilege audit.

### Superuser Inventory

Only one superuser exists — the `postgres` system account. No application 
users or DBA users have superuser privileges. This is the correct posture.

### SSL Configuration

| Parameter | Value |
|-----------|-------|
| ssl | off |
| ssl_cert_file | server.crt |
| ssl_key_file | server.key |

SSL is currently disabled. The server has certificate and key files configured 
but SSL is not enforced for connections. For this local development environment 
connecting over localhost this is acceptable — all traffic stays on the local 
machine. In a production environment I would enable SSL and configure 
`pg_hba.conf` to require encrypted connections for all non-local clients.

### RLS Status by Table

| Table | RLS Enabled |
|-------|-------------|
| providers | ✅ Yes |
| provider_services | No |
| staging_raw | No |
| user_state_access | No |

RLS is enabled on `providers` which is the most sensitive table containing 
provider identity and location information. `provider_services` contains 
aggregated utilization data with no individual identifiers beyond NPI — 
RLS on `providers` combined with role-based access controls provides 
sufficient protection for this dataset.

### Privilege Matrix

The privilege audit confirmed the role assignments are clean and follow 
least-privilege principles. No unexpected grants were found. The `postgres` 
superuser retains full access as expected for a system account.

---

## Security Layers Summary

This phase implemented security at three distinct layers:

**Layer 1 — Authentication:** Separate login users with strong passwords, 
no shared credentials, role-based assignment.

**Layer 2 — Authorization:** Least-privilege role design ensuring each user 
can only perform the operations their job requires on the tables they need.

**Layer 3 — Data visibility:** Row-Level Security restricting what rows 
application users can see, enforced transparently by the database engine 
regardless of query structure.

**Layer 4 — Audit trail:** Trigger-based logging capturing every data 
modification with full context — who, when, what changed.

---

## Scripts

| Script | Purpose |
|--------|---------|
| `sql/phase-5/01_roles_and_access.sql` | Role creation and privilege grants |
| `sql/phase-5/02_row_level_security.sql` | RLS policies and access control table |
| `sql/phase-5/03_audit_logging.sql` | Audit schema, trigger function, and validation |
| `sql/phase-5/04_security_assessment.sql` | Security posture assessment queries |

---

## Next Phase

With all five technical phases complete, Phase 6 will focus on portfolio 
integration — building the project page for nasaryobee.com and ensuring 
the public GitHub repository is polished and presentation-ready.