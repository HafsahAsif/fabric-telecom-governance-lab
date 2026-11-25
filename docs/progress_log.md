# Progress Log

## Day 1 - Bronze layer

**Built**
- Fabric trial workspace `ws-telecom-dev`
- Lakehouse `lh_bronze`, uploaded 5 CSVs to `Files/raw`
- Loaded each file to a Delta table (Load to Tables)
- Queried through the SQL analytics endpoint

**Results**
- Row counts reconciled with the generator output (5050 / 124687 / 3000 / 7 / 10)
- Bronze DQ scorecard: 50 duplicates, 97 missing CNIC, 110 invalid emails, 106 missing cities, 2,478 negative charges
- MTTR by priority: P1 4.5h, P2 14.1h, P3 42.4h, P4 97.4h

**Learned**
- Lakehouse vs SQL analytics endpoint (read-only T-SQL over the same Delta files)
- Files area vs Tables area in OneLake
- Workspace licence modes: Pro vs Fabric Trial capacity
- "MTTR" needs a written business definition before it can be trusted (closed only? business hours?)

## Day 2 - Silver layer

**Built**
- Lakehouse `lh_silver`
- Notebook `nb_bronze_to_silver` (PySpark) reading from `lh_bronze`, writing to `lh_silver`
- Quarantine tables for subscribers, CDRs and service requests

**Results**
- Confirmed in Fabric: subscribers 4,799 clean / 201 quarantined; cdrs 117,318 / 7,369; service_requests 2,874 / 126
- Silver DQ scorecard: all 5 checks = 0
- 4,891 CDRs quarantined only because their subscriber was quarantined (integrity cascade)

**Learned**
- Explicit type casting instead of trusting inferred types (phone numbers lose their leading zero if stored as numbers)
- Quarantine pattern with reason codes
- Referential integrity checks across tables in Spark
