-- Frostbyte AI - Register eval datasets + RUN_EVAL procedure
-- ============================================================================
-- Eval datasets live in Git; CI uploads them to @EVAL.CFG_STAGE and
-- calls CREATE DATASET. The RUN_EVAL procedure wraps EXECUTE_AI_EVALUATION
-- so other tasks/scripts can invoke evals with a single CALL.
-- ============================================================================

USE ROLE EVAL_SVC_RL;
USE WAREHOUSE WH_EVAL;
USE SCHEMA EVAL;

-- ----------------------------------------------------------------------------
-- Eval config stage (CI uploads YAML configs here)
-- ----------------------------------------------------------------------------
CREATE STAGE IF NOT EXISTS CFG_STAGE
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Eval YAML configs uploaded from Git by CI';

GRANT READ, WRITE ON STAGE CFG_STAGE TO ROLE EVAL_SVC_RL;

-- ----------------------------------------------------------------------------
-- Run history table for trend analysis + alerting
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS EVAL_RUN_HISTORY (
  run_name        STRING,
  agent_name      STRING,
  agent_version   STRING,
  dataset_name    STRING,
  metric_name     STRING,
  eval_agg_score  FLOAT,
  passed          BOOLEAN,
  threshold       FLOAT,
  run_at          TIMESTAMP_LTZ,
  raw_payload     VARIANT
);

-- ----------------------------------------------------------------------------
-- RUN_EVAL: kicks off an evaluation and snapshots the result.
-- agent_version may be VERSION$N, an alias (dev/staging/production),
-- or a shortcut (LIVE/FIRST/LAST/DEFAULT).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE RUN_EVAL(
  AGENT_NAME     STRING,
  AGENT_VERSION  STRING,
  DATASET_NAME   STRING,
  CONFIG_PATH    STRING DEFAULT '@CFG_STAGE/'
)
RETURNS OBJECT
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  run_name STRING DEFAULT 'run_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS');
  result VARIANT;
BEGIN
  -- Kick off evaluation (Snowflake handles the heavy lifting)
  CALL SNOWFLAKE.CORTEX.EXECUTE_AI_EVALUATION(
    AGENT       => :AGENT_NAME || ':' || :AGENT_VERSION,
    DATASET     => :DATASET_NAME,
    RUN_NAME    => :run_name,
    CONFIG_PATH => :CONFIG_PATH
  );

  -- Snapshot per-metric scores into EVAL_RUN_HISTORY
  INSERT INTO EVAL_RUN_HISTORY
    (run_name, agent_name, agent_version, dataset_name, metric_name,
     eval_agg_score, passed, threshold, run_at, raw_payload)
  SELECT
    :run_name, :AGENT_NAME, :AGENT_VERSION, :DATASET_NAME,
    METRIC_NAME, EVAL_AGG_SCORE,
    EVAL_AGG_SCORE >= CASE METRIC_NAME
                        WHEN 'answer_correctness'  THEN 0.75
                        WHEN 'logical_consistency' THEN 0.80
                        WHEN 'pii_safety'          THEN 0.99
                        ELSE 0.0
                      END,
    CASE METRIC_NAME
      WHEN 'answer_correctness'  THEN 0.75
      WHEN 'logical_consistency' THEN 0.80
      WHEN 'pii_safety'          THEN 0.99
      ELSE 0.0
    END,
    CURRENT_TIMESTAMP(),
    OBJECT_CONSTRUCT(*)
  FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
              CURRENT_DATABASE(), 'AGENTS', :AGENT_NAME, 'CORTEX AGENT', :run_name));

  SELECT OBJECT_AGG(metric_name, eval_agg_score) INTO :result
  FROM EVAL_RUN_HISTORY WHERE run_name = :run_name;

  RETURN OBJECT_CONSTRUCT('run_name', :run_name, 'metrics', :result);
END;
$$;

GRANT USAGE ON PROCEDURE RUN_EVAL(STRING, STRING, STRING, STRING) TO ROLE EVAL_SVC_RL;
