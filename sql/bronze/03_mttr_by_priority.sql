-- Run on: lh_bronze SQL analytics endpoint
-- Purpose: mean time to resolve by priority (closed SRs only)
-- Author: Hafsah Asif
SELECT priority,
       COUNT(*) AS closed_srs,
       CAST(AVG(TRY_CAST(resolution_hours AS DECIMAL(10,1))) AS DECIMAL(10,1)) AS avg_mttr_hrs
FROM service_requests
WHERE status = 'Closed'
GROUP BY priority
ORDER BY priority;
