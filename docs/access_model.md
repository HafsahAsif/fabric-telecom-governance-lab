# Access Model - Fabric Telecom Governance Lab

Author: Hafsah Asif

How access is designed for `ws-telecom-dev`. Principle: **least privilege**. Give the smallest
access that lets someone do their job, and prefer groups over individuals.

## 1. Three layers of access in Fabric

| Layer | Controls | Granted by |
|---|---|---|
| Workspace role | Every item in the workspace | Workspace Admin / Member |
| Item permission | One item shared on its own (Read, Build, Reshare) | Item owner / Admin / Member |
| SQL / data role | Tables, columns (and rows, Day 7) inside a warehouse | Warehouse Admin via T-SQL |

**Key point:** all four workspace roles, including **Viewer**, get `ReadData` on the warehouse,
which means SELECT on every table. Column-level security only works for people who are given
**item access** (Read on the warehouse or report), **not** a workspace role.

## 2. Workspace roles

| Role | Can do | Give to |
|---|---|---|
| Admin | Everything, incl. delete workspace and manage access | Platform owner (1-2 people max) |
| Member | Create, edit, share, add people | Data engineering lead |
| Contributor | Create and edit content, cannot share or manage access | Data engineers |
| Viewer | View content, read all warehouse tables | Avoid for business users who must not see PII |

## 3. Personas

| Persona | Workspace role | Item access | SQL role | Sees PII? |
|---|---|---|---|---|
| Platform admin | Admin | all | (via workspace) | Yes |
| Data engineer | Contributor | all | (via workspace) | Yes |
| Business analyst | none | Report: Read. Semantic model: Build | `rl_report_viewer` | No |
| Customer care lead | none | wh_gold: Read | `rl_pii_reader` | Yes, approved need only |
| Data quality steward | none | wh_gold: Read | `rl_dq_steward` | No |
| Executive | none | Report: Read only | none | No |

## 4. SQL roles in wh_gold

Script: `sql/security/01_sql_roles.sql`. Audit query: `sql/security/02_permission_report.sql`.

| Role | Granted | Not granted |
|---|---|---|
| `rl_report_viewer` | SELECT on dim_date, dim_plan, dim_location, fact_usage, fact_service_request; dim_subscriber **9 non-PII columns** only | `full_name`, `msisdn`, `etl_run_log` |
| `rl_pii_reader` | SELECT on full dim_subscriber | facts, audit log |
| `rl_dq_steward` | SELECT on etl_run_log, EXECUTE on usp_check_gold | all business data |

Verified on Day 6: 17 permission rows, no grant on `full_name` or `msisdn` for `rl_report_viewer`.

## 5. RACI

R = Responsible, A = Accountable, C = Consulted, I = Informed

| Activity | Platform admin | Data engineer | Data owner (business) | DQ steward | Analyst |
|---|---|---|---|---|---|
| Grant workspace access | R/A | I | C | - | - |
| Grant PII access (`rl_pii_reader`) | R | - | **A** | - | I |
| Define DQ rules | I | R | A | C | I |
| Run / monitor reconciliation | I | R | I | A | - |
| Define business metrics (measures) | - | R | A | C | C |
| Quarterly access review | R | C | **A** | - | - |

The data owner, not IT, is accountable for who sees PII. IT carries out the grant.

## 6. Data minimisation already in the design

- CNIC, email and date of birth never reach gold (Day 3). DOB becomes `age_band`.
- Name and MSISDN stay in gold but behind column-level security (Day 6) and masking (Day 7).

## 7. What a real setup would add

- Entra ID **groups** as role members, never individual users
- Access requests with an approver and an expiry date
- Quarterly access review using the permission report query
