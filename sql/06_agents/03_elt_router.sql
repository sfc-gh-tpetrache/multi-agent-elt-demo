-- Frostbyte AI - ROUTER agent (MCP connectors + Git-sourced skill)
-- ============================================================================
-- Canonical agent spec — always reflects the latest evaluated version.
-- Running this script against any environment creates the agent with VERSION$1
-- containing the best-known configuration. After creation, set the alias:
--   ALTER AGENT AGENTS.ELT_ROUTER MODIFY VERSION VERSION$1 SET ALIAS = production;
--
-- For subsequent updates, use the promotion flow:
--   1. Iterate on LIVE version in DEV
--   2. COMMIT -> eval -> gate check
--   3. Tag Git + deploy_candidate.py to PROD
--   See 04_router_version_changelog.sql for DEV iteration history.
--
-- The router delegates to sub-agents via MCP servers. Each MCP server wraps
-- a sub-agent as a CORTEX_AGENT_RUN tool, providing:
--   1. External access: MCP servers are callable by external clients (Cursor,
--      Claude Desktop) via OAuth REST endpoint.
--   2. Decoupling: MCP server can be shared across multiple consumers.
--   3. Eval support: confirmed working with MCP connectors in this account.
-- ============================================================================

USE ROLE SYSADMIN;
USE SCHEMA AGENTS;

SET DB = CURRENT_DATABASE();

EXECUTE IMMEDIATE $$
BEGIN
  LET db STRING := (SELECT CURRENT_DATABASE());

  EXECUTE IMMEDIATE '
    CREATE OR REPLACE AGENT ELT_ROUTER
      PROFILE = ''{"display_name":"Frostbyte ELT Router"}''
      COMMENT = ''Frostbyte ELT router. Orchestrates Marketing/Sales/HR sub-agents via MCP servers.''
      FROM SPECIFICATION $spec$
      {
        "models": { "orchestration": "claude-sonnet-4-6" },
        "instructions": {
          "orchestration": "You orchestrate Frostbyte ELT questions. For triggers ''good morning'', ''summit sync'', ''monday brief'', or ''catch me up'', follow the summit_sync_briefing skill exactly. Otherwise route ad-hoc questions: delegate_to_marketing for campaigns / MQL / influence, delegate_to_sales for pipeline / ARR / pre-orders, delegate_to_hr for headcount / attrition / HR policy. For cross-domain questions, fan out in parallel and synthesize using these rules: (1) Present each sub-agent''s response in a clearly labeled section (e.g., ''Marketing:'', ''Sales:'', ''HR:''). (2) Do not blend figures from different domains into a single sentence — keep each domain''s numbers in its own section. (3) Add a one-line cross-domain insight only if the user explicitly asked for a combined analysis. (4) If sub-agents report data for different time periods, note the discrepancy. Never fabricate numbers. If a sub-agent reports ''this metric is not currently certified'', say so and do not improvise."
        },
        "tools": [],
        "mcp_servers": [
          { "server_spec": { "name": "' || :db || '.AGENTS.MARKETING_AGENT_SERVER" } },
          { "server_spec": { "name": "' || :db || '.AGENTS.SALES_AGENT_SERVER"     } },
          { "server_spec": { "name": "' || :db || '.AGENTS.HR_AGENT_SERVER"        } }
        ],
        "skills": [
          {
            "name": "summit_sync_briefing",
            "source": {
              "type": "GIT_INTEGRATION",
              "path": "@' || :db || '.ARTIFACTS.GIT_REPO/branches/main/agent-skills/summit_sync_briefing"
            }
          }
        ]
      }
      $spec$';
END;
$$;

GRANT USAGE   ON AGENT ELT_ROUTER TO ROLE ELT_RL;
GRANT MONITOR ON AGENT ELT_ROUTER TO ROLE EVAL_SVC_RL;

GRANT USAGE ON AGENT ELT_ROUTER TO ROLE ELT_SALES_RL;
GRANT USAGE ON AGENT ELT_ROUTER TO ROLE ELT_MKT_RL;
GRANT USAGE ON AGENT ELT_ROUTER TO ROLE ELT_HR_RL;
