-- Frostbyte AI - Marts Dynamic Tables (dim_, fct_, agg_)
-- ============================================================================
-- TARGET_LAG = DOWNSTREAM so leaves drive refresh cadence.
-- ============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE WH_DT_M;
USE SCHEMA MARTS;

-- ============================================================================
-- Dimensions
-- ============================================================================

CREATE OR REPLACE TABLE dim_date AS
SELECT
  DATEADD(day, SEQ4(), DATE '2023-01-01') AS date_key,
  YEAR(DATEADD(day, SEQ4(), DATE '2023-01-01'))      AS year_num,
  QUARTER(DATEADD(day, SEQ4(), DATE '2023-01-01'))   AS quarter_num,
  MONTH(DATEADD(day, SEQ4(), DATE '2023-01-01'))     AS month_num,
  TO_CHAR(DATEADD(day, SEQ4(), DATE '2023-01-01'), 'YYYY-MM') AS year_month,
  WEEKOFYEAR(DATEADD(day, SEQ4(), DATE '2023-01-01'))AS week_num
FROM TABLE(GENERATOR(ROWCOUNT => 2000));

CREATE OR REPLACE DYNAMIC TABLE dim_region
  TARGET_LAG = DOWNSTREAM WAREHOUSE = WH_DT_M
AS SELECT DISTINCT region_code, region_name, rollup_region FROM FROSTBYTE_AI_DEV.RAW.REGIONS;

CREATE OR REPLACE DYNAMIC TABLE dim_product_line
  TARGET_LAG = DOWNSTREAM WAREHOUSE = WH_DT_M
AS SELECT DISTINCT product_line FROM FROSTBYTE_AI_DEV.RAW.PRODUCT_CATALOG;

CREATE OR REPLACE TABLE dim_channel AS
SELECT * FROM VALUES ('DTC'), ('Wholesale'), ('Frostbyte Pro') AS t(channel);

CREATE OR REPLACE DYNAMIC TABLE dim_account
  TARGET_LAG = DOWNSTREAM WAREHOUSE = WH_DT_M
AS
SELECT a.account_id, a.account_name, a.channel, a.region, a.segment, a.created_date
FROM STG.stg_sales_accounts a;

CREATE OR REPLACE DYNAMIC TABLE dim_employee
  TARGET_LAG = DOWNSTREAM WAREHOUSE = WH_DT_M
AS
SELECT
  e.employee_id, e.first_name, e.last_name, e.full_name,
  e.work_email, e.org_unit, e.manager_id, e.manager_chain,
  e.title, e.level, e.region, e.active_status,
  e.hire_date, e.termination_date, e.snapshot_date,
  e.base_salary
FROM STG.stg_hr_employees e;

-- ============================================================================
-- Facts / Aggregates
-- ============================================================================

CREATE OR REPLACE DYNAMIC TABLE fct_opps
  TARGET_LAG = '5 minutes' WAREHOUSE = WH_DT_M
AS
SELECT
  o.opp_id, o.account_id, o.product_line, o.channel, o.region,
  o.stage, o.arr_usd, o.is_pre_order, o.rep_employee_id,
  o.created_date, o.close_date
FROM STG.stg_sales_opps o;

CREATE OR REPLACE DYNAMIC TABLE agg_sales_pipeline_daily
  TARGET_LAG = '5 minutes' WAREHOUSE = WH_DT_M
AS
SELECT
  o.created_date  AS date_key,
  o.region,
  o.channel,
  o.product_line,
  o.stage,
  COUNT(*)                                AS opp_count,
  SUM(o.arr_usd)                          AS pipeline_arr_usd,
  SUM(IFF(o.is_pre_order, o.arr_usd, 0))  AS pre_order_arr_usd
FROM fct_opps o
GROUP BY 1, 2, 3, 4, 5;

CREATE OR REPLACE DYNAMIC TABLE agg_mkt_campaign
  TARGET_LAG = '5 minutes' WAREHOUSE = WH_DT_M
AS
SELECT
  c.campaign_id,
  c.campaign_name,
  c.product_line,
  c.region,
  c.channel,
  c.budget_usd,
  COUNT(l.lead_id)                                 AS lead_count,
  COUNT(l.converted_account_id)                    AS converted_count,
  IFF(COUNT(l.lead_id) > 0,
      COUNT(l.converted_account_id) * 1.0 / COUNT(l.lead_id),
      0)                                           AS conversion_rate
FROM STG.stg_mkt_campaigns c
LEFT JOIN STG.stg_mkt_leads l ON l.campaign_id = c.campaign_id
GROUP BY 1, 2, 3, 4, 5, 6;

CREATE OR REPLACE DYNAMIC TABLE agg_hr_headcount_snapshot
  TARGET_LAG = '1 hour' WAREHOUSE = WH_DT_M
  COMMENT = 'Latest-snapshot, ACTIVE_STATUS=1 headcount by org_unit/region/level'
AS
WITH latest AS (
  SELECT MAX(snapshot_date) AS d FROM dim_employee
)
SELECT
  e.snapshot_date AS date_key,
  e.region,
  e.org_unit,
  e.level,
  COUNT(*) AS headcount
FROM dim_employee e, latest
WHERE e.snapshot_date = latest.d
  AND e.active_status = 1
GROUP BY 1, 2, 3, 4;

CREATE OR REPLACE DYNAMIC TABLE agg_hr_attrition_monthly
  TARGET_LAG = '1 hour' WAREHOUSE = WH_DT_M
AS
SELECT
  DATE_TRUNC('month', t.termination_date) AS month_key,
  e.region,
  e.org_unit,
  COUNT(*) AS terminations
FROM STG.stg_hr_terminations t
JOIN dim_employee e ON e.employee_id = t.employee_id
GROUP BY 1, 2, 3;
