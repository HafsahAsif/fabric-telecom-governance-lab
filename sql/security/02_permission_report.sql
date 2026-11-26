-- Run on: wh_gold
-- Purpose: audit what each custom role can do (evidence for access reviews)
-- Author: Hafsah Asif
SELECT
    pr.name                                   AS role_name,
    pe.permission_name,
    pe.state_desc,
    OBJECT_SCHEMA_NAME(pe.major_id) + '.' + OBJECT_NAME(pe.major_id) AS object_name,
    COALESCE(COL_NAME(pe.major_id, pe.minor_id), '(all columns)')     AS column_name
FROM sys.database_permissions pe
JOIN sys.database_principals  pr ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name LIKE 'rl[_]%'
ORDER BY role_name, object_name, column_name;
