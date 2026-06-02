# Phase 1: Schema Design and Data Loading

## Overview

In this phase I designed and implemented the PostgreSQL schema for a healthcare 
analytics workload using real-world public data from the Centers for Medicare & 
Medicaid Services (CMS). I made deliberate design decisions at every step, loaded 
over 9.6 million records, and validated the data before moving on to the next phase.

---

## Environment

- **Database:** PostgreSQL 18.2
- **Host:** localhost (Windows 11)
- **Tool:** DataGrip
- **Database name:** healthcare_dba
- **Schema:** cms

---

## Dataset

I used the **CMS Medicare Physician & Other Practitioners by Provider and Service** 
dataset (2023). This is a publicly available dataset that contains one row per 
provider per procedure code, capturing utilization and payment information for 
Medicare fee-for-service claims.

- **File:** MUP_PHY_R25_P05_V20_D23_Prov_Svc.csv
- **Size:** ~3 GB
- **Raw rows:** 9,660,647
- **Columns:** 27

---

## Schema Design Decisions

Before writing a single line of SQL I inspected the raw CSV to understand the 
data structure, column types, and value patterns. Based on that analysis I made 
the following design decisions:

### Separate Schema
I created a dedicated `cms` schema rather than placing objects in the default 
`public` schema. In production environments it is standard practice to isolate 
project objects in their own schema for clarity, access control, and maintainability.

### Normalized Table Structure
The source data is a flat file where provider attributes repeat on every service 
row. I split this into two tables:

- **cms.providers** — one row per unique provider (NPI level)
- **cms.provider_services** — one row per provider/procedure combination

This eliminates redundancy and reflects how a real production DBA would model 
this data.

### Data Type Decisions

| Column | Type | Reason |
|--------|------|--------|
| rndrng_npi | VARCHAR(10) | Identifier, never used in calculations |
| ruca | NUMERIC(4,1) | Can contain decimal values in source data |
| Payment columns | NUMERIC(12,2) | Dollar precision required |
| tot_benes | INTEGER | Whole number counts |
| hcpcs_desc, ruca_desc | TEXT | Variable length descriptions |

### Surrogate Key on Services
I added a `BIGSERIAL` surrogate key on `provider_services` because the natural 
key (NPI + HCPCS code) is not enforced as unique in the source data — a provider 
can appear multiple times for the same procedure code.

---

## Data Loading Strategy

I used a **staged loading approach**:

1. Load the raw CSV into a staging table (`cms.staging_raw`) with all columns 
   as VARCHAR to avoid type errors during bulk load
2. Deduplicate and insert provider records into `cms.providers`
3. Insert all service records into `cms.provider_services` with type casting

This approach gives me full control over data quality and transformation before 
data lands in the final tables.

### Why COPY Instead of INSERT
I used PostgreSQL's `COPY` command for the initial bulk load into staging because 
it is significantly faster than row-by-row INSERT for large files. The 3 GB file 
loaded in 57 seconds.

### Windows Permission Issue
The PostgreSQL server process could not read files from the user Downloads folder 
due to Windows file permissions. I resolved this by copying the source file to 
`C:\temp\` which is accessible to the PostgreSQL service account.

---

## Load Results

| Step | Rows | Duration |
|------|------|----------|
| Staging load (COPY) | 9,660,647 | 57 seconds |
| Providers insert | 1,175,281 | 42 seconds |
| Provider services insert | 9,660,647 | 2 min 59 sec |

---

## Data Validation Results

After loading I ran a series of validation checks to confirm data integrity 
and quality:

| Check | Result |
|-------|--------|
| Null NPIs in providers | 0 |
| Orphaned service rows | 0 |
| Null HCPCS codes | 0 |
| Null beneficiary counts | 0 |
| Null payment amounts | 0 |
| Min Medicare payment | $0.00 |
| Max Medicare payment | $42,059.52 |
| Avg Medicare payment | $82.99 |
| Total Medicare payments | $801,745,767.09 |

All checks passed. The data loaded cleanly with no integrity issues.

---

## Top Provider Types

| Provider Type | Count |
|---------------|-------|
| Nurse Practitioner | 174,681 |
| Physician Assistant | 94,996 |
| Internal Medicine | 88,703 |
| Family Practice | 78,514 |
| Physical Therapist in Private Practice | 73,457 |
| Emergency Medicine | 47,236 |
| CRNA | 38,387 |
| Anesthesiology | 34,189 |
| Chiropractic | 32,225 |
| Diagnostic Radiology | 31,554 |

---

## Top 10 States by Provider Count

| State | Providers |
|-------|-----------|
| CA | 93,498 |
| NY | 80,484 |
| TX | 78,270 |
| FL | 77,006 |
| PA | 58,065 |
| OH | 47,844 |
| IL | 47,277 |
| NC | 40,231 |
| MI | 39,654 |
| NJ | 36,541 |

---

## Scripts

| Script | Purpose |
|--------|---------|
| `sql/phase-1/01_create_schema_and_tables.sql` | Creates cms schema and normalized tables |
| `sql/phase-1/02_load_data.sql` | Staged data loading from raw CSV |
| `sql/phase-1/03_validate_data.sql` | Data integrity and quality validation |

---

## Next Phase

In Phase 2 I will establish baseline performance measurements and run 
diagnostics against the loaded dataset to identify areas for optimization.