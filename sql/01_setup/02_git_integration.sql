-- Frostbyte AI - Git integration + stages (run per-env)
-- ============================================================================
-- USE DATABASE <FROSTBYTE_AI_DEV | FROSTBYTE_AI_PROD>;
-- Replace ORIGIN with your actual repo URL before running.
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ----------------------------------------------------------------------------
-- Git API integration (shared across envs; create once)
-- ----------------------------------------------------------------------------
CREATE API INTEGRATION IF NOT EXISTS GIT_API_INT
  API_PROVIDER     = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED          = TRUE
  COMMENT          = 'Frostbyte demo Git integration';

GRANT USAGE ON INTEGRATION GIT_API_INT TO ROLE SYSADMIN;

-- ----------------------------------------------------------------------------
-- Git repository in the current database
-- ----------------------------------------------------------------------------
CREATE OR REPLACE GIT REPOSITORY ARTIFACTS.GIT_REPO
  API_INTEGRATION = GIT_API_INT
  ORIGIN          = 'https://github.com/REPLACE_ME/frostbyte-ai-demo'
  COMMENT         = 'Source of truth for agent specs, skills, eval datasets, SQL';

ALTER GIT REPOSITORY ARTIFACTS.GIT_REPO FETCH;

-- ----------------------------------------------------------------------------
-- Seed stage for synthetic CSVs
-- ----------------------------------------------------------------------------
CREATE STAGE IF NOT EXISTS ARTIFACTS.SEEDS
  DIRECTORY = (ENABLE = TRUE)
  FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1 NULL_IF = ('', 'NULL'))
  COMMENT = 'Synthetic Frostbyte seed CSVs';

GRANT READ ON STAGE ARTIFACTS.SEEDS TO ROLE DATA_LOAD_RL;
GRANT WRITE ON STAGE ARTIFACTS.SEEDS TO ROLE DATA_LOAD_RL;
GRANT READ ON STAGE ARTIFACTS.GIT_REPO TO ROLE SYSADMIN;
GRANT READ ON STAGE ARTIFACTS.GIT_REPO TO ROLE EVAL_SVC_RL;
GRANT READ ON STAGE ARTIFACTS.GIT_REPO TO ROLE ELT_RL;
