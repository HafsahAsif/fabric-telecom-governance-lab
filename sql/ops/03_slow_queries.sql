-- Run on: wh_gold
-- Purpose: top resource consumers by median elapsed time
-- Author: Hafsah Asif
SELECT TOP 10
    LEFT(last_run_command, 80) AS query_preview,
    number_of_runs,
    median_total_elapsed_time_ms,
    last_run_total_elapsed_time_ms
FROM queryinsights.long_running_queries
ORDER BY median_total_elapsed_time_ms DESC;
