-- Frostbyte AI - PII audit event table (Tier D)
-- ============================================================================
-- Captures every agent-context PII access for compliance.
-- The masking policies emit SYSTEM$LOG_INFO events that land here.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE SCHEMA GOVERNANCE;

CREATE EVENT TABLE IF NOT EXISTS PII_AUDIT_EVENTS
  COMMENT = 'Agent-context PII access audit (populated by SYSTEM$LOG_INFO in masking policies)';

-- Wire the database to use this event table for telemetry
ALTER DATABASE IDENTIFIER(CURRENT_DATABASE())
  SET EVENT_TABLE = GOVERNANCE.PII_AUDIT_EVENTS;

-- A friendly view over the event table
CREATE OR REPLACE VIEW V_PII_AUDIT AS
SELECT
  TIMESTAMP::TIMESTAMP_LTZ                       AS event_time,
  RECORD:agent_type::STRING                      AS agent_type,
  RECORD:agent_db::STRING                        AS agent_db,
  RECORD:agent_schema::STRING                    AS agent_schema,
  RECORD:agent_name::STRING                      AS agent_name,
  RECORD:pii_category::STRING                    AS pii_category,
  RECORD:session_user::STRING                    AS session_user,
  RECORD:session_role::STRING                    AS session_role,
  RECORD:query_id::STRING                        AS query_id
FROM PII_AUDIT_EVENTS
WHERE RECORD:event::STRING = 'pii_access_via_agent';

GRANT SELECT ON VIEW V_PII_AUDIT TO ROLE HR_PII_RL;
GRANT SELECT ON VIEW V_PII_AUDIT TO ROLE SECURITYADMIN;
