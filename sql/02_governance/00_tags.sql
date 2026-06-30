-- Frostbyte AI - PII tags
-- ============================================================================
-- USE DATABASE <FROSTBYTE_AI_DEV | _PROD>;
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA GOVERNANCE;

-- Tag taxonomy
CREATE TAG IF NOT EXISTS PII_CATEGORY
  ALLOWED_VALUES 'email', 'phone', 'ssn', 'address', 'salary', 'full_name', 'employee_id'
  COMMENT = 'Classifies a column by PII category. Drives tag-based masking.';

CREATE TAG IF NOT EXISTS SENSITIVITY_TIER
  ALLOWED_VALUES 'public', 'internal', 'sensitive', 'restricted'
  COMMENT = 'Data sensitivity tier.';

CREATE TAG IF NOT EXISTS STATUS
  ALLOWED_VALUES 'active', 'deprecated', 'sunset'
  COMMENT = 'Lifecycle state of an object.';

CREATE TAG IF NOT EXISTS OWNER
  COMMENT = 'Owning team/individual for an object.';

CREATE TAG IF NOT EXISTS SUNSET_DATE
  COMMENT = 'YYYY-MM-DD when a deprecated object should be removed.';

-- CERTIFIED tag drives the runtime certification gate; APPLY granted only to CERTIFIER_RL
CREATE TAG IF NOT EXISTS CERTIFIED
  ALLOWED_VALUES 'true', 'false'
  COMMENT = 'Set to true ONLY by GOVERNANCE.CERTIFY_SEMANTIC_VIEW. Required for agent consumption.';

GRANT APPLY ON TAG CERTIFIED TO ROLE CERTIFIER_RL;
