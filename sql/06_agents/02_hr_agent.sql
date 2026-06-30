-- Frostbyte AI - HR sub-agent (Analyst + Search) + MCP server
-- ============================================================================
-- NOTE: The MCP server is retained for external client access but the
-- ELT_ROUTER uses direct cortex_agent_run tools instead.
-- ============================================================================

USE ROLE SYSADMIN;
USE SCHEMA AGENTS;

CREATE OR REPLACE AGENT HR_AGENT
  PROFILE = '{"display_name":"Frostbyte HR"}'
  COMMENT = 'Frostbyte HR sub-agent: headcount, attrition, comp distribution, policy lookup.'
  FROM SPECIFICATION $$
  {
    "models": { "orchestration": "claude-sonnet-4-6" },
    "instructions": {
      "orchestration": "You are Frostbyte's HR assistant. Use hr-headcount-data (semantic view sv_hr_headcount) for structured questions about headcount, attrition, and aggregate comp distribution. Use hr-policy-search (Cortex Search css_hr_policies) for policy questions. Always apply latest snapshot and ACTIVE_STATUS=1 for headcount. Refuse questions about individual compensation. Never fabricate numbers; cite the metric or document you used."
    },
    "tools": [
      { "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "hr-headcount-data",
          "description": "Frostbyte HR headcount, attrition, aggregate comp distribution."
      } },
      { "tool_spec": {
          "type": "cortex_search",
          "name": "hr-policy-search",
          "description": "Search Frostbyte HR policies (handbook, leave, comp guidelines)."
      } }
    ],
    "tool_resources": {
      "hr-headcount-data": {
        "execution_environment": { "type": "warehouse", "warehouse": "WH_AGENT" },
        "semantic_view": "FROSTBYTE_AI_DEV.SEMANTIC.SV_HR_HEADCOUNT"
      },
      "hr-policy-search": {
        "search_service": "FROSTBYTE_AI_DEV.SEARCH.CSS_HR_POLICIES",
        "title_column":   "TITLE",
        "id_column":      "DOC_ID",
        "max_results":    5
      }
    }
  }
  $$;

CREATE OR REPLACE MCP SERVER HR_AGENT_SERVER
  COMMENT = 'Exposes HR_AGENT for external MCP clients.'
  FROM SPECIFICATION $$
  tools:
    - title: "Delegate to HR sub-agent"
      name: "delegate_to_hr"
      type: "CORTEX_AGENT_RUN"
      identifier: "FROSTBYTE_AI_DEV.AGENTS.HR_AGENT"
      description: "Frostbyte HR sub-agent. Headcount vs plan, attrition, comp distribution, HR policy lookup."
  $$;

GRANT USAGE   ON AGENT HR_AGENT TO ROLE ELT_HR_RL;
GRANT USAGE   ON MCP SERVER HR_AGENT_SERVER TO ROLE ELT_RL;
GRANT MONITOR ON AGENT HR_AGENT TO ROLE EVAL_SVC_RL;
