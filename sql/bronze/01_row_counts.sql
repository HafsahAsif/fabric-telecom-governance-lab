-- Run on: lh_bronze SQL analytics endpoint
-- Purpose: reconcile loaded rows with generator output
-- Author: Hafsah Asif
SELECT 'subscribers' AS tbl, COUNT(*) AS rows_cnt FROM subscribers
UNION ALL SELECT 'cdrs', COUNT(*) FROM cdrs
UNION ALL SELECT 'service_requests', COUNT(*) FROM service_requests
UNION ALL SELECT 'plans', COUNT(*) FROM plans
UNION ALL SELECT 'regions', COUNT(*) FROM regions;
