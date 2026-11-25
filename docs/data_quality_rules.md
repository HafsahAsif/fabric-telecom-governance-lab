# Data Quality Rule Catalogue

Author: Hafsah Asif

Rules applied in `notebooks/nb_bronze_to_silver.py`. Each rule has an ID, a DAMA-DMBOK dimension and a clear action, so anyone reviewing the pipeline can see what is checked and what happens when a check fails.

| Rule ID | Table | Column(s) | Rule | DQ dimension | Action on failure |
|---|---|---|---|---|---|
| DQ-SUB-01 | subscribers | subscriber_id | Must be unique | Uniqueness | Keep one row, drop duplicates |
| DQ-SUB-02 | subscribers | cnic | Must not be empty | Completeness | Quarantine (`missing_cnic`) |
| DQ-SUB-03 | subscribers | email | Must match `name@domain.tld` | Validity | Quarantine (`invalid_email`) |
| DQ-SUB-04 | subscribers | city | Should not be empty | Completeness | Default to `Unknown`, keep row |
| DQ-SUB-05 | subscribers | msisdn | 11 digits, leading zero kept | Validity / Conformity | Left-pad with `0` |
| DQ-CDR-01 | cdrs | charge_pkr | Must be ≥ 0 | Validity | Quarantine (`negative_charge`) |
| DQ-CDR-02 | cdrs | subscriber_id | Must exist in clean subscribers | Integrity | Quarantine (`unknown_or_quarantined_subscriber`) |
| DQ-SR-01 | service_requests | subscriber_id | Must exist in clean subscribers | Integrity | Quarantine (`unknown_or_quarantined_subscriber`) |
| DQ-SR-02 | service_requests | status, closed_ts | Closed SR must have a close date | Consistency | Quarantine (`closed_without_close_date`) |

## Design decisions

- **Reject vs default.** A missing CNIC is a regulatory problem for a telecom operator (SIM ownership must be traceable), so the row is quarantined. A missing city only affects regional reporting, so it is defaulted to `Unknown` and kept. Not every gap deserves the same treatment.
- **Quarantine, don't delete.** Rejected rows keep their full content plus `dq_reason` and `quarantined_at`. This gives an audit trail and lets the source team fix records.
- **Integrity cascades.** If a subscriber is quarantined, their CDRs and service requests are quarantined too. One bad master record affects every transaction that depends on it.
- **Multiple reasons.** A row can fail more than one rule; reasons are joined with `; `.

## Still to add

- Freshness / timeliness checks (load date vs event date)
- Thresholds and alerting (e.g. fail the pipeline if quarantine > 5%)
- Same rules defined in Microsoft Purview Data Quality (Month 2)
