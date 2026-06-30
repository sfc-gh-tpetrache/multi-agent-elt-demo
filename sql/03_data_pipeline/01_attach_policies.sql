-- Frostbyte AI - Attach masking + row-access policies to RAW columns
-- Run AFTER 00_raw_tables.sql and AFTER governance policies are created.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA RAW;

-- HR employees
ALTER TABLE HR_EMPLOYEES MODIFY COLUMN work_email     SET MASKING POLICY GOVERNANCE.mp_mask_email     USING (work_email);
ALTER TABLE HR_EMPLOYEES MODIFY COLUMN personal_email SET MASKING POLICY GOVERNANCE.mp_mask_email     USING (personal_email);
ALTER TABLE HR_EMPLOYEES MODIFY COLUMN phone          SET MASKING POLICY GOVERNANCE.mp_mask_phone     USING (phone);
ALTER TABLE HR_EMPLOYEES MODIFY COLUMN ssn            SET MASKING POLICY GOVERNANCE.mp_mask_ssn       USING (ssn);
ALTER TABLE HR_EMPLOYEES MODIFY COLUMN home_address   SET MASKING POLICY GOVERNANCE.mp_mask_address   USING (home_address);
ALTER TABLE HR_EMPLOYEES MODIFY COLUMN base_salary    SET MASKING POLICY GOVERNANCE.mp_mask_salary    USING (base_salary);
ALTER TABLE HR_EMPLOYEES MODIFY COLUMN equity_grant   SET MASKING POLICY GOVERNANCE.mp_mask_salary    USING (equity_grant);
ALTER TABLE HR_EMPLOYEES MODIFY COLUMN full_name      SET MASKING POLICY GOVERNANCE.mp_mask_full_name USING (full_name);

-- Row access on HR
ALTER TABLE HR_EMPLOYEES ADD ROW ACCESS POLICY GOVERNANCE.rap_hr_employee_scope ON (manager_chain);

-- Sales contacts
ALTER TABLE SALES_CONTACTS MODIFY COLUMN email     SET MASKING POLICY GOVERNANCE.mp_mask_email     USING (email);
ALTER TABLE SALES_CONTACTS MODIFY COLUMN phone     SET MASKING POLICY GOVERNANCE.mp_mask_phone     USING (phone);
ALTER TABLE SALES_CONTACTS MODIFY COLUMN full_name SET MASKING POLICY GOVERNANCE.mp_mask_full_name USING (full_name);

-- Marketing leads
ALTER TABLE MKT_LEADS MODIFY COLUMN email SET MASKING POLICY GOVERNANCE.mp_mask_email USING (email);
ALTER TABLE MKT_LEADS MODIFY COLUMN phone SET MASKING POLICY GOVERNANCE.mp_mask_phone USING (phone);
