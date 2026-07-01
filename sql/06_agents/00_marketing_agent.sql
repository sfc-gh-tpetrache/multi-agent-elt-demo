-- Frostbyte AI - MARKETING sub-agent + MCP server
-- ============================================================================
-- Environment-aware: uses CURRENT_DATABASE() for FQN references.
-- Run with USE DATABASE FROSTBYTE_AI_DEV (or _PROD) before executing.
-- ============================================================================

USE ROLE SYSADMIN;
USE SCHEMA AGENTS;

EXECUTE IMMEDIATE $$
BEGIN
  LET db STRING := (SELECT CURRENT_DATABASE());

  EXECUTE IMMEDIATE '
    CREATE OR REPLACE AGENT MARKETING_AGENT
      PROFILE = ''{"display_name":"Frostbyte Marketing"}''
      COMMENT = ''Frostbyte marketing sub-agent: campaign ROI, MQL funnel, pipeline influence.''
      FROM SPECIFICATION $spec$
      {
        "models": { "orchestration": "claude-sonnet-4-6" },
        "instructions": {
          "orchestration": "You are Frostbyte''s Marketing assistant. Answer questions about campaign performance, MQL conversion, and pipeline influence using marketing-campaign-roi (semantic view sv_mkt_campaign_roi). Channels are DTC, Wholesale, Frostbyte Pro. Product lines are Cornice and Glacier. Regions are NA, EMEA, JP. Refuse questions outside marketing scope. Never fabricate numbers; cite the metric you used."
        },
        "tools": [
          { "tool_spec": {
              "type": "cortex_analyst_text_to_sql",
              "name": "marketing-campaign-roi",
              "description": "Frostbyte marketing campaign ROI, MQL funnel, conversion, cost per lead."
          } }
        ],
        "tool_resources": {
          "marketing-campaign-roi": {
            "execution_environment": { "type": "warehouse", "warehouse": "WH_AGENT" },
            "semantic_view": "' || :db || '.SEMANTIC.SV_MKT_CAMPAIGN_ROI"
          }
        }
      }
      $spec$';

  EXECUTE IMMEDIATE '
    CREATE OR REPLACE MCP SERVER MARKETING_AGENT_SERVER
      COMMENT = ''Exposes MARKETING_AGENT for external MCP clients.''
      FROM SPECIFICATION $spec$
      tools:
        - title: "Delegate to Marketing sub-agent"
          name: "delegate_to_marketing"
          type: "CORTEX_AGENT_RUN"
          identifier: "' || :db || '.AGENTS.MARKETING_AGENT"
          description: "Frostbyte Marketing sub-agent. Campaign ROI, MQL funnel, pipeline influence by channel / region / product line."
      $spec$';
END;
$$;

GRANT USAGE   ON AGENT MARKETING_AGENT TO ROLE ELT_MKT_RL;
GRANT USAGE   ON MCP SERVER MARKETING_AGENT_SERVER TO ROLE ELT_RL;
GRANT USAGE   ON MCP SERVER MARKETING_AGENT_SERVER TO ROLE ELT_MKT_RL;
GRANT MONITOR ON AGENT MARKETING_AGENT TO ROLE EVAL_SVC_RL;
