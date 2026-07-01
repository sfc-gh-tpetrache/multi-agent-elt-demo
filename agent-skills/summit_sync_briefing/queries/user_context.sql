-- UC-1: Resolve the caller's scope via CURRENT_ROLE().
-- Used by the summit_sync_briefing skill. Always returns exactly 1 row.
--
-- Maps the active role to a domain that determines which sub-agents
-- the skill delegates to. This mirrors the RBAC grants on MCP servers:
--   ELT_RL        -> global  (all 3 MCP servers granted)
--   ELT_SALES_RL  -> sales   (only SALES_AGENT_SERVER granted)
--   ELT_MKT_RL    -> marketing (only MARKETING_AGENT_SERVER granted)
--   ELT_HR_RL     -> hr      (only HR_AGENT_SERVER granted)
--   Other         -> unauthorized (refuse briefing)

SELECT
  CURRENT_USER()  AS user_name,
  CURRENT_ROLE()  AS role_name,
  CASE
    WHEN CURRENT_ROLE() = 'ELT_RL'       THEN 'global'
    WHEN CURRENT_ROLE() = 'ELT_SALES_RL' THEN 'sales'
    WHEN CURRENT_ROLE() = 'ELT_MKT_RL'   THEN 'marketing'
    WHEN CURRENT_ROLE() = 'ELT_HR_RL'    THEN 'hr'
    ELSE 'unauthorized'
  END AS domain
;
