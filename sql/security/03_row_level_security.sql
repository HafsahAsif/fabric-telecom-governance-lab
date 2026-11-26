-- Run on: wh_gold, one step at a time (CREATE SCHEMA and CREATE FUNCTION must each be their own batch)
-- Purpose: row-level security by region
-- Author: Hafsah Asif

-- STEP 1 ------------------------------------------------------------ schema for security objects
CREATE SCHEMA sec;

-- STEP 2 ------------------------------------------------------------ who can see which region
CREATE TABLE dbo.sec_region_access (
    user_email VARCHAR(200),
    region     VARCHAR(50)      -- a region name, or 'ALL' for full access
);
INSERT INTO dbo.sec_region_access (user_email, region)
SELECT USER_NAME(), 'North';     -- test: map myself to North only

-- STEP 3 ------------------------------------------------------------ predicate function
CREATE FUNCTION sec.fn_region_filter(@location_key INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS allowed
    FROM dbo.dim_location l
    JOIN dbo.sec_region_access a
      ON a.region = l.region OR a.region = 'ALL'
    WHERE l.location_key = @location_key
      AND a.user_email   = USER_NAME();

-- STEP 4 ------------------------------------------------------------ apply to facts and subscriber dimension
CREATE SECURITY POLICY sec.region_policy
ADD FILTER PREDICATE sec.fn_region_filter(location_key) ON dbo.fact_usage,
ADD FILTER PREDICATE sec.fn_region_filter(location_key) ON dbo.fact_service_request,
ADD FILTER PREDICATE sec.fn_region_filter(location_key) ON dbo.dim_subscriber
WITH (STATE = ON);

-- TEST --------------------------------------------------------------
SELECT l.region, COUNT(*) AS usage_rows
FROM dbo.fact_usage f
JOIN dbo.dim_location l ON l.location_key = f.location_key
GROUP BY l.region;

-- RESTORE FULL ACCESS (needed so the pipeline reconciliation still passes) ----------
UPDATE dbo.sec_region_access SET region = 'ALL' WHERE user_email = USER_NAME();

-- EMERGENCY OFF SWITCH ---------------------------------------------
-- ALTER SECURITY POLICY sec.region_policy WITH (STATE = OFF);
