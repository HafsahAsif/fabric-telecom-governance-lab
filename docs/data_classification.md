# Data Classification - Gold Layer

Author: Hafsah Asif

## Why this document exists

Fabric sensitivity labels (Microsoft Purview Information Protection) are **not enabled** in the tenant
this lab runs in: the setting shows *"turned off because your organization has stopped supporting it"*.
Without labels, the classification has to live somewhere a reviewer can find it. This is that place,
and it is what the labels would encode once they are switched on.

## Classification scheme

| Level | Meaning | Example handling |
|---|---|---|
| Public | Safe to publish outside the company | No restriction |
| Internal | For employees, no customer impact if leaked | Workspace access only |
| Confidential | Commercially sensitive, aggregated customer data | Named roles, no external sharing |
| Restricted | Identifies a person (PII) | CLS, masking, approved need only, audited |

## Item level

| Item | Classification | Reason |
|---|---|---|
| lh_bronze | Restricted | Raw CNIC, email, DOB, MSISDN |
| lh_silver | Restricted | Same PII, cleaned |
| wh_gold | Restricted | Name and MSISDN in dim_subscriber |
| sm_telecom_gold | Confidential | Reports aggregates; PII not used in measures |
| rpt_telecom_overview | Confidential | Revenue and churn by region |
| etl_run_log | Internal | Operational metadata only |

## Column level (gold)

| Table | Column | Classification | Control in place |
|---|---|---|---|
| dim_subscriber | full_name | Restricted | CLS (excluded from rl_report_viewer), masking `partial(1,"xxxxx",0)` |
| dim_subscriber | msisdn | Restricted | CLS, masking `partial(4,"XXXXXXX",0)` |
| dim_subscriber | gender, age_band | Confidential | Visible to rl_report_viewer; DOB generalised to age band |
| dim_subscriber | subscriber_id, status, dates | Confidential | RLS by region |
| fact_usage | all | Confidential | RLS by region |
| fact_service_request | all | Confidential | RLS by region |
| dim_plan, dim_location, dim_date | all | Internal | None needed |
| (not in gold) | cnic, email, date_of_birth | Restricted | Excluded from gold: data minimisation |

## Gap and recommendation

- **Gap:** no sensitivity labels, so classification is not attached to the items, does not travel with
  exports (Excel, PDF), and is not visible in the Fabric UI or the Purview hub.
- **Recommendation:** enable Purview Information Protection labels for Fabric, publish the four levels above,
  and turn on default labelling for new items in workspaces that hold customer data.
