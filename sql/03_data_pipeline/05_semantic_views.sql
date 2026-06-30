-- Frostbyte AI - Semantic Views (one per domain)
-- ============================================================================
-- These are the contract surface for Cortex Analyst inside each sub-agent.
-- Default-filter business rules (latest snapshot, ACTIVE_STATUS=1, channel-aware
-- ARR) are encoded here so the agent cannot bypass them via prompt.
-- ============================================================================

USE ROLE SYSADMIN;
USE SCHEMA SEMANTIC;

-- ============================================================================
-- sv_mkt_campaign_roi
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW sv_mkt_campaign_roi
  TABLES (
    campaigns AS MARTS.agg_mkt_campaign
      PRIMARY KEY (campaign_id),
    dates AS MARTS.dim_date PRIMARY KEY (date_key)
  )
  DIMENSIONS (
    campaigns.campaign_id       AS campaign_id,
    campaigns.campaign_name     AS campaign_name,
    campaigns.product_line      AS product_line
      WITH SYNONYMS = ('product family', 'line') COMMENT = 'Cornice / Glacier / Powder / Whiteout',
    campaigns.region            AS region
      WITH SYNONYMS = ('geo', 'rollup region') COMMENT = 'NA / EMEA / JP',
    campaigns.channel           AS channel
      WITH SYNONYMS = ('go-to-market channel') COMMENT = 'DTC / Wholesale / Frostbyte Pro'
  )
  METRICS (
    campaigns.lead_count        AS SUM(campaigns.lead_count),
    campaigns.converted_count   AS SUM(campaigns.converted_count),
    campaigns.budget_usd        AS SUM(campaigns.budget_usd),
    campaigns.conversion_rate   AS AVG(campaigns.conversion_rate)
      COMMENT = 'Lead-to-account conversion rate. Average across campaigns.',
    cost_per_lead AS DIV0(campaigns.budget_usd, campaigns.lead_count)
      COMMENT = 'Marketing cost per MQL (derived).'
  )
  COMMENT = 'Frostbyte marketing campaign performance';

-- ============================================================================
-- sv_sales_pipeline
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW sv_sales_pipeline
  TABLES (
    pipeline AS MARTS.agg_sales_pipeline_daily,
    accounts AS MARTS.dim_account PRIMARY KEY (account_id),
    dates    AS MARTS.dim_date    PRIMARY KEY (date_key)
  )
  RELATIONSHIPS (
    pipeline_to_dates AS pipeline (date_key) REFERENCES dates (date_key)
  )
  DIMENSIONS (
    pipeline.region        AS region,
    pipeline.channel       AS channel
      COMMENT = 'DTC = direct-to-consumer; Wholesale = retailers; Frostbyte Pro = B2B subscription (recurring ARR)',
    pipeline.product_line  AS product_line,
    pipeline.stage         AS stage,
    dates.year_month       AS year_month,
    dates.quarter_num      AS quarter_num
  )
  METRICS (
    pipeline.opp_count          AS SUM(pipeline.opp_count),
    pipeline.pipeline_arr_usd   AS SUM(pipeline.pipeline_arr_usd)
      COMMENT = 'Pipeline ARR. For Frostbyte Pro this is recurring; for DTC/Wholesale this is one-time.',
    pipeline.pre_order_arr_usd  AS SUM(pipeline.pre_order_arr_usd)
      COMMENT = 'Pre-order pipeline (Cornice/Glacier season launches).'
  )
  COMMENT = 'Frostbyte sales pipeline by channel, region, product line';

-- ============================================================================
-- sv_hr_headcount
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW sv_hr_headcount
  TABLES (
    hc        AS MARTS.agg_hr_headcount_snapshot,
    attrition AS MARTS.agg_hr_attrition_monthly,
    employees AS MARTS.dim_employee PRIMARY KEY (employee_id)
  )
  DIMENSIONS (
    hc.region              AS region,
    hc.org_unit            AS org_unit
      COMMENT = 'Marketing / Sales / Engineering / Operations / ...',
    hc.level               AS level
      COMMENT = 'IC / Manager / Director / VP / C-LEVEL',
    hc.date_key            AS hc.date_key
      COMMENT = 'Headcount snapshot date',
    attrition.month_key    AS attrition.month_key
      COMMENT = 'Attrition month'
  )
  METRICS (
    hc.headcount           AS SUM(hc.headcount)
      COMMENT = 'Latest-snapshot, ACTIVE_STATUS=1 headcount.',
    attrition.terminations AS SUM(attrition.terminations)
      COMMENT = 'Terminations per month.'
  )
  COMMENT = 'Frostbyte HR headcount + attrition (aggregates only; individual rows masked by Tier C RAP)';
