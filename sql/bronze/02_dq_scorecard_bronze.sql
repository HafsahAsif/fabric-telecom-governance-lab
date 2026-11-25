-- Run on: lh_bronze SQL analytics endpoint
-- Purpose: profile raw data against DAMA DQ dimensions
-- Author: Hafsah Asif
SELECT
  (SELECT COUNT(*) FROM (SELECT subscriber_id FROM subscribers GROUP BY subscriber_id HAVING COUNT(*) > 1) d) AS dup_subscribers,   -- uniqueness
  (SELECT COUNT(*) FROM subscribers WHERE NULLIF(TRIM(cnic), '') IS NULL)                                   AS missing_cnic,      -- completeness
  (SELECT COUNT(*) FROM subscribers WHERE email NOT LIKE '%@%')                                              AS bad_email,         -- validity
  (SELECT COUNT(*) FROM subscribers WHERE NULLIF(TRIM(city), '') IS NULL)                                    AS missing_city,      -- completeness
  (SELECT COUNT(*) FROM cdrs WHERE TRY_CAST(charge_pkr AS DECIMAL(12,2)) < 0)                                AS negative_charges;  -- validity
