-- Run on: lh_silver SQL analytics endpoint
-- Purpose: same checks as bronze scorecard; all should be 0 after cleaning
-- Author: Hafsah Asif
SELECT
  (SELECT COUNT(*) FROM (SELECT subscriber_id FROM subscribers GROUP BY subscriber_id HAVING COUNT(*) > 1) d) AS dup_subscribers,
  (SELECT COUNT(*) FROM subscribers WHERE cnic IS NULL)                                                      AS missing_cnic,
  (SELECT COUNT(*) FROM subscribers WHERE email NOT LIKE '%@%.%')                                            AS bad_email,
  (SELECT COUNT(*) FROM subscribers WHERE city IS NULL)                                                      AS missing_city,
  (SELECT COUNT(*) FROM subscribers WHERE city = 'Unknown')                                                  AS city_defaulted,
  (SELECT COUNT(*) FROM cdrs WHERE charge_pkr < 0)                                                           AS negative_charges;
