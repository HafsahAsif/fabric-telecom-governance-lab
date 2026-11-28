# Release Management - Git and Deployment Pipelines

Author: Hafsah Asif

How changes should move from development to production, what this lab tested, and what it found.

## 1. Git integration

**Finding:** in this tenant, Fabric Git integration offers **Azure DevOps only**. GitHub is greyed out
(a tenant admin setting). Connecting a personal practice lab to a corporate Azure DevOps project was
not appropriate, so the design is documented instead.

### Intended design

| Decision | Choice | Why |
|---|---|---|
| Provider | Azure DevOps (tenant policy) | Only option allowed |
| Folder | `fabric_items/` in the repo | Keeps Fabric item definitions apart from hand-written SQL and docs |
| Branching | `main` = Test/Prod source; feature branches per change; PR with one reviewer | No direct edits to what gets promoted |
| Connected workspace | Dev only | Test and Prod are fed by the deployment pipeline, never edited |
| Secrets | Never in Git; connections set per stage | Credentials do not travel with code |

### What Git adds that this repo lacks

This repo holds SQL and docs copied by hand. Git integration would version the **item definitions**
themselves (notebook, pipeline, semantic model, report), so every change has an author, a diff and a review.

## 2. Deployment pipeline `dp_telecom`

Stages: **Development** (`ws-telecom-dev`) -> **Test** (`ws-telecom-test`). Production left out to save trial capacity.

The Test workspace description states: *Deployed from ws-telecom-dev only. Do not edit directly.*

### First deployment: what travelled and what did not

| Item / setting | Travelled? | Evidence |
|---|---|---|
| Item definitions (9 items) | Yes | Successful deployment, all "Same as source" |
| Warehouse schema (8 tables, 2 procedures) | Yes | `sys.tables`, `sys.procedures` in Test |
| SQL roles, RLS policy, masks | **Yes** | 3 roles, 1 policy, 2 masked columns in Test |
| Warehouse data | **No** | All counts 0 in Test |
| RLS access table rows | **No** | `sec_region_access` empty: RLS would hide every row |
| Audit log history | No | `etl_run_log` empty (correct: each stage has its own) |
| Endorsement (Promoted) | **No** | Test copy shows no endorsement |
| Refresh schedule | Per stage | Test model has its own next refresh |
| Semantic model binding | **No - leaked** | Test model read **Dev's** warehouse |

### Finding: Test report showed Dev data

After a "Successful deployment", the Test report showed Dev's numbers (PKR 5M, 944 ARPU, DQ pass 88%).
The 88% came from Dev's audit log, including failures from the Day 7 RLS test, which proved the source.
Lineage showed Test's semantic model fed by `wh_gold` tagged `ws-telecom-dev`.

Risk: people with Test access see real (in production terms, live) data, and nobody notices because
the deployment reported success.

### Fix attempted: data source rule

Rule on Test `sm_telecom_gold`: Dev warehouse `3e103a1f-...` -> Test warehouse `6a3184c8-...`, then redeployed the model.

Result:
- The link to Dev is **gone**: Test no longer reads Dev data
- The model now shows **0 tables** and no upstream warehouse: the rule broke the old binding but did not
  rebind to Test

This matches reported behaviour for Direct Lake models on warehouses in deployment pipelines.
**Outcome: fails closed, not open** - acceptable for security, not yet for function.

### Options to finish the rebind

1. Rebind the model by script (semantic model connection update via API / Semantic Link) after each deployment
2. Rebuild the semantic model in each stage against that stage's warehouse
3. Use Direct Lake on SQL with a deployment rule configured **before** the first deployment

## 3. Release checklist (what this lab says to do every time)

- [ ] Deployment rules set before the first deploy (semantic model source, notebook default lakehouse)
- [ ] After deploy, check lineage: no item in Test/Prod should point at another stage
- [ ] Seed per-stage security data (RLS access table) as part of the release
- [ ] Load test data that is synthetic or masked - never copy production PII down
- [ ] Re-apply endorsement in the target stage; certify only in Production
- [ ] Review refresh schedules per stage
- [ ] Deployment note filled in (it is the change record in Deployment history)
- [ ] Capacity region checked against data residency rules (this lab: East Asia - fine for synthetic data, not for customer data)

## 4. Still open

- Test notebook `nb_bronze_to_silver` still has Dev lakehouses attached. A notebook deployment rule
  (default lakehouse) is available and would close it
- Test semantic model needs rebinding (section 2)
