-- Run on: wh_gold (Fabric Warehouse), with lh_silver added in Explorer
-- Purpose: build gold star schema from silver (cross-database CTAS)
-- Author: Hafsah Asif
-- Governance: gold keeps only what reporting needs. CNIC, email and DOB are
-- left out (data minimisation). Name and MSISDN stay for the Day 7 masking demo.

-- ---------------------------------------------------------------- dim_date
DROP TABLE IF EXISTS dbo.dim_date;
CREATE TABLE dbo.dim_date AS
SELECT
    YEAR(x.d) * 10000 + MONTH(x.d) * 100 + DAY(x.d) AS date_key,
    x.d                                             AS calendar_date,
    YEAR(x.d)                                       AS year_num,
    DATEPART(QUARTER, x.d)                          AS quarter_num,
    MONTH(x.d)                                      AS month_num,
    CAST(DATENAME(MONTH, x.d)   AS VARCHAR(10))     AS month_name,
    CAST(DATENAME(WEEKDAY, x.d) AS VARCHAR(10))     AS day_name,
    CASE WHEN DATENAME(WEEKDAY, x.d) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END AS is_weekend
FROM (
    SELECT DATEADD(DAY, n.n, b.start_d) AS d, b.start_d, b.end_d
    FROM (
        SELECT a.v + t.v * 10 + h.v * 100 + k.v * 1000 AS n
        FROM       (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) a(v)
        CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) t(v)
        CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) h(v)
        CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) k(v)
    ) n
    CROSS JOIN (
        -- calendar starts at the earliest date in ANY table, ends today
        SELECT MIN(m.dt) AS start_d, CAST(GETDATE() AS DATE) AS end_d
        FROM (
            SELECT MIN(activation_date)           AS dt FROM lh_silver.dbo.subscribers
            UNION ALL
            SELECT MIN(CAST(event_ts  AS DATE))   FROM lh_silver.dbo.cdrs
            UNION ALL
            SELECT MIN(CAST(opened_ts AS DATE))   FROM lh_silver.dbo.service_requests
        ) m
    ) b
    WHERE n.n <= DATEDIFF(DAY, b.start_d, b.end_d)
) x;

-- ---------------------------------------------------------------- dim_plan
DROP TABLE IF EXISTS dbo.dim_plan;
CREATE TABLE dbo.dim_plan AS
SELECT
    CAST(ROW_NUMBER() OVER (ORDER BY plan_id) AS INT) AS plan_key,
    CAST(plan_id   AS VARCHAR(10))  AS plan_id,
    CAST(plan_name AS VARCHAR(50))  AS plan_name,
    CAST(plan_type AS VARCHAR(20))  AS plan_type,
    CAST(monthly_fee_pkr AS DECIMAL(12,2)) AS monthly_fee_pkr,
    data_gb,
    voice_mins
FROM lh_silver.dbo.plans;

-- ---------------------------------------------------------------- dim_location
DROP TABLE IF EXISTS dbo.dim_location;
CREATE TABLE dbo.dim_location AS
SELECT
    CAST(ROW_NUMBER() OVER (ORDER BY city) AS INT) AS location_key,
    CAST(city     AS VARCHAR(50)) AS city,
    CAST(region   AS VARCHAR(50)) AS region,
    CAST(province AS VARCHAR(50)) AS province
FROM (
    SELECT city, region, province FROM lh_silver.dbo.regions
    UNION ALL
    SELECT 'Unknown', 'Unknown', 'Unknown'
) r;

-- ---------------------------------------------------------------- dim_subscriber
DROP TABLE IF EXISTS dbo.dim_subscriber;
CREATE TABLE dbo.dim_subscriber AS
SELECT
    CAST(ROW_NUMBER() OVER (ORDER BY s.subscriber_id) AS INT) AS subscriber_key,
    CAST(s.subscriber_id AS VARCHAR(20)) AS subscriber_id,
    CAST(s.full_name     AS VARCHAR(100)) AS full_name,
    CAST(s.msisdn        AS VARCHAR(15))  AS msisdn,
    CAST(s.gender        AS VARCHAR(1))   AS gender,
    CASE
        WHEN DATEDIFF(YEAR, s.date_of_birth, GETDATE()) < 25 THEN '18-24'
        WHEN DATEDIFF(YEAR, s.date_of_birth, GETDATE()) < 35 THEN '25-34'
        WHEN DATEDIFF(YEAR, s.date_of_birth, GETDATE()) < 50 THEN '35-49'
        ELSE '50+'
    END                                   AS age_band,
    p.plan_key,
    l.location_key,
    CAST(s.status AS VARCHAR(20))         AS status,
    s.activation_date,
    s.churn_date
FROM lh_silver.dbo.subscribers s
LEFT JOIN dbo.dim_plan     p ON p.plan_id = s.plan_id
LEFT JOIN dbo.dim_location l ON l.city    = s.city;

-- ---------------------------------------------------------------- fact_usage (grain: subscriber x day x event_type)
DROP TABLE IF EXISTS dbo.fact_usage;
CREATE TABLE dbo.fact_usage AS
SELECT
    YEAR(c.event_date) * 10000 + MONTH(c.event_date) * 100 + DAY(c.event_date) AS date_key,
    d.subscriber_key,
    d.plan_key,
    d.location_key,
    CAST(c.event_type AS VARCHAR(10))          AS event_type,
    COUNT(*)                                   AS event_count,
    CAST(SUM(c.duration_sec) / 60.0 AS DECIMAL(14,2)) AS voice_minutes,
    CAST(SUM(c.data_mb) AS DECIMAL(14,2))      AS data_mb,
    CAST(SUM(c.charge_pkr) AS DECIMAL(14,2))   AS charge_pkr
FROM (
    SELECT subscriber_id, CAST(event_ts AS DATE) AS event_date, event_type,
           duration_sec, data_mb, charge_pkr
    FROM lh_silver.dbo.cdrs
) c
JOIN dbo.dim_subscriber d ON d.subscriber_id = c.subscriber_id
GROUP BY c.event_date, d.subscriber_key, d.plan_key, d.location_key, c.event_type;

-- ---------------------------------------------------------------- fact_service_request (grain: one SR)
DROP TABLE IF EXISTS dbo.fact_service_request;
CREATE TABLE dbo.fact_service_request AS
SELECT
    CAST(r.sr_id AS VARCHAR(20)) AS sr_id,
    YEAR(r.opened_ts) * 10000 + MONTH(r.opened_ts) * 100 + DAY(r.opened_ts) AS opened_date_key,
    CASE WHEN r.closed_ts IS NOT NULL
         THEN YEAR(r.closed_ts) * 10000 + MONTH(r.closed_ts) * 100 + DAY(r.closed_ts) END AS closed_date_key,
    d.subscriber_key,
    d.plan_key,
    d.location_key,
    CAST(r.category AS VARCHAR(50)) AS category,
    CAST(r.priority AS VARCHAR(5))  AS priority,
    CAST(r.channel  AS VARCHAR(20)) AS channel,
    CAST(r.status   AS VARCHAR(20)) AS status,
    CAST(r.resolution_hours AS DECIMAL(10,1)) AS resolution_hours,
    CASE WHEN r.status = 'Closed' THEN 1 ELSE 0 END AS is_closed
FROM lh_silver.dbo.service_requests r
JOIN dbo.dim_subscriber d ON d.subscriber_id = r.subscriber_id;
