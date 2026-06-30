-- Frostbyte AI - Cortex Search Service for HR policies (over redacted DT)
-- ============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE WH_DT_S;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE css_hr_policies
  ON content_redacted
  ATTRIBUTES title, category, last_updated
  WAREHOUSE = WH_DT_S
  TARGET_LAG = '1 hour'
  AS (
    SELECT doc_id, title, category, content_redacted, last_updated
    FROM STG.stg_hr_policies_redacted
  );

GRANT USAGE ON CORTEX SEARCH SERVICE css_hr_policies TO ROLE ELT_HR_RL;
GRANT USAGE ON CORTEX SEARCH SERVICE css_hr_policies TO ROLE ELT_RL;
