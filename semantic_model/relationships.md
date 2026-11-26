# Relationships - sm_telecom_gold

All Many-to-one (*:1), single direction, active. Facts point to dimensions only.

| From (many) | To (one) |
|---|---|
| fact_usage[date_key] | dim_date[date_key] |
| fact_usage[subscriber_key] | dim_subscriber[subscriber_key] |
| fact_usage[plan_key] | dim_plan[plan_key] |
| fact_usage[location_key] | dim_location[location_key] |
| fact_service_request[opened_date_key] | dim_date[date_key] |
| fact_service_request[subscriber_key] | dim_subscriber[subscriber_key] |
| fact_service_request[plan_key] | dim_plan[plan_key] |
| fact_service_request[location_key] | dim_location[location_key] |

Not related on purpose:
- dim_subscriber to dim_plan / dim_location: would create ambiguous filter paths
- etl_run_log: audit table, not part of the star

Gotcha: Direct Lake guesses cardinality from row counts. fact_service_request (2,874 rows) is smaller
than dim_subscriber (4,799), so Fabric proposed One-to-many. It had to be set to Many-to-one by hand.
