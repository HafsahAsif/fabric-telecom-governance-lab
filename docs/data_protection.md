# Data Protection Controls - wh_gold

Author: Hafsah Asif

Four layers protect subscriber data in the gold warehouse. Each answers a different question.

| Control | Question it answers | Implemented in | Day |
|---|---|---|---|
| Data minimisation | Does this data need to be here at all? | CNIC, email, DOB never loaded to gold; DOB -> age_band | 3 |
| Column-level security | Can this person see this column at all? | `rl_report_viewer` has 9 of 11 dim_subscriber columns | 6 |
| Row-level security | Which rows can this person see? | `sec.region_policy` filters facts and subscribers by region | 7 |
| Dynamic data masking | Can this person see the full value? | `msisdn` -> `0399XXXXXXX`, `full_name` -> `Axxxxx` | 7 |

## Row-level security

- Access table `dbo.sec_region_access` maps a user to a region, or `ALL`
- Predicate `sec.fn_region_filter(location_key)` returns a row only if the user's region matches
- Policy `sec.region_policy` applies it to `fact_usage`, `fact_service_request`, `dim_subscriber`
- RLS applies to workspace Admins too. Nobody is exempt unless the access table says so

### What the test showed

1. Mapped myself to North. `fact_usage` returned only North (22,528 of 110,063 rows)
2. Ran the reconciliation `usp_check_gold`: it **failed** (subscribers 985 vs 4,799, events 23,990 vs 117,318, SRs 608 vs 2,874)
3. Mapped myself to `ALL`: all six checks passed again

**Lesson:** the identity that runs pipelines and quality checks must be mapped to `ALL`
(in production, a service principal). Otherwise RLS silently shrinks what the checks see,
and the checks fail. Security controls and quality controls have to be designed together.

### Emergency off switch

```sql
ALTER SECURITY POLICY sec.region_policy WITH (STATE = OFF);
```

## Dynamic data masking

- Masks apply to Viewers and users with item access only
- Admin, Member and Contributor have UNMASK automatically, so masking cannot be tested as an admin
- Masking is presentation, not encryption. A determined user with query access can infer values
  from filters, so it complements CLS and RLS rather than replacing them

## Which control when

| Situation | Use |
|---|---|
| Report users never need the column | Column-level security, or leave it out of gold |
| Users need the column, but only their region's rows | Row-level security |
| Users need to know the value exists or check the last digits | Masking |
| Nobody downstream needs it | Data minimisation |
