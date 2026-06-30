-- UC-1: Resolve the calling user to a dim_employee row for personalization.
-- Used by the summit_sync_briefing skill. Returns 0 or 1 row.
--
-- The session is running under the agent's owner role for tool execution,
-- but the original user is exposed via the SESSION namespace.

WITH me AS (
  SELECT TRIM(LOWER(email)) AS email
  FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
  WHERE name = SYS_CONTEXT('SNOWFLAKE$SESSION', 'CURRENT_USER')
  ORDER BY created_on DESC
  LIMIT 1
)
SELECT
  emp.first_name,
  emp.title,
  emp.region,
  CASE
    WHEN emp.level = 'C-LEVEL'              THEN 'TRUE'             -- C-level sees global
    WHEN emp.region IS NULL                 THEN 'TRUE'
    ELSE 'region = ''' || emp.region || ''''                          -- everyone else scoped
  END AS org_filter,
  emp.employee_id
FROM me
JOIN MARTS.dim_employee emp
  ON LOWER(emp.work_email) = me.email
WHERE emp.active_status = 1
ORDER BY emp.snapshot_date DESC
LIMIT 1;
