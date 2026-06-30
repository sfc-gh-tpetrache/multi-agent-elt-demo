-- Frostbyte AI - SALES sub-agent + MCP server
-- ============================================================================
-- NOTE: The MCP server is retained for external client access but the
-- ELT_ROUTER uses direct cortex_agent_run tools instead.
-- ============================================================================

USE ROLE SYSADMIN;
USE SCHEMA AGENTS;

CREATE OR REPLACE AGENT SALES_AGENT
  PROFILE = '{"display_name":"Frostbyte Sales"}'
  COMMENT = 'Frostbyte sales sub-agent: pipeline, ARR, pre-orders by channel/region.'
  FROM SPECIFICATION $$
  {
    "models": { "orchestration": "claude-sonnet-4-6" },
    "instructions": {
      "orchestration": "You are Frostbyte's Sales assistant. Answer questions about pipeline coverage, ARR, and pre-orders using sales-pipeline-data (semantic view sv_sales_pipeline). Channels are DTC, Wholesale, Frostbyte Pro - Frostbyte Pro ARR is recurring, the others are one-time. Regions are NA, EMEA, JP. Product lines are Cornice and Glacier. Refuse questions outside sales scope. Never fabricate numbers; cite the metric you used."
    },
    "tools": [
      { "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "sales-pipeline-data",
          "description": "Frostbyte sales pipeline, ARR by channel/segment/region, pre-order pipeline."
      } }
    ],
    "tool_resources": {
      "sales-pipeline-data": {
        "execution_environment": { "type": "warehouse", "warehouse": "WH_AGENT" },
        "semantic_view": "FROSTBYTE_AI_DEV.SEMANTIC.SV_SALES_PIPELINE"
      }
    }
  }
  $$;

CREATE OR REPLACE MCP SERVER SALES_AGENT_SERVER
  COMMENT = 'Exposes SALES_AGENT for external MCP clients.'
  FROM SPECIFICATION $$
  tools:
    - title: "Delegate to Sales sub-agent"
      name: "delegate_to_sales"
      type: "CORTEX_AGENT_RUN"
      identifier: "FROSTBYTE_AI_DEV.AGENTS.SALES_AGENT"
      description: "Frostbyte Sales sub-agent. Pipeline coverage, ARR by segment, pre-orders, top accounts by channel."
  $$;

GRANT USAGE   ON AGENT SALES_AGENT TO ROLE ELT_SALES_RL;
GRANT USAGE   ON MCP SERVER SALES_AGENT_SERVER TO ROLE ELT_RL;
GRANT MONITOR ON AGENT SALES_AGENT TO ROLE EVAL_SVC_RL;
