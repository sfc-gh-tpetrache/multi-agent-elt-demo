-- Frostbyte AI - Daily drift detection task per agent
-- ============================================================================

USE ROLE EVAL_SVC_RL;
USE SCHEMA EVAL;

CREATE OR REPLACE TASK T_DAILY_EVAL_MARKETING
  WAREHOUSE = WH_EVAL SCHEDULE = 'USING CRON 0 8 * * * America/Los_Angeles'
AS
  CALL RUN_EVAL('MARKETING_AGENT', 'production', 'ds_marketing_summit_sync_v1');

CREATE OR REPLACE TASK T_DAILY_EVAL_SALES
  WAREHOUSE = WH_EVAL SCHEDULE = 'USING CRON 5 8 * * * America/Los_Angeles'
AS
  CALL RUN_EVAL('SALES_AGENT', 'production', 'ds_sales_summit_sync_v1');

CREATE OR REPLACE TASK T_DAILY_EVAL_HR
  WAREHOUSE = WH_EVAL SCHEDULE = 'USING CRON 10 8 * * * America/Los_Angeles'
AS
  CALL RUN_EVAL('HR_AGENT', 'production', 'ds_hr_summit_sync_v1');

CREATE OR REPLACE TASK T_DAILY_EVAL_ROUTER
  WAREHOUSE = WH_EVAL SCHEDULE = 'USING CRON 15 8 * * * America/Los_Angeles'
AS
  CALL RUN_EVAL('ELT_ROUTER', 'production', 'ds_router_cross_domain_v1');

ALTER TASK T_DAILY_EVAL_MARKETING RESUME;
ALTER TASK T_DAILY_EVAL_SALES     RESUME;
ALTER TASK T_DAILY_EVAL_HR        RESUME;
ALTER TASK T_DAILY_EVAL_ROUTER    RESUME;

-- Accuracy alert
CREATE OR REPLACE NOTIFICATION INTEGRATION IF NOT EXISTS NI_FROSTBYTE_OPS_EMAIL
  TYPE = EMAIL ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('eltops@frostbyte.example');

CREATE OR REPLACE ALERT AL_EVAL_ACCURACY
  WAREHOUSE = WH_EVAL SCHEDULE = '60 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM EVAL_RUN_HISTORY
    WHERE metric_name = 'answer_correctness'
      AND eval_agg_score < 0.80
      AND run_at > DATEADD(hour, -1, CURRENT_TIMESTAMP())
  ))
  THEN
    CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(
      SNOWFLAKE.NOTIFICATION.TEXT_PLAIN('A Frostbyte agent eval dropped below 0.80 accuracy in the last hour.'),
      '{"NI_FROSTBYTE_OPS_EMAIL": {"toAddress":["eltops@frostbyte.example"]}}'
    );

ALTER ALERT AL_EVAL_ACCURACY RESUME;
