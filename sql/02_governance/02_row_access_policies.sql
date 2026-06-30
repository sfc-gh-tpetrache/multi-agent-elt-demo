-- Frostbyte AI - Row access policies
-- ============================================================================
-- Tier C: agent-aware row access. Only HR_AGENT (in FROSTBYTE_AI_*) can
-- read rows from HR base/dim tables under an agent session.
-- Humans use the standard manager-chain / HR_PII_RL bypass.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA GOVERNANCE;

CREATE OR REPLACE ROW ACCESS POLICY rap_hr_employee_scope
  AS (manager_chain ARRAY) RETURNS BOOLEAN ->
    CASE
      WHEN SYS_CONTEXT('SNOWFLAKE$CURRENT','IS_AGENT_ACTIVATED') = 'TRUE' THEN
            SYS_CONTEXT('SNOWFLAKE$CURRENT','AGENT_NAME') = 'HR_AGENT'
        AND SYS_CONTEXT('SNOWFLAKE$CURRENT','AGENT_DATABASE') LIKE 'FROSTBYTE_AI_%'
      WHEN ARRAY_CONTAINS(CURRENT_USER()::VARIANT, manager_chain) THEN TRUE
      WHEN IS_ROLE_IN_SESSION('HR_PII_RL') THEN TRUE
      ELSE FALSE
    END;
