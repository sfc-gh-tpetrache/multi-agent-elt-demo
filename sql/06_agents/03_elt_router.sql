-- Frostbyte AI - ROUTER agent (MCP connectors + stage-sourced skill)
-- ============================================================================
-- The router delegates to sub-agents via MCP servers. Each MCP server wraps
-- a sub-agent as a CORTEX_AGENT_RUN tool, providing:
--   1. External access: MCP servers are callable by external clients (Cursor,
--      Claude Desktop) via OAuth REST endpoint.
--   2. Decoupling: MCP server can be shared across multiple consumers.
--   3. Eval support: confirmed working with MCP connectors in this account.
-- ============================================================================

USE ROLE SYSADMIN;
USE SCHEMA AGENTS;

CREATE OR REPLACE AGENT ELT_ROUTER
  PROFILE = '{"display_name":"Frostbyte ELT Router"}'
  COMMENT = 'Frostbyte ELT router. Orchestrates Marketing/Sales/HR sub-agents via MCP servers.'
  FROM SPECIFICATION $$
  {
    "models": { "orchestration": "claude-sonnet-4-6" },
    "instructions": {
      "orchestration": "You orchestrate Frostbyte ELT questions. For triggers 'good morning', 'summit sync', 'monday brief', or 'catch me up', follow the summit_sync_briefing skill exactly. Otherwise route ad-hoc questions: delegate_to_marketing for campaigns / MQL / influence, delegate_to_sales for pipeline / ARR / pre-orders, delegate_to_hr for headcount / attrition / HR policy. For cross-domain questions, fan out in parallel and synthesize one answer with citations per sub-agent. Never fabricate numbers. If a sub-agent reports 'this metric is not currently certified', say so and do not improvise."
    },
    "tools": [],
    "mcp_servers": [
      { "server_spec": { "name": "FROSTBYTE_AI_DEV.AGENTS.MARKETING_AGENT_SERVER" } },
      { "server_spec": { "name": "FROSTBYTE_AI_DEV.AGENTS.SALES_AGENT_SERVER"     } },
      { "server_spec": { "name": "FROSTBYTE_AI_DEV.AGENTS.HR_AGENT_SERVER"        } }
    ],
    "skills": [
      {
        "name": "summit_sync_briefing",
        "source": {
          "type": "STAGE",
          "path": "@FROSTBYTE_AI_DEV.ARTIFACTS.AGENT_SKILLS/summit_sync_briefing"
        }
      }
    ]
  }
  $$;

GRANT USAGE   ON AGENT ELT_ROUTER TO ROLE ELT_RL;
GRANT MONITOR ON AGENT ELT_ROUTER TO ROLE EVAL_SVC_RL;
