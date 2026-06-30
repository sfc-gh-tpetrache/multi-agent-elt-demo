-- Frostbyte AI - Load synthetic CSVs from @ARTIFACTS.SEEDS into RAW
-- ============================================================================
-- Run as DATA_LOAD_RL after `snow stage put-file data/seeds/*.csv
-- @ARTIFACTS.SEEDS --auto-compress=false`.
-- ============================================================================

USE ROLE DATA_LOAD_RL;
USE WAREHOUSE WH_DT_S;
USE SCHEMA RAW;

CREATE OR REPLACE FILE FORMAT ARTIFACTS.CSV_FMT
  TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1
  NULL_IF = ('', 'NULL') EMPTY_FIELD_AS_NULL = TRUE;

COPY INTO RAW.REGIONS
  FROM @ARTIFACTS.SEEDS/regions.csv
  FILE_FORMAT = (FORMAT_NAME = ARTIFACTS.CSV_FMT)
  ON_ERROR = ABORT_STATEMENT;

COPY INTO RAW.PRODUCT_CATALOG
  FROM @ARTIFACTS.SEEDS/product_catalog.csv
  FILE_FORMAT = (FORMAT_NAME = ARTIFACTS.CSV_FMT)
  ON_ERROR = ABORT_STATEMENT;

COPY INTO RAW.HR_EMPLOYEES (
    employee_id, first_name, last_name, full_name, work_email, personal_email,
    phone, ssn, home_address, dob, hire_date, termination_date, active_status,
    org_unit, manager_id, manager_chain, title, level, region, base_salary,
    equity_grant, snapshot_date
  )
  FROM (
    SELECT
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
      $13::NUMBER, $14, $15, PARSE_JSON($16), $17, $18, $19,
      $20::NUMBER, $21::NUMBER, $22
    FROM @ARTIFACTS.SEEDS/hr_employees.csv (FILE_FORMAT => ARTIFACTS.CSV_FMT)
  )
  ON_ERROR = ABORT_STATEMENT;

COPY INTO RAW.HR_TERMINATIONS FROM @ARTIFACTS.SEEDS/hr_terminations.csv
  FILE_FORMAT = (FORMAT_NAME = ARTIFACTS.CSV_FMT) ON_ERROR = ABORT_STATEMENT;

COPY INTO RAW.HR_POLICY_DOCS FROM @ARTIFACTS.SEEDS/hr_policy_docs.csv
  FILE_FORMAT = (FORMAT_NAME = ARTIFACTS.CSV_FMT) ON_ERROR = ABORT_STATEMENT;

COPY INTO RAW.SALES_ACCOUNTS FROM @ARTIFACTS.SEEDS/sales_accounts.csv
  FILE_FORMAT = (FORMAT_NAME = ARTIFACTS.CSV_FMT) ON_ERROR = ABORT_STATEMENT;

COPY INTO RAW.SALES_CONTACTS FROM @ARTIFACTS.SEEDS/sales_contacts.csv
  FILE_FORMAT = (FORMAT_NAME = ARTIFACTS.CSV_FMT) ON_ERROR = ABORT_STATEMENT;

COPY INTO RAW.SALES_OPPS FROM @ARTIFACTS.SEEDS/sales_opps.csv
  FILE_FORMAT = (FORMAT_NAME = ARTIFACTS.CSV_FMT) ON_ERROR = ABORT_STATEMENT;

COPY INTO RAW.MKT_CAMPAIGNS FROM @ARTIFACTS.SEEDS/mkt_campaigns.csv
  FILE_FORMAT = (FORMAT_NAME = ARTIFACTS.CSV_FMT) ON_ERROR = ABORT_STATEMENT;

COPY INTO RAW.MKT_LEADS FROM @ARTIFACTS.SEEDS/mkt_leads.csv
  FILE_FORMAT = (FORMAT_NAME = ARTIFACTS.CSV_FMT) ON_ERROR = ABORT_STATEMENT;
