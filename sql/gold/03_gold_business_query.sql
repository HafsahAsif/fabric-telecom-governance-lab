-- Run on: wh_gold
-- Purpose: first business question on the star schema - revenue and SR load by region and plan type
-- Author: Hafsah Asif
SELECT
    l.region,
    p.plan_type,
    COUNT(DISTINCT s.subscriber_key)                  AS subscribers,
    CAST(SUM(u.charge_pkr) AS DECIMAL(14,0))          AS revenue_pkr,
    CAST(SUM(u.charge_pkr) / NULLIF(COUNT(DISTINCT s.subscriber_key), 0) AS DECIMAL(10,0)) AS revenue_per_sub_pkr
FROM dbo.fact_usage u
JOIN dbo.dim_subscriber s ON s.subscriber_key = u.subscriber_key
JOIN dbo.dim_location   l ON l.location_key   = u.location_key
JOIN dbo.dim_plan       p ON p.plan_key       = u.plan_key
GROUP BY l.region, p.plan_type
ORDER BY revenue_pkr DESC;
