-- Frostbyte AI - ELT Router: add a new version
-- ============================================================================
-- ONE-TIME CHANGELOG SCRIPT (not idempotent — each run creates a new VERSION$N)
--
-- Actual version history in DEV:
--   VERSION$1 — Initial router (auto-committed by CREATE AGENT)
--   VERSION$2 — Committed dangling LIVE to clear state (identical to V1)
--   VERSION$3 — Improved orchestration: structured cross-domain synthesis rules
--
-- General pattern for adding a new version:
--   1. ADD LIVE VERSION FROM LAST (or FROM a specific VERSION$N)
--   2. MODIFY LIVE VERSION SET SPECIFICATION = $$...$$
--   3. COMMIT -> creates next VERSION$N
--   4. Run eval targeting the new default version
--   5. If eval passes: SET ALIAS = production / SET DEFAULT_VERSION
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE FROSTBYTE_AI_DEV;
USE SCHEMA AGENTS;

-- Step 1: Create a mutable LIVE version from the latest committed version
-- NOTE: If a LIVE version already exists, commit it first with:
--   ALTER AGENT ELT_ROUTER COMMIT COMMENT = 'committing existing LIVE';
ALTER AGENT ELT_ROUTER ADD LIVE VERSION FROM LAST;

-- Step 2: Update the LIVE version with new spec
ALTER AGENT ELT_ROUTER MODIFY LIVE VERSION SET SPECIFICATION = $$
{
  "models": { "orchestration": "claude-sonnet-4-6" },
  "instructions": {
    "orchestration": "You orchestrate Frostbyte ELT questions. For triggers 'good morning', 'summit sync', 'monday brief', or 'catch me up', follow the summit_sync_briefing skill exactly. Otherwise route ad-hoc questions: delegate_to_marketing for campaigns / MQL / influence, delegate_to_sales for pipeline / ARR / pre-orders, delegate_to_hr for headcount / attrition / HR policy. For cross-domain questions, fan out in parallel and synthesize using these rules: (1) Present each sub-agent's response in a clearly labeled section (e.g., 'Marketing:', 'Sales:', 'HR:'). (2) Do not blend figures from different domains into a single sentence — keep each domain's numbers in its own section. (3) Add a one-line cross-domain insight only if the user explicitly asked for a combined analysis. (4) If sub-agents report data for different time periods, note the discrepancy. Never fabricate numbers. If a sub-agent reports 'this metric is not currently certified', say so and do not improvise."
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
        "type": "GIT_INTEGRATION",
        "path": "@FROSTBYTE_AI_DEV.ARTIFACTS.GIT_REPO/branches/main/agent-skills/summit_sync_briefing"
      }
    }
  ]
}
$$;

-- Step 3: Commit -> creates next VERSION$N
ALTER AGENT ELT_ROUTER COMMIT
  COMMENT = 'v3: structured cross-domain synthesis rules to improve logical consistency';

-- Step 4: Set as default and run eval (run from USE SCHEMA AGENTS)
ALTER AGENT ELT_ROUTER SET DEFAULT_VERSION = LAST;

CALL EXECUTE_AI_EVALUATION('START',
  OBJECT_CONSTRUCT('run_name', 'router-v3-eval'),
  '@FROSTBYTE_AI_DEV.EVAL.CFG_STAGE/router_eval_config.yaml');

-- Check status (poll until COMPLETED)
-- CALL EXECUTE_AI_EVALUATION('STATUS',
--   OBJECT_CONSTRUCT('run_name', 'router-v3-eval'),
--   '@FROSTBYTE_AI_DEV.EVAL.CFG_STAGE/router_eval_config.yaml');

-- View results
-- SELECT METRIC_NAME, ROUND(AVG(EVAL_AGG_SCORE), 3) AS avg_score
-- FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
--   'FROSTBYTE_AI_DEV', 'AGENTS', 'ELT_ROUTER', 'CORTEX AGENT', 'router-v3-eval'))
-- WHERE METRIC_NAME IS NOT NULL
-- GROUP BY METRIC_NAME;

-- Step 5: If eval passes (answer_correctness >= 0.75, logical_consistency >= 0.80), promote
-- ALTER AGENT ELT_ROUTER MODIFY VERSION VERSION$3 SET ALIAS = production;
