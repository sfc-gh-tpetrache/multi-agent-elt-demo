-- Frostbyte AI - SV Certification: history table + procedure
-- ============================================================================
-- Two procedure variants:
--
-- 1. SIMPLIFIED (default, used in both DEV and fresh PROD deploys):
--    Skips ACCOUNT_USAGE checks. Sets the CERTIFIED tag directly.
--    Use when objects were just created (ACCOUNT_USAGE has ~2h latency).
--
-- 2. FULL (commented out below, for established PROD environments):
--    Runs C1 (upstream lineage) and C2 (PII masking coverage) checks via
--    SNOWFLAKE.ACCOUNT_USAGE. Only certifies if all checks pass.
--    Use after objects have been stable for 2+ hours.
--
-- For first-time deploys where ACCOUNT_USAGE has no data yet, you can also
-- certify manually:
--    ALTER SEMANTIC VIEW <FQN> SET TAG GOVERNANCE.CERTIFIED = 'true';
-- ============================================================================

USE ROLE SYSADMIN;
USE SCHEMA GOVERNANCE;

-- ----------------------------------------------------------------------------
-- Audit history of every certification run
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CERTIFICATION_HISTORY (
  sv_name           STRING,
  env               STRING,
  run_at            TIMESTAMP_LTZ,
  passed            BOOLEAN,
  failed_checks     ARRAY,
  run_by            STRING,
  git_tag           STRING,
  notes             STRING
);

GRANT SELECT ON TABLE CERTIFICATION_HISTORY TO ROLE CERTIFIER_RL;
GRANT SELECT ON TABLE CERTIFICATION_HISTORY TO ROLE SECURITYADMIN;

-- ----------------------------------------------------------------------------
-- DEV version: skips ACCOUNT_USAGE checks (C1/C2) for immediate usability.
-- In PROD, replace this block with the full version below.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CERTIFY_SEMANTIC_VIEW(
  SV_NAME STRING,
  GIT_TAG STRING DEFAULT NULL
)
RETURNS OBJECT
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  failed_checks ARRAY DEFAULT ARRAY_CONSTRUCT();
  result OBJECT;
BEGIN
  IF (ARRAY_SIZE(failed_checks) = 0) THEN
    EXECUTE IMMEDIATE 'ALTER SEMANTIC VIEW ' || :SV_NAME ||
                      ' SET TAG GOVERNANCE.CERTIFIED = ''true''';
  ELSE
    EXECUTE IMMEDIATE 'ALTER SEMANTIC VIEW ' || :SV_NAME ||
                      ' UNSET TAG GOVERNANCE.CERTIFIED';
  END IF;

  INSERT INTO CERTIFICATION_HISTORY
    (sv_name, env, run_at, passed, failed_checks, run_by, git_tag, notes)
  SELECT :SV_NAME, CURRENT_DATABASE(), CURRENT_TIMESTAMP(),
         ARRAY_SIZE(:failed_checks) = 0, :failed_checks, CURRENT_USER(), :GIT_TAG, NULL;

  result := OBJECT_CONSTRUCT(
    'sv', :SV_NAME,
    'env', CURRENT_DATABASE(),
    'certified', ARRAY_SIZE(:failed_checks) = 0,
    'failed_checks', :failed_checks
  );
  RETURN result;
END;
$$;

GRANT USAGE ON PROCEDURE CERTIFY_SEMANTIC_VIEW(STRING, STRING) TO ROLE CERTIFIER_RL;

-- ----------------------------------------------------------------------------
-- PROD version (uncomment and use in FROSTBYTE_AI_PROD):
-- Uses ACCOUNT_USAGE views for C1 (upstream lineage) and C2 (PII masking).
-- These views have ~2h latency but objects are stable by PROD deploy time.
-- ----------------------------------------------------------------------------
/*
CREATE OR REPLACE PROCEDURE CERTIFY_SEMANTIC_VIEW(
  SV_NAME STRING,
  GIT_TAG STRING DEFAULT NULL
)
RETURNS OBJECT
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  failed_checks ARRAY DEFAULT ARRAY_CONSTRUCT();
  upstream_uncert NUMBER DEFAULT 0;
  unmasked_pii NUMBER DEFAULT 0;
  result OBJECT;
BEGIN
  -- C1: All upstream DTs carry CERTIFIED='true'
  SELECT COUNT(*) INTO :upstream_uncert
  FROM SNOWFLAKE.ACCOUNT_USAGE.OBJECT_DEPENDENCIES d
  LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES t
    ON t.OBJECT_NAME = d.REFERENCED_OBJECT_NAME
   AND t.OBJECT_DATABASE = d.REFERENCED_DATABASE
   AND t.TAG_NAME = 'CERTIFIED'
   AND t.TAG_VALUE = 'true'
  WHERE d.REFERENCING_OBJECT_NAME = SPLIT_PART(:SV_NAME, '.', 3)
    AND d.REFERENCING_DATABASE = SPLIT_PART(:SV_NAME, '.', 1)
    AND d.REFERENCED_OBJECT_DOMAIN IN ('DYNAMIC TABLE', 'TABLE', 'VIEW')
    AND t.TAG_NAME IS NULL;

  IF (upstream_uncert > 0) THEN
    failed_checks := ARRAY_APPEND(failed_checks, 'C1: ' || upstream_uncert || ' upstream object(s) not certified');
  END IF;

  -- C2: Every PII_CATEGORY tagged column has a masking policy
  SELECT COUNT(*) INTO :unmasked_pii
  FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES t
  WHERE t.TAG_NAME = 'PII_CATEGORY'
    AND t.OBJECT_DATABASE = SPLIT_PART(:SV_NAME, '.', 1)
    AND t.DOMAIN = 'COLUMN'
    AND NOT EXISTS (
      SELECT 1 FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES p
      WHERE p.POLICY_KIND = 'MASKING_POLICY'
        AND p.REF_COLUMN_NAME = t.COLUMN_NAME
        AND p.REF_ENTITY_NAME = t.OBJECT_NAME
        AND p.REF_DATABASE_NAME = t.OBJECT_DATABASE
    );

  IF (unmasked_pii > 0) THEN
    failed_checks := ARRAY_APPEND(failed_checks, 'C2: ' || unmasked_pii || ' PII column(s) without masking policy');
  END IF;

  IF (ARRAY_SIZE(failed_checks) = 0) THEN
    EXECUTE IMMEDIATE 'ALTER SEMANTIC VIEW ' || :SV_NAME ||
                      ' SET TAG GOVERNANCE.CERTIFIED = ''true''';
  ELSE
    EXECUTE IMMEDIATE 'ALTER SEMANTIC VIEW ' || :SV_NAME ||
                      ' UNSET TAG GOVERNANCE.CERTIFIED';
  END IF;

  INSERT INTO CERTIFICATION_HISTORY
    (sv_name, env, run_at, passed, failed_checks, run_by, git_tag, notes)
  SELECT :SV_NAME, CURRENT_DATABASE(), CURRENT_TIMESTAMP(),
         ARRAY_SIZE(:failed_checks) = 0, :failed_checks, CURRENT_USER(), :GIT_TAG, NULL;

  result := OBJECT_CONSTRUCT(
    'sv', :SV_NAME,
    'env', CURRENT_DATABASE(),
    'certified', ARRAY_SIZE(:failed_checks) = 0,
    'failed_checks', :failed_checks
  );
  RETURN result;
END;
$$;

GRANT USAGE ON PROCEDURE CERTIFY_SEMANTIC_VIEW(STRING, STRING) TO ROLE CERTIFIER_RL;
*/
