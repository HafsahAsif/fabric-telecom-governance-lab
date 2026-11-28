# Operations and Audit

Author: Hafsah Asif

How to answer "what ran, who looked at what, and who controls access" on this platform.

## 1. Run history - Monitor hub

| Activity | Status | Meaning |
|---|---|---|
| pl_bronze_to_gold | Succeeded | Pipeline run (Day 4) |
| nb_bronze_to_silver (same minute) | Succeeded | Notebook started by the pipeline |
| nb_bronze_to_silver (2 earlier) | Stopped | Interactive sessions that timed out, not failures |
| HC_lh_bronze_LakehouseOperation | Succeeded | Load to Tables (Day 1) |

- "Stopped" is not "Failed". Morning checks must tell them apart
- Submitted by shows who triggered each run: a basic run audit trail

## 2. Query audit - queryinsights (wh_gold)

Scripts in `sql/ops/`.

### PII access audit (`02_pii_access_audit.sql`)

Seven queries touched `msisdn` or `full_name`:

| Rows | What | Type |
|---|---|---|
| 5 | SELECT TOP 5 ... full_name, msisdn | Human looked at PII |
| 0 | ALTER ... ADD MASKED (x2) | Security change |
| 4,799 | CREATE TABLE dim_subscriber AS SELECT ... (x2) | Pipeline read all PII |
| 0 | CREATE OR ALTER PROCEDURE usp_build_gold | Code deployment |
| 56 | SELECT 1 as XLOrdinal ... | UI noise past the filter |

Lessons:
- A pipeline reading 4,799 PII rows is normal; a person doing it is a red flag. Audits must separate
  service identities from humans, which is one more reason pipelines should run as a service principal
- Most history rows are the Fabric UI loading metadata. Noise filters help but are never perfect
- History is kept for 30 days and appears with a short delay. Real audits need it exported on a schedule

### Top resource consumers (`03_slow_queries.sql`)

| Query | Runs | Median ms | Last run ms |
|---|---|---|---|
| CREATE TABLE fact_service_request | 2 | 12,079 | 4,876 |
| CREATE TABLE fact_usage | 2 | 11,430 | 4,334 |
| check_plan_orphans (LEFT JOIN ... IS NULL) | 1 | 10,624 | 10,624 |
| CREATE TABLE dim_subscriber | 2 | 9,683 | 2,907 |

- Last runs 2-3x faster than the median: first runs were cold. Judge by median, not one run
- The orphan check costs as much as building a table. At real volume it is the first tuning target

## 3. Lake-level access - OneLake security (lh_bronze)

| Role | Data | Members |
|---|---|---|
| DefaultReader (auto-created) | All 5 tables + Files/raw | Everyone with read access |
| refdatareader (Day 9) | plans, regions only | 0 (would be an Entra group) |

- SQL roles (Day 6) only apply to SQL queries. OneLake roles apply to every engine: Spark, SQL, Power BI
- `Files/raw` holds the original CSVs with raw CNIC, email and DOB. Raw files are easy to forget and
  often the bigger leak
- A new role is added on top of DefaultReader, not instead of it. Least privilege needs DefaultReader
  narrowed first. Left unchanged here because the trial capacity is shared
- Workspace Admin, Member and Contributor bypass OneLake roles, the same pattern as CLS, RLS and masking

## 4. Tenant governance - Admin portal

As a non-admin, the portal shows only Capacity settings, Refresh summary and Help + support.
**Tenant settings are not visible.** That is separation of duties working as intended: the people who
build content are not the people who decide tenant-wide rules (sensitivity labels, export, publish to web,
trials, service principal access).

## Summary: what proves the platform is governed

| Question | Where the evidence is |
|---|---|
| Did the load run, and did it pass? | Monitor hub + `etl_run_log` |
| Who looked at customer PII? | `queryinsights` PII audit |
| Who can read raw data at the lake level? | OneLake security roles |
| Who can read gold tables and columns? | SQL roles, CLS, RLS, masking |
| Who sets tenant rules? | Admin portal, admins only |
