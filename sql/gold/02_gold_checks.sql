-- Run on: wh_gold
-- Purpose: reconcile gold against silver and check the star joins
-- Author: Hafsah Asif
SELECT 'dim_subscriber rows = silver subscribers' AS check_name,
       (SELECT COUNT(*) FROM dbo.dim_subscriber)              AS gold_value,
       (SELECT COUNT(*) FROM lh_silver.dbo.subscribers)       AS silver_value
UNION ALL
SELECT 'fact_usage events = silver cdrs',
       (SELECT SUM(event_count) FROM dbo.fact_usage),
       (SELECT COUNT(*) FROM lh_silver.dbo.cdrs)
UNION ALL
SELECT 'fact_service_request rows = silver SRs',
       (SELECT COUNT(*) FROM dbo.fact_service_request),
       (SELECT COUNT(*) FROM lh_silver.dbo.service_requests)
UNION ALL
SELECT 'fact_usage rows with no date in dim_date',
       (SELECT COUNT(*) FROM dbo.fact_usage f LEFT JOIN dbo.dim_date d ON d.date_key = f.date_key WHERE d.date_key IS NULL),
       0
UNION ALL
SELECT 'subscribers with no plan_key',
       (SELECT COUNT(*) FROM dbo.dim_subscriber WHERE plan_key IS NULL),
       0
UNION ALL
SELECT 'subscribers with no location_key',
       (SELECT COUNT(*) FROM dbo.dim_subscriber WHERE location_key IS NULL),
       0;
