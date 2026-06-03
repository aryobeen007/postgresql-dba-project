# Phase 4: Operations and High Availability

## Overview

In this phase I implemented and tested the operational procedures that keep a 
PostgreSQL database running reliably in production. This includes a backup 
strategy with verified restore testing, ongoing health monitoring queries, and 
routine maintenance procedures. A database that performs well but cannot be 
recovered from failure is not production-ready — this phase addresses that.

---

## Backup Strategy

I implemented two complementary backup approaches that together provide complete 
coverage for different recovery scenarios.

### Logical Backup — pg_dump

A logical backup captures the database schema and data in a portable format that 
can be restored to any PostgreSQL instance.

**Command used:**
```bash
pg_dump -U postgres -d healthcare_dba -F c -f C:\pgbackups\dumps\healthcare_dba_20260603.backup
```

**Flags explained:**
- `-F c` — custom format, enables compression and parallel restore
- `-f` — output file path

**Result:**
- Source database size: 5,571 MB
- Backup file size: 845 MB
- Compression ratio: 85%

The custom format compresses the output significantly while preserving the 
ability to restore selectively — individual tables, schemas, or the entire 
database can be restored from the same backup file.

### Physical Backup — pg_basebackup

A physical backup captures the entire PostgreSQL cluster at the file system 
level. This is the foundation for point-in-time recovery and streaming 
replication.

**Command used:**
```bash
pg_basebackup -U postgres -D C:\pgbackups\basebackup -F t -z -P
```

**Flags explained:**
- `-F t` — tar format with compression
- `-z` — gzip compression
- `-P` — show progress during backup

**Result:**

| File | Size | Purpose |
|------|------|---------|
| base.tar.gz | 3.3 GB | Full cluster data |
| pg_wal.tar.gz | 17 KB | WAL files for consistency |
| backup_manifest | 446 KB | Checksums for verification |

### Backup Verification

I verified the physical backup integrity using `pg_verifybackup`:

```bash
pg_verifybackup -n C:\pgbackups\basebackup
```

Result: **backup successfully verified**

The `-n` flag skips WAL parsing since the backup is in tar format. The manifest 
file contains checksums for every file in the backup — `pg_verifybackup` 
confirms each file matches its recorded checksum.

---

## Restore Testing

A backup that has never been tested cannot be trusted. I performed a full end-to-end 
restore test to validate the logical backup.

### Restore Procedure

1. Created a new target database:
```sql
   CREATE DATABASE healthcare_dba_restore;
```

2. Restored the backup into the new database:
```bash
   pg_restore -U postgres -d healthcare_dba_restore -F c C:\pgbackups\dumps\healthcare_dba_20260603.backup
```

3. Verified row counts matched the source database:

| Table | Source | Restored | Match |
|-------|--------|----------|-------|
| providers | 1,175,281 | 1,175,281 | ✅ |
| provider_services | 9,660,647 | 9,660,647 | ✅ |
| staging_raw | 9,660,647 | 9,660,647 | ✅ |

4. Verified all 7 indexes were restored correctly — both primary keys and all 
   5 analytical indexes created in Phase 3.

5. Dropped the restore database after successful validation:
```sql
   DROP DATABASE healthcare_dba_restore;
```

The restore completed without errors and all data and indexes were confirmed 
intact.

---

## WAL Configuration

I reviewed the current WAL configuration as part of the backup readiness 
assessment:

| Parameter | Value | Note |
|-----------|-------|------|
| wal_level | replica | Supports streaming replication |
| archive_mode | off | WAL archiving not yet enabled |
| max_wal_senders | 10 | Up to 10 replication connections |
| wal_keep_size | 0 MB | No WAL retention configured |

`wal_level` is already set to `replica` which means the server is capable of 
streaming replication. For a production environment I would enable `archive_mode` 
and configure an `archive_command` to ship WAL files to a secure location, 
enabling point-in-time recovery between base backups.

---

## Health Monitoring

I created a monitoring script with eight queries covering the key health 
indicators a DBA would review regularly in production.

### Monitoring Results at Time of Execution

**Server uptime:** 2 hours 38 minutes (after restart for configuration change)  
**Database size:** 5,571 MB  
**Active connections:** 1 (DataGrip session only)  
**Long running queries:** None  

**Table bloat:**

| Table | Live Rows | Dead Rows | Dead Row % |
|-------|-----------|-----------|------------|
| provider_services | 9,660,882 | 0 | 0% |
| providers | 1,175,243 | 0 | 0% |
| staging_raw | 9,659,647 | 0 | 0% |

No bloat detected across any table.

**Cache hit ratios:**

| Table | Cache Hit Ratio |
|-------|----------------|
| providers | 97.66% |
| provider_services | 79.16% |
| staging_raw | 31.85% |

The `provider_services` ratio of 79.16% reflects the buffer cache rebuilding 
after the PostgreSQL restart. Under normal sustained operation this ratio 
typically climbs above 90%.

**Replication status:** No standbys configured — single node environment.

**Slowest queries from pg_stat_statements:**
The five slowest recorded operations were the Phase 1 bulk data loads (COPY 
commands) and the Q4 state/provider type aggregation from Phase 3. This is 
consistent with expectations.

---

## Routine Maintenance

I ran manual VACUUM ANALYZE on all three cms tables and performed a 
REINDEX CONCURRENTLY on all five analytical indexes.

### VACUUM ANALYZE Results

```sql
VACUUM ANALYZE cms.providers;
VACUUM ANALYZE cms.provider_services;
VACUUM ANALYZE cms.staging_raw;
```

All tables showed zero dead rows before and after maintenance. The 
`last_vacuum` timestamps updated to reflect today's run.

### Index Rebuild Results

I rebuilt all analytical indexes using `REINDEX INDEX CONCURRENTLY` to avoid 
table locks. Index sizes remained consistent with pre-reindex measurements, 
confirming no index bloat was present.

### Autovacuum Configuration

| Parameter | Value |
|-----------|-------|
| autovacuum | on |
| vacuum threshold | 50 rows + 20% of table |
| analyze threshold | 50 rows + 10% of table |
| vacuum cost delay | 2ms |

For the `provider_services` table with 9.6M rows, autovacuum triggers after 
approximately 1.9 million dead rows accumulate — appropriate for a table of 
this size.

---

## Scripts

| Script | Purpose |
|--------|---------|
| `sql/phase-4/01_backup_strategy.sql` | Pre-backup checks and WAL configuration review |
| `sql/phase-4/02_monitoring.sql` | Ongoing health monitoring queries |
| `sql/phase-4/03_maintenance.sql` | VACUUM, ANALYZE, and index maintenance |

---

## Next Phase

In Phase 5 I will implement security and compliance controls including role-based 
access control, row-level security, audit logging, and SSL configuration.