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

# Certify each SV (use FQN — procedure requires fully qualified name)
snow sql -q "CALL GOVERNANCE.CERTIFY_SEMANTIC_VIEW('FROSTBYTE_AI_DEV.SEMANTIC.SV_MKT_CAMPAIGN_ROI', 'dev-1');" --connection $CONN
snow sql -q "CALL GOVERNANCE.CERTIFY_SEMANTIC_VIEW('FROSTBYTE_AI_DEV.SEMANTIC.SV_SALES_PIPELINE', 'dev-1');"   --connection $CONN
snow sql -q "CALL GOVERNANCE.CERTIFY_SEMANTIC_VIEW('FROSTBYTE_AI_DEV.SEMANTIC.SV_HR_HEADCOUNT', 'dev-1');"     --connection $CONN

# Agents + MCP servers + router (env-aware scripts use CURRENT_DATABASE())
for f in multi-agent-pipeline/sql/06_agents/0[0-3]*.sql; do
  snow sql -f "$f" --connection $CONN
done

# Eval scaffolding
for f in multi-agent-pipeline/sql/07_eval/*.sql; do
  snow sql -f "$f" --connection $CONN
done
```

## PROD bootstrap (first time)

Re-run the DEV pipeline steps above with `CONN=frostbyte_prod` once DEV evals pass.
The agents should be created with the **latest evaluated version** from DEV — i.e., update
the SQL scripts to match the spec that passed evals before running against PROD.

```bash
CONN=frostbyte_prod

# Infrastructure (governance already deployed from one-time bootstrap)
python data/generators/generate_synthetic_data.py
snow stage put-file data/seeds/*.csv @ARTIFACTS.SEEDS --auto-compress=false --connection $CONN

for f in sql/03_data_pipeline/*.sql; do snow sql -f "$f" --connection $CONN; done
snow sql -f sql/04_search/00_css_hr_policies.sql --connection $CONN
for f in sql/05_certification/*.sql; do snow sql -f "$f" --connection $CONN; done

# Certify SVs
snow sql -q "CALL GOVERNANCE.CERTIFY_SEMANTIC_VIEW('FROSTBYTE_AI_PROD.SEMANTIC.SV_MKT_CAMPAIGN_ROI', 'prod-1');" --connection $CONN
snow sql -q "CALL GOVERNANCE.CERTIFY_SEMANTIC_VIEW('FROSTBYTE_AI_PROD.SEMANTIC.SV_SALES_PIPELINE', 'prod-1');" --connection $CONN
snow sql -q "CALL GOVERNANCE.CERTIFY_SEMANTIC_VIEW('FROSTBYTE_AI_PROD.SEMANTIC.SV_HR_HEADCOUNT', 'prod-1');" --connection $CONN

# Agents + MCP servers + router (creates VERSION$1 with latest evaluated spec)
for f in sql/06_agents/0[0-3]*.sql; do snow sql -f "$f" --connection $CONN; done

# Eval scaffolding
for f in sql/07_eval/*.sql; do snow sql -f "$f" --connection $CONN; done

# Set production alias on all agents
snow sql -q "
  ALTER AGENT AGENTS.MARKETING_AGENT MODIFY VERSION VERSION\$1 SET ALIAS = production;
  ALTER AGENT AGENTS.SALES_AGENT     MODIFY VERSION VERSION\$1 SET ALIAS = production;
  ALTER AGENT AGENTS.HR_AGENT        MODIFY VERSION VERSION\$1 SET ALIAS = production;
  ALTER AGENT AGENTS.ELT_ROUTER      MODIFY VERSION VERSION\$1 SET ALIAS = production;
" --connection $CONN
```

## PROD promotion (subsequent updates)

After the initial PROD bootstrap, use this flow to promote agent changes.

### 1. Develop + eval in DEV

```bash
# Edit agent spec or skill files locally, push to Git
git add . && git commit -m "description" && git push origin main

# Fetch in DEV
snow sql -q "ALTER GIT REPOSITORY ARTIFACTS.GIT_REPO FETCH;" --connection frostbyte_dev

# Version the agent in DEV
snow sql -q "
  USE SCHEMA AGENTS;
  ALTER AGENT ELT_ROUTER ADD LIVE VERSION FROM LAST;
  ALTER AGENT ELT_ROUTER MODIFY LIVE VERSION SET SPECIFICATION = \$\$...\$\$;
  ALTER AGENT ELT_ROUTER COMMIT COMMENT = 'description';
  ALTER AGENT ELT_ROUTER SET DEFAULT_VERSION = LAST;
" --connection frostbyte_dev

# Run eval (MUST use USE SCHEMA AGENTS or agent name won't resolve)
snow sql -q "
  USE SCHEMA AGENTS;
  CALL EXECUTE_AI_EVALUATION('START',
    OBJECT_CONSTRUCT('run_name', 'router-vN-eval'),
    '@EVAL.CFG_STAGE/router_eval_config.yaml');
" --connection frostbyte_dev
```

### 2. Gate check

```bash
# Verify thresholds: answer_correctness >= 0.75, logical_consistency >= 0.80
python scripts/poll_evaluation.py --run-name router-vN-eval --connection frostbyte_dev
python scripts/quality_gate.py --run-name router-vN-eval --connection frostbyte_dev
```

### 3. Tag + promote to PROD

```bash
# Tag the release in Git
git tag prod-N && git push origin prod-N

# Deploy candidate to PROD from the Git tag
python scripts/deploy_candidate.py \
  --agent ELT_ROUTER \
  --connection frostbyte_prod \
  --git-ref tags/prod-N \
  --alias production

# Or manually:
snow sql -q "
  ALTER GIT REPOSITORY ARTIFACTS.GIT_REPO FETCH;
  ALTER AGENT AGENTS.ELT_ROUTER ADD VERSION FROM @ARTIFACTS.GIT_REPO/tags/prod-N/agents/router;
  ALTER AGENT AGENTS.ELT_ROUTER MODIFY VERSION LAST SET ALIAS = production;
  ALTER AGENT AGENTS.ELT_ROUTER SET DEFAULT_VERSION = LAST;
" --connection frostbyte_prod
```

### 4. Rollback (if needed)

```sql
-- Point alias back to previous version
ALTER AGENT AGENTS.ELT_ROUTER MODIFY VERSION VERSION$1 SET ALIAS = production;
ALTER AGENT AGENTS.ELT_ROUTER SET DEFAULT_VERSION = 'VERSION$1';
```

### Notes

- Evals MUST run from `USE SCHEMA AGENTS` or the judge cannot resolve the agent name.
- Each `COMMIT` or `ADD VERSION FROM` creates an immutable VERSION$N — prior versions are never overwritten.
- If a LIVE version already exists, commit it first before creating a new one.
- The `deploy_candidate.py` script expects agent specs at `agents/<agent_lower>/` in the Git repo.

## Live demo script (9 beats)

1. **Open Snowflake Intelligence in Snowsight, role `ELT_RL`.** Type *"Good morning"*. Skill triggers, three parallel `CORTEX_AGENT_RUN` calls, single Summit Sync brief.
2. **Cross-domain ad-hoc**: *"Are we hiring fast enough in EMEA to support the Cornice launch in Chamonix?"* — all three sub-agents.
3. **HR Search + Analyst**: *"What is our parental leave policy for EMEA, and how many employees are in EMEA?"* — HR agent uses both tools; redacted citations show [NAME], [EMAIL].
4. **Per-agent mask shape**: Run the following in a worksheet to show how the same data looks under different contexts:
   ```sql
   USE ROLE ACCOUNTADMIN;
   USE DATABASE FROSTBYTE_AI_PROD;
   USE SCHEMA RAW;

   -- What the HR agent sees (partial masking: first name visible, email domain visible, salary NULL)
   EXECUTE USING POLICY_CONTEXT(
     SNOWFLAKE$CURRENT_AGENT_NAME => 'HR_AGENT',
     SNOWFLAKE$CURRENT_AGENT_DATABASE => 'FROSTBYTE_AI_PROD',
     SNOWFLAKE$CURRENT_AGENT_SCHEMA => 'AGENTS',
     SNOWFLAKE$CURRENT_ACTIVATED_AGENT_TYPES => ('CORTEX_AGENT')
   )
   AS SELECT employee_id, full_name, work_email, base_salary
      FROM FROSTBYTE_AI_PROD.RAW.HR_EMPLOYEES LIMIT 5;

   -- What the HR_PII_RL role sees (clear text — full access)
   EXECUTE USING POLICY_CONTEXT(
     CURRENT_ROLE => 'HR_PII_RL',
     SNOWFLAKE$SESSION_ACTIVATED_ROLES => ('HR_PII_RL')
   )
   AS SELECT employee_id, full_name, work_email, base_salary
      FROM FROSTBYTE_AI_PROD.RAW.HR_EMPLOYEES LIMIT 5;

   -- What a regular user sees (SHA2 hashed — no access)
   EXECUTE USING POLICY_CONTEXT(
     CURRENT_ROLE => 'ELT_HR_RL',
     SNOWFLAKE$SESSION_ACTIVATED_ROLES => ('ELT_HR_RL')
   )
   AS SELECT employee_id, full_name, work_email, base_salary
      FROM FROSTBYTE_AI_PROD.RAW.HR_EMPLOYEES LIMIT 5;
   ```
   Then show the masking policy body: `DESCRIBE MASKING POLICY GOVERNANCE.MP_MASK_EMAIL;`
5. **Per-agent row access**: Sales-agent query against `dim_employee` -> 0 rows; HR-agent path -> rows.
6. **Certification gate**:
   ```sql
   ALTER SEMANTIC VIEW SEMANTIC.SV_HR_HEADCOUNT UNSET TAG GOVERNANCE.CERTIFIED;
   ```
   Re-ask *"Good morning"*. HR slice reports "not certified". Re-certify:
   ```sql
   CALL GOVERNANCE.CERTIFY_SEMANTIC_VIEW('FROSTBYTE_AI_DEV.SEMANTIC.SV_HR_HEADCOUNT', 'demo-recertify');
   ```
7. **RBAC switch**: connect as `ELT_HR_RL`; HR agent works, others denied.
8. **Promote** (live demo of version promotion):
   ```sql
   ALTER GIT REPOSITORY ARTIFACTS.GIT_REPO FETCH;
   ALTER AGENT FROSTBYTE_AI_PROD.AGENTS.SALES_AGENT ADD LIVE VERSION FROM LAST;
   ALTER AGENT FROSTBYTE_AI_PROD.AGENTS.SALES_AGENT MODIFY LIVE VERSION SET SPECIFICATION = $$...$$;
   ALTER AGENT FROSTBYTE_AI_PROD.AGENTS.SALES_AGENT COMMIT COMMENT = 'demo promotion';
   ALTER AGENT FROSTBYTE_AI_PROD.AGENTS.SALES_AGENT MODIFY VERSION LAST SET ALIAS = production;
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
