-- Frostbyte AI - RAW base tables (loaded from synthetic CSVs)
-- ============================================================================
-- USE DATABASE FROSTBYTE_AI_DEV; (then re-run with _PROD)
-- ============================================================================

USE ROLE DATA_LOAD_RL;
USE WAREHOUSE WH_DT_S;
USE SCHEMA RAW;

-- ----------------------------------------------------------------------------
-- Reference tables
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS REGIONS (
  region_code     STRING,
  region_name     STRING,
  rollup_region   STRING   -- NA / EMEA / JP
);

CREATE TABLE IF NOT EXISTS PRODUCT_CATALOG (
  sku             STRING,
  product_line    STRING,   -- Cornice / Glacier / Powder / Whiteout
  product_name    STRING,
  unit_price_usd  NUMBER(10,2)
);

-- ----------------------------------------------------------------------------
-- HR (PII-heavy)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS HR_EMPLOYEES (
  employee_id     STRING,
  first_name      STRING,
  last_name       STRING,
  full_name       STRING WITH TAG (GOVERNANCE.PII_CATEGORY = 'full_name'),
  work_email      STRING WITH TAG (GOVERNANCE.PII_CATEGORY = 'email'),
  personal_email  STRING WITH TAG (GOVERNANCE.PII_CATEGORY = 'email'),
  phone           STRING WITH TAG (GOVERNANCE.PII_CATEGORY = 'phone'),
  ssn             STRING WITH TAG (GOVERNANCE.PII_CATEGORY = 'ssn'),
  home_address    STRING WITH TAG (GOVERNANCE.PII_CATEGORY = 'address'),
  dob             DATE,
  hire_date       DATE,
  termination_date DATE,
  active_status   NUMBER(1),
  org_unit        STRING,         -- Marketing / Sales / Engineering / ...
  manager_id      STRING,
  manager_chain   ARRAY,
  title           STRING,
  level           STRING,         -- IC / Manager / Director / VP / C-LEVEL
  region          STRING,         -- NA / EMEA / JP
  base_salary     NUMBER(12,2) WITH TAG (GOVERNANCE.PII_CATEGORY = 'salary'),
  equity_grant    NUMBER(12,2) WITH TAG (GOVERNANCE.PII_CATEGORY = 'salary'),
  snapshot_date   DATE
);

CREATE TABLE IF NOT EXISTS HR_TERMINATIONS (
  employee_id     STRING,
  termination_date DATE,
  reason          STRING,
  exit_interview_notes STRING
);

CREATE TABLE IF NOT EXISTS HR_POLICY_DOCS (
  doc_id          STRING,
  title           STRING,
  category        STRING,         -- leave / comp / handbook / safety
  content         STRING,         -- contains PII; redacted in downstream DT
  last_updated    TIMESTAMP_NTZ
);

-- ----------------------------------------------------------------------------
-- Sales (DTC + Wholesale + Frostbyte Pro)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SALES_ACCOUNTS (
  account_id      STRING,
  account_name    STRING,
  channel         STRING,         -- DTC / Wholesale / Frostbyte Pro
  region          STRING,
  segment         STRING,         -- SMB / Mid-Market / Enterprise
  created_date    DATE
);

CREATE TABLE IF NOT EXISTS SALES_CONTACTS (
  contact_id      STRING,
  account_id      STRING,
  full_name       STRING WITH TAG (GOVERNANCE.PII_CATEGORY = 'full_name'),
  email           STRING WITH TAG (GOVERNANCE.PII_CATEGORY = 'email'),
  phone           STRING WITH TAG (GOVERNANCE.PII_CATEGORY = 'phone'),
  linkedin_url    STRING
);

CREATE TABLE IF NOT EXISTS SALES_OPPS (
  opp_id          STRING,
  account_id      STRING,
  product_line    STRING,
  channel         STRING,
  region          STRING,
  stage           STRING,
  arr_usd         NUMBER(14,2),
  is_pre_order    BOOLEAN,
  rep_employee_id STRING,
  created_date    DATE,
  close_date      DATE,
  opportunity_notes STRING        -- free-text, may contain PII -> AI_REDACT later
);

-- ----------------------------------------------------------------------------
-- Marketing
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS MKT_CAMPAIGNS (
  campaign_id     STRING,
  campaign_name   STRING,
  product_line    STRING,
  region          STRING,
  channel         STRING,
  start_date      DATE,
  end_date        DATE,
  budget_usd      NUMBER(14,2)
);

CREATE TABLE IF NOT EXISTS MKT_LEADS (
  lead_id         STRING,
  campaign_id     STRING,
  first_name      STRING,
  last_name       STRING,
  email           STRING WITH TAG (GOVERNANCE.PII_CATEGORY = 'email'),
  phone           STRING WITH TAG (GOVERNANCE.PII_CATEGORY = 'phone'),
  company         STRING,
  country         STRING,
  region          STRING,
  mql_date        DATE,
  converted_account_id STRING,
  lead_comments   STRING          -- free-text, may contain PII -> AI_REDACT later
);
