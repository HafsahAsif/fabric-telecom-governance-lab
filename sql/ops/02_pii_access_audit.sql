-- Run on: wh_gold
-- Purpose: every query that touched PII columns, with UI/system noise filtered out
-- Author: Hafsah Asif
-- Add login_name for a real review; left out here so results can be shared.
SELECT
    start_time,
    status,
    row_count,
    LEFT(command, 100) AS command_preview
FROM queryinsights.exec_requests_history
WHERE (command LIKE '%msisdn%' OR command LIKE '%full_name%')
  AND command NOT LIKE '%queryinsights%'
  AND command NOT LIKE '%sys.%'
ORDER BY start_time DESC;
