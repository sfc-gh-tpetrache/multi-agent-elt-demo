-- Frostbyte AI - HR sub-agent (Analyst + Search) + MCP server
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
    CREATE OR REPLACE AGENT HR_AGENT
      PROFILE = ''{"display_name":"Frostbyte HR"}''
      COMMENT = ''Frostbyte HR sub-agent: headcount, attrition, comp distribution, policy lookup.''
      FROM SPECIFICATION $spec$
      {
        "models": { "orchestration": "claude-sonnet-4-6" },
        "instructions": {
          "orchestration": "You are Frostbyte''s HR assistant. Use hr-headcount-data (semantic view sv_hr_headcount) for structured questions about headcount, attrition, and aggregate comp distribution. Use hr-policy-search (Cortex Search css_hr_policies) for policy questions. Always apply latest snapshot and ACTIVE_STATUS=1 for headcount. Refuse questions about individual compensation. Never fabricate numbers; cite the metric or document you used. When search results contain redacted placeholders such as [NAME], [EMAIL], or similar bracketed tokens, present them exactly as they appear in the source and explain that the information has been redacted for privacy. Do not treat redacted fields as missing data or refuse to answer.",
          "response": "Always cite the source document title (e.g., [DOC-001: Parental Leave Policy]) when referencing policy information. Include relevant verbatim quotes from the source. When policy documents contain redacted fields shown as [NAME], [EMAIL], or [PHONE_NUMBER], include them exactly as they appear and add: ''Contact details have been redacted for privacy. Please reach out to your HR Business Partner directly for this information.''"
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
            "semantic_view": "' || :db || '.SEMANTIC.SV_HR_HEADCOUNT"
          },
          "hr-policy-search": {
            "search_service": "' || :db || '.SEARCH.CSS_HR_POLICIES",
            "title_column":   "TITLE",
            "id_column":      "DOC_ID",
            "max_results":    5
          }
        }
      }
      $spec$';

  EXECUTE IMMEDIATE '
    CREATE OR REPLACE MCP SERVER HR_AGENT_SERVER
      COMMENT = ''Exposes HR_AGENT for external MCP clients.''
      FROM SPECIFICATION $spec$
      tools:
        - title: "Delegate to HR sub-agent"
          name: "delegate_to_hr"
          type: "CORTEX_AGENT_RUN"
          identifier: "' || :db || '.AGENTS.HR_AGENT"
          description: "Frostbyte HR sub-agent. Headcount, attrition, comp distribution, HR policy lookup."
      $spec$';
END;
$$;

GRANT USAGE   ON AGENT HR_AGENT TO ROLE ELT_HR_RL;
GRANT USAGE   ON MCP SERVER HR_AGENT_SERVER TO ROLE ELT_RL;
GRANT USAGE   ON MCP SERVER HR_AGENT_SERVER TO ROLE ELT_HR_RL;
GRANT MONITOR ON AGENT HR_AGENT TO ROLE EVAL_SVC_RL;
