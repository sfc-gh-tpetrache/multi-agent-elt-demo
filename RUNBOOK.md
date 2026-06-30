# Runbook — Frostbyte ELT Multi-Agent Demo

Step-by-step execution guide for setting up and demoing the build.

## Prerequisites

- Snowflake account with Cortex Agents, Cortex Search, Cortex Analyst enabled.
- Two named connections in your `~/.snowflake/config.toml`:
  - `frostbyte_dev`
  - `frostbyte_prod`
- `snow` CLI installed.
- Python 3.11+ with `faker`, `snowflake-connector-python`, `pyyaml`.
- A GitHub repo created and its URL pasted into `sql/01_setup/02_git_integration.sql` (ORIGIN line).

## One-time bootstrap

```bash
# 1. Account-level objects (run ONCE as ACCOUNTADMIN)
snow sql -f multi-agent-pipeline/sql/01_setup/00_databases_warehouses_roles.sql \
  --connection frostbyte_dev

# 2. Per-database role grants (run twice: --connection frostbyte_dev, then _prod)
for conn in frostbyte_dev frostbyte_prod; do
  snow sql -f multi-agent-pipeline/sql/01_setup/01_schema_grants.sql --connection $conn
  snow sql -f multi-agent-pipeline/sql/01_setup/02_git_integration.sql --connection $conn
done
```

## DEV pipeline

```bash
CONN=frostbyte_dev

# Governance (tags, masking, RAP, audit event table)
for f in multi-agent-pipeline/sql/02_governance/*.sql; do
  snow sql -f "$f" --connection $CONN
done

# Generate + upload seeds
python multi-agent-pipeline/data/generators/generate_synthetic_data.py
snow stage put-file multi-agent-pipeline/data/seeds/*.csv @ARTIFACTS.SEEDS \
  --auto-compress=false --connection $CONN

# Data pipeline: RAW tables, attach policies, COPY, STG/INT/MARTS DTs, SVs
for f in multi-agent-pipeline/sql/03_data_pipeline/*.sql; do
  snow sql -f "$f" --connection $CONN
done

# Search
snow sql -f multi-agent-pipeline/sql/04_search/00_css_hr_policies.sql --connection $CONN

# Certification chain
for f in multi-agent-pipeline/sql/05_certification/*.sql; do
  snow sql -f "$f" --connection $CONN
done

# Certify each SV
snow sql -q "USE ROLE CERTIFIER_RL; CALL GOVERNANCE.CERTIFY_SEMANTIC_VIEW('SEMANTIC.SV_MKT_CAMPAIGN_ROI');" --connection $CONN
snow sql -q "USE ROLE CERTIFIER_RL; CALL GOVERNANCE.CERTIFY_SEMANTIC_VIEW('SEMANTIC.SV_SALES_PIPELINE');"   --connection $CONN
snow sql -q "USE ROLE CERTIFIER_RL; CALL GOVERNANCE.CERTIFY_SEMANTIC_VIEW('SEMANTIC.SV_HR_HEADCOUNT');"     --connection $CONN

# Agents + MCP servers + router
for f in multi-agent-pipeline/sql/06_agents/*.sql; do
  snow sql -f "$f" --connection $CONN
done

# Eval scaffolding
for f in multi-agent-pipeline/sql/07_eval/*.sql; do
  snow sql -f "$f" --connection $CONN
done
```

## PROD bootstrap

Re-run every step above with `CONN=frostbyte_prod` once the DEV environment is verified.

## Live demo script (9 beats)

1. **Open Snowflake Intelligence in Snowsight, role `ELT_RL`.** Type *"Good morning"*. Skill triggers, three parallel `CORTEX_AGENT_RUN` calls, single Summit Sync brief.
2. **Cross-domain ad-hoc**: *"Are we hiring fast enough in EMEA to support the Cornice launch in Chamonix?"* — all three sub-agents.
3. **HR Search + Analyst**: *"What is our parental leave policy for EMEA, and how many EMEA hires are pending?"* — HR agent uses both tools.
4. **Per-agent mask shape**: as `HR_PII_RL`, run the same query in a worksheet vs ask Marketing agent. Show the masking policy body live.
5. **Per-agent row access**: Sales-agent query against `dim_employee` -> 0 rows; HR-agent path -> rows.
6. **Certification gate**:
   ```sql
   USE ROLE CERTIFIER_RL;
   ALTER SEMANTIC VIEW SEMANTIC.SV_HR_HEADCOUNT UNSET TAG GOVERNANCE.CERTIFIED;
   ```
   Re-ask *"Good morning"*. HR slice reports "not certified". Re-certify:
   ```sql
   CALL GOVERNANCE.CERTIFY_SEMANTIC_VIEW('SEMANTIC.SV_HR_HEADCOUNT');
   ```
7. **RBAC switch**: connect as `ELT_HR_RL`; HR agent works, others denied.
8. **Promote**:
   ```sql
   ALTER AGENT FROSTBYTE_AI_PROD.AGENTS.SALES_AGENT
     ADD VERSION FROM @ARTIFACTS.GIT_REPO/tags/prod-7/agents/sales;
   CALL EVAL.RUN_EVAL('SALES_AGENT', 'VERSION$2', 'ds_sales_summit_sync_v1');
   ALTER AGENT FROSTBYTE_AI_PROD.AGENTS.SALES_AGENT
     MODIFY VERSION VERSION$2 SET ALIAS = production;
   ```
9. **Rollback** one statement:
   ```sql
   ALTER AGENT FROSTBYTE_AI_PROD.AGENTS.SALES_AGENT
     MODIFY VERSION VERSION$1 SET ALIAS = production;
   ```

## Useful inspection queries

```sql
-- Agent versions
SHOW VERSIONS IN AGENT FROSTBYTE_AI_PROD.AGENTS.SALES_AGENT;

-- Which SVs are certified, in which env, by whom
SELECT * FROM TABLE(SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES_ALL_COLUMNS())
WHERE TAG_NAME = 'CERTIFIED' AND TAG_VALUE = 'true';

-- Certification history
SELECT * FROM GOVERNANCE.CERTIFICATION_HISTORY ORDER BY run_at DESC LIMIT 20;

-- Agent-context PII audit
SELECT * FROM GOVERNANCE.V_PII_AUDIT ORDER BY event_time DESC LIMIT 50;

-- Eval trend
SELECT agent_name, metric_name, run_at, eval_agg_score, passed
FROM EVAL.EVAL_RUN_HISTORY
WHERE run_at > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY run_at DESC;
```
