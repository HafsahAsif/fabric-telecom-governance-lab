-- Run on: lh_silver SQL analytics endpoint
-- Purpose: what was rejected, and why
-- Author: Hafsah Asif
SELECT 'subscribers' AS source_table, dq_reason, COUNT(*) AS rows_cnt FROM quarantine_subscribers GROUP BY dq_reason
UNION ALL
SELECT 'cdrs', dq_reason, COUNT(*) FROM quarantine_cdrs GROUP BY dq_reason
UNION ALL
SELECT 'service_requests', dq_reason, COUNT(*) FROM quarantine_service_requests GROUP BY dq_reason
ORDER BY source_table, rows_cnt DESC;
