# Frostbyte AI - Setup (run as ACCOUNTADMIN)
-- ============================================================================
-- Creates databases, schemas, warehouses, functional roles for DEV and PROD.
-- Idempotent: safe to re-run.
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ----------------------------------------------------------------------------
-- Databases (one per environment)
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS FROSTBYTE_AI_DEV  COMMENT = 'Frostbyte multi-agent demo (DEV)';
CREATE DATABASE IF NOT EXISTS FROSTBYTE_AI_PROD COMMENT = 'Frostbyte multi-agent demo (PROD)';

-- Apply identical schema to both environments
EXECUTE IMMEDIATE $$
DECLARE
  envs ARRAY DEFAULT ARRAY_CONSTRUCT('FROSTBYTE_AI_DEV', 'FROSTBYTE_AI_PROD');
  schemas ARRAY DEFAULT ARRAY_CONSTRUCT(
    'RAW', 'STG', 'INT', 'MARTS', 'SEMANTIC',
    'GOVERNANCE', 'AGENTS', 'SEARCH', 'EVAL', 'ARTIFACTS'
  );
BEGIN
  FOR i IN 0 TO ARRAY_SIZE(envs) - 1 DO
    FOR j IN 0 TO ARRAY_SIZE(schemas) - 1 DO
      EXECUTE IMMEDIATE 'CREATE SCHEMA IF NOT EXISTS ' || envs[i] || '.' || schemas[j];
    END FOR;
  END FOR;
END;
$$;

-- ----------------------------------------------------------------------------
-- Warehouses
-- ----------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS WH_DT_S
  WAREHOUSE_SIZE = XSMALL AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
  COMMENT = 'Dynamic Tables - stg/int';

CREATE WAREHOUSE IF NOT EXISTS WH_DT_M
  WAREHOUSE_SIZE = SMALL  AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
  COMMENT = 'Dynamic Tables - marts';

CREATE WAREHOUSE IF NOT EXISTS WH_AGENT
  WAREHOUSE_SIZE = SMALL  AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
  COMMENT = 'Cortex Agents execution';

CREATE WAREHOUSE IF NOT EXISTS WH_EVAL
  WAREHOUSE_SIZE = SMALL  AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
  COMMENT = 'Agent evaluation jobs';

CREATE WAREHOUSE IF NOT EXISTS WH_GOV
  WAREHOUSE_SIZE = XSMALL AUTO_SUSPEND = 60 AUTO_RESUME = TRUE
  COMMENT = 'Governance tasks (PII verify, sunset)';

-- ----------------------------------------------------------------------------
-- Functional roles
-- ----------------------------------------------------------------------------
-- ELT umbrella + per-domain
CREATE ROLE IF NOT EXISTS ELT_RL          COMMENT = 'ELT umbrella role';
CREATE ROLE IF NOT EXISTS ELT_MKT_RL      COMMENT = 'ELT Marketing';
CREATE ROLE IF NOT EXISTS ELT_SALES_RL    COMMENT = 'ELT Sales';
CREATE ROLE IF NOT EXISTS ELT_HR_RL       COMMENT = 'ELT HR';

-- Privileged + service roles
CREATE ROLE IF NOT EXISTS HR_PII_RL       COMMENT = 'Sees unmasked HR PII (humans only, agents always masked)';
CREATE ROLE IF NOT EXISTS DATA_LOAD_RL    COMMENT = 'Owns RAW.*; loads seeds; not granted to humans';
CREATE ROLE IF NOT EXISTS EVAL_SVC_RL     COMMENT = 'Service role for Cortex Agent evaluations';
CREATE ROLE IF NOT EXISTS CERTIFIER_RL    COMMENT = 'Sole role allowed to APPLY the CERTIFIED tag';

-- Hierarchy
GRANT ROLE ELT_MKT_RL   TO ROLE ELT_RL;
GRANT ROLE ELT_SALES_RL TO ROLE ELT_RL;
GRANT ROLE ELT_HR_RL    TO ROLE ELT_RL;
GRANT ROLE ELT_RL       TO ROLE SYSADMIN;
GRANT ROLE HR_PII_RL    TO ROLE SECURITYADMIN;
GRANT ROLE CERTIFIER_RL TO ROLE SYSADMIN;
GRANT ROLE EVAL_SVC_RL  TO ROLE SYSADMIN;
GRANT ROLE DATA_LOAD_RL TO ROLE SYSADMIN;

-- ----------------------------------------------------------------------------
-- Warehouse grants
-- ----------------------------------------------------------------------------
GRANT USAGE ON WAREHOUSE WH_AGENT TO ROLE ELT_RL;
GRANT USAGE ON WAREHOUSE WH_AGENT TO ROLE ELT_MKT_RL;
GRANT USAGE ON WAREHOUSE WH_AGENT TO ROLE ELT_SALES_RL;
GRANT USAGE ON WAREHOUSE WH_AGENT TO ROLE ELT_HR_RL;
GRANT USAGE ON WAREHOUSE WH_EVAL  TO ROLE EVAL_SVC_RL;
GRANT USAGE ON WAREHOUSE WH_GOV   TO ROLE CERTIFIER_RL;
GRANT USAGE ON WAREHOUSE WH_DT_S  TO ROLE DATA_LOAD_RL;
GRANT USAGE ON WAREHOUSE WH_DT_M  TO ROLE DATA_LOAD_RL;
