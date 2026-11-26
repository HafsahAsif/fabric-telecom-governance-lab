-- Run on: wh_gold
-- Purpose: least-privilege SQL roles for people who get item access (not a workspace role)
-- Author: Hafsah Asif
-- Note: workspace Admin/Member/Contributor/Viewer all get ReadData = SELECT on every table.
--       These roles only restrict users who are shared the warehouse item with Read only.

-- ---------------------------------------------------------------- roles
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rl_report_viewer' AND type = 'R')
    CREATE ROLE rl_report_viewer;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rl_pii_reader' AND type = 'R')
    CREATE ROLE rl_pii_reader;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rl_dq_steward' AND type = 'R')
    CREATE ROLE rl_dq_steward;

-- ---------------------------------------------------------------- rl_report_viewer: star schema, no PII columns
GRANT SELECT ON dbo.dim_date             TO rl_report_viewer;
GRANT SELECT ON dbo.dim_plan             TO rl_report_viewer;
GRANT SELECT ON dbo.dim_location         TO rl_report_viewer;
GRANT SELECT ON dbo.fact_usage           TO rl_report_viewer;
GRANT SELECT ON dbo.fact_service_request TO rl_report_viewer;
-- column-level security: everything in dim_subscriber except full_name and msisdn
GRANT SELECT ON dbo.dim_subscriber
    (subscriber_key, subscriber_id, gender, age_band, plan_key, location_key, status, activation_date, churn_date)
    TO rl_report_viewer;

-- ---------------------------------------------------------------- rl_pii_reader: full subscriber dimension
GRANT SELECT ON dbo.dim_subscriber TO rl_pii_reader;

-- ---------------------------------------------------------------- rl_dq_steward: audit log + run the checks
GRANT SELECT  ON dbo.etl_run_log            TO rl_dq_steward;
GRANT EXECUTE ON OBJECT::dbo.usp_check_gold TO rl_dq_steward;
