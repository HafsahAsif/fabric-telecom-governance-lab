-- Run on: wh_gold
-- Purpose: mask PII for anyone without UNMASK (Viewers and item-only users)
-- Author: Hafsah Asif
-- Note: workspace Admin, Member and Contributor get UNMASK automatically, so they see real values.

ALTER TABLE dbo.dim_subscriber
    ALTER COLUMN msisdn ADD MASKED WITH (FUNCTION = 'partial(4,"XXXXXXX",0)');   -- 03992571945 -> 0399XXXXXXX
ALTER TABLE dbo.dim_subscriber
    ALTER COLUMN full_name ADD MASKED WITH (FUNCTION = 'partial(1,"xxxxx",0)');  -- Ali Mirza -> Axxxxx

-- evidence
SELECT OBJECT_NAME(object_id) AS table_name, name AS column_name, masking_function
FROM sys.masked_columns;

-- grant unmask only where there is an approved need
-- GRANT UNMASK TO rl_pii_reader;
