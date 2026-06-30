-- Frostbyte AI - Certification runtime gate + sunset task
-- ============================================================================
-- NOTE: The runtime gate RAP uses CURRENT_SEMANTIC_VIEW() which requires the
-- agent call to go through a semantic view. Skipped in DEV if not yet GA.
-- The sunset task uses ACCOUNT_USAGE (fine for daily scheduled checks).
-- ============================================================================

USE ROLE SYSADMIN;
USE SCHEMA GOVERNANCE;

-- ----------------------------------------------------------------------------
-- Runtime gate: row access policy attached to MARTS aggregates.
-- An agent session can only read if the SV it's calling through has
-- CERTIFIED='true'. Direct human queries are unaffected.
-- SKIPPED in DEV: CURRENT_SEMANTIC_VIEW() may not be available yet.
-- Uncomment and attach once the function is GA.
-- ----------------------------------------------------------------------------
/*
CREATE OR REPLACE ROW ACCESS POLICY rap_require_certified_for_agent
  AS () RETURNS BOOLEAN ->
    CASE
      WHEN SYS_CONTEXT('SNOWFLAKE$CURRENT','IS_AGENT_ACTIVATED') != 'TRUE' THEN TRUE
      WHEN CURRENT_SEMANTIC_VIEW() IS NULL THEN TRUE
      WHEN EXISTS (
        SELECT 1
        FROM TABLE(SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES(
                    CURRENT_SEMANTIC_VIEW(),
                    'SEMANTIC_VIEW'))
        WHERE TAG_DATABASE = 'GOVERNANCE'
          AND TAG_NAME     = 'CERTIFIED'
          AND TAG_VALUE    = 'true'
      ) THEN TRUE
      ELSE FALSE
    END;

ALTER DYNAMIC TABLE MARTS.agg_mkt_campaign            ADD ROW ACCESS POLICY rap_require_certified_for_agent ON ();
ALTER DYNAMIC TABLE MARTS.agg_sales_pipeline_daily    ADD ROW ACCESS POLICY rap_require_certified_for_agent ON ();
ALTER DYNAMIC TABLE MARTS.agg_hr_headcount_snapshot   ADD ROW ACCESS POLICY rap_require_certified_for_agent ON ();
ALTER DYNAMIC TABLE MARTS.agg_hr_attrition_monthly    ADD ROW ACCESS POLICY rap_require_certified_for_agent ON ();
*/

-- ----------------------------------------------------------------------------
-- Sunset task: revoke certification when STATUS=deprecated and past SUNSET_DATE
-- Uses ACCOUNT_USAGE TAG_REFERENCES (acceptable for a daily cron job).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TASK T_REVOKE_CERTIFICATION_ON_SUNSET
  WAREHOUSE = WH_GOV
  SCHEDULE  = 'USING CRON 0 0 * * * UTC'
AS
DECLARE
  cur CURSOR FOR
    SELECT t.OBJECT_DATABASE || '.' || t.OBJECT_SCHEMA || '.' || t.OBJECT_NAME AS fqn
    FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES t
    JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES s
      ON s.OBJECT_NAME = t.OBJECT_NAME
     AND s.OBJECT_DATABASE = t.OBJECT_DATABASE
     AND s.OBJECT_SCHEMA = t.OBJECT_SCHEMA
     AND s.DOMAIN = t.DOMAIN
    WHERE t.TAG_NAME = 'STATUS' AND t.TAG_VALUE = 'deprecated'
      AND s.TAG_NAME = 'SUNSET_DATE'
      AND CURRENT_DATE() >= TRY_TO_DATE(s.TAG_VALUE)
      AND t.DOMAIN = 'SEMANTIC VIEW';
BEGIN
  FOR row IN cur DO
    EXECUTE IMMEDIATE 'ALTER SEMANTIC VIEW ' || row.fqn || ' UNSET TAG GOVERNANCE.CERTIFIED';
  END FOR;
END;

ALTER TASK T_REVOKE_CERTIFICATION_ON_SUNSET RESUME;
