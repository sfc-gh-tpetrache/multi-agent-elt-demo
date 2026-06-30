-- Frostbyte AI - Staging Dynamic Tables
-- ============================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE WH_DT_S;
USE SCHEMA STG;

-- HR
CREATE OR REPLACE DYNAMIC TABLE stg_hr_employees
  TARGET_LAG = '5 minutes' WAREHOUSE = WH_DT_S
  COMMENT = 'Staged HR employees - 1:1 cleaning of RAW'
AS
SELECT
  employee_id, first_name, last_name, full_name,
  work_email, personal_email, phone, ssn, home_address,
  dob, hire_date, termination_date, active_status,
  TRIM(org_unit) AS org_unit,
  manager_id, manager_chain, title, level, region,
  base_salary, equity_grant, snapshot_date
FROM RAW.HR_EMPLOYEES;

CREATE OR REPLACE DYNAMIC TABLE stg_hr_terminations
  TARGET_LAG = '1 hour' WAREHOUSE = WH_DT_S
AS SELECT * FROM RAW.HR_TERMINATIONS;

-- HR policy docs -> AI_REDACT for Search service
CREATE OR REPLACE DYNAMIC TABLE stg_hr_policies_redacted
  TARGET_LAG = '1 hour' WAREHOUSE = WH_DT_S
  COMMENT = 'HR policy docs with PII redacted by SNOWFLAKE.CORTEX.AI_REDACT for Search ingestion'
AS
SELECT
  doc_id,
  title,
  category,
  SNOWFLAKE.CORTEX.AI_REDACT(content)::STRING AS content_redacted,
  last_updated
FROM RAW.HR_POLICY_DOCS;

-- Sales
CREATE OR REPLACE DYNAMIC TABLE stg_sales_accounts
  TARGET_LAG = '5 minutes' WAREHOUSE = WH_DT_S
AS SELECT * FROM RAW.SALES_ACCOUNTS;

CREATE OR REPLACE DYNAMIC TABLE stg_sales_contacts
  TARGET_LAG = '5 minutes' WAREHOUSE = WH_DT_S
AS SELECT * FROM RAW.SALES_CONTACTS;

CREATE OR REPLACE DYNAMIC TABLE stg_sales_opps
  TARGET_LAG = '5 minutes' WAREHOUSE = WH_DT_S
AS
SELECT
  opp_id, account_id, product_line, channel, region, stage, arr_usd,
  is_pre_order, rep_employee_id, created_date, close_date,
  SNOWFLAKE.CORTEX.AI_REDACT(opportunity_notes)::STRING AS opportunity_notes_redacted
FROM RAW.SALES_OPPS;

-- Marketing
CREATE OR REPLACE DYNAMIC TABLE stg_mkt_campaigns
  TARGET_LAG = '5 minutes' WAREHOUSE = WH_DT_S
AS SELECT * FROM RAW.MKT_CAMPAIGNS;

CREATE OR REPLACE DYNAMIC TABLE stg_mkt_leads
  TARGET_LAG = '5 minutes' WAREHOUSE = WH_DT_S
AS
SELECT
  lead_id, campaign_id, first_name, last_name, email, phone,
  company, country, region, mql_date, converted_account_id,
  SNOWFLAKE.CORTEX.AI_REDACT(lead_comments)::STRING AS lead_comments_redacted
FROM RAW.MKT_LEADS;
