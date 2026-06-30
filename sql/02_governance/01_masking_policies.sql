-- Frostbyte AI - Agent-aware masking policies
-- ============================================================================
-- Implements Tiers A + B from build_plan.md Step 2:
--   Tier A: role-based mask (HR_PII_RL sees plaintext)
--   Tier B: agent-aware overlay using SYS_CONTEXT IS_AGENT_ACTIVATED + AGENT_NAME / AGENT_TYPE
--           Any agent session = never plaintext; per-agent mask shape.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA GOVERNANCE;

-- ----------------------------------------------------------------------------
-- mp_mask_email
-- ----------------------------------------------------------------------------
CREATE OR REPLACE MASKING POLICY mp_mask_email AS (val STRING)
  RETURNS STRING ->
    CASE
      WHEN SYS_CONTEXT('SNOWFLAKE$CURRENT','IS_AGENT_ACTIVATED') = 'TRUE' THEN
        CASE
          WHEN SYS_CONTEXT('SNOWFLAKE$CURRENT','AGENT_NAME') = 'HR_AGENT'
            THEN REGEXP_REPLACE(val, '^[^@]+', '****')
          WHEN SYS_CONTEXT('SNOWFLAKE$CURRENT','AGENT_TYPE') = 'CORTEX_CODE_CLI'
            THEN '***REDACTED***'
          ELSE SHA2(val)
        END
      WHEN CURRENT_ROLE() IN ('HR_PII_RL', 'SECURITYADMIN') THEN val
      ELSE SHA2(val)
    END;

-- ----------------------------------------------------------------------------
-- mp_mask_phone
-- ----------------------------------------------------------------------------
CREATE OR REPLACE MASKING POLICY mp_mask_phone AS (val STRING)
  RETURNS STRING ->
    CASE
      WHEN SYS_CONTEXT('SNOWFLAKE$CURRENT','IS_AGENT_ACTIVATED') = 'TRUE' THEN
        CASE
          WHEN SYS_CONTEXT('SNOWFLAKE$CURRENT','AGENT_NAME') = 'HR_AGENT'
            THEN REGEXP_REPLACE(val, '\\d', 'X')
          ELSE SHA2(val)
        END
      WHEN CURRENT_ROLE() IN ('HR_PII_RL', 'SECURITYADMIN') THEN val
      ELSE SHA2(val)
    END;

-- ----------------------------------------------------------------------------
-- mp_mask_ssn  (always full hash for any agent, regardless of name)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE MASKING POLICY mp_mask_ssn AS (val STRING)
  RETURNS STRING ->
    CASE
      WHEN SYS_CONTEXT('SNOWFLAKE$CURRENT','IS_AGENT_ACTIVATED') = 'TRUE' THEN SHA2(val)
      WHEN CURRENT_ROLE() IN ('HR_PII_RL', 'SECURITYADMIN') THEN val
      ELSE 'XXX-XX-' || RIGHT(val, 4)
    END;

-- ----------------------------------------------------------------------------
-- mp_mask_address
-- ----------------------------------------------------------------------------
CREATE OR REPLACE MASKING POLICY mp_mask_address AS (val STRING)
  RETURNS STRING ->
    CASE
      WHEN SYS_CONTEXT('SNOWFLAKE$CURRENT','IS_AGENT_ACTIVATED') = 'TRUE' THEN '[REDACTED ADDRESS]'
      WHEN CURRENT_ROLE() IN ('HR_PII_RL', 'SECURITYADMIN') THEN val
      ELSE '[REDACTED ADDRESS]'
    END;

-- ----------------------------------------------------------------------------
-- mp_mask_salary  (always hash for agents, even HR_AGENT)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE MASKING POLICY mp_mask_salary AS (val NUMBER)
  RETURNS NUMBER ->
    CASE
      WHEN SYS_CONTEXT('SNOWFLAKE$CURRENT','IS_AGENT_ACTIVATED') = 'TRUE' THEN NULL
      WHEN CURRENT_ROLE() IN ('HR_PII_RL', 'SECURITYADMIN') THEN val
      ELSE NULL
    END;

-- ----------------------------------------------------------------------------
-- mp_mask_full_name
-- ----------------------------------------------------------------------------
CREATE OR REPLACE MASKING POLICY mp_mask_full_name AS (val STRING)
  RETURNS STRING ->
    CASE
      WHEN SYS_CONTEXT('SNOWFLAKE$CURRENT','IS_AGENT_ACTIVATED') = 'TRUE' THEN
        CASE
          WHEN SYS_CONTEXT('SNOWFLAKE$CURRENT','AGENT_NAME') = 'HR_AGENT'
            THEN SPLIT_PART(val, ' ', 1) || ' ***'
          ELSE 'REDACTED'
        END
      WHEN CURRENT_ROLE() IN ('HR_PII_RL', 'SECURITYADMIN') THEN val
      ELSE val   -- humans see full names; only agents are masked here by default
    END;
