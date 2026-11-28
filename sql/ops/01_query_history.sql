-- Run on: wh_gold
-- Purpose: recent query history (who ran what, how long, how many rows)
-- Author: Hafsah Asif
-- Note: login_name holds user emails. Do not publish this result.
SELECT TOP 20
    start_time,
    login_name,
    status,
    total_elapsed_time_ms,
    row_count,
    LEFT(command, 80) AS command_preview
FROM queryinsights.exec_requests_history
ORDER BY start_time DESC;
