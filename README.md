# Frostbyte ELT Multi-Agent Demo

**Goal:** This demo shows the governed path to building enterprise multi-agent systems on Snowflake — where compliance is built into the tooling, not bolted on after.

## What this demo shows

- **One router, three domain agents** — automatic routing based on intent, with a Git-sourced skill for personalized briefings
- **RBAC everywhere** — domain roles only access their corresponding sub-agent; the ELT role sees everything; the skill itself adapts its output based on `CURRENT_ROLE()`
- **Certified semantic views** — agents can only query data models that passed a certification gate (tag-based, auditable)
- **AI_REDACT on unstructured data** — PII is stripped before it enters Cortex Search; agents never see raw names/emails
- **Agent-aware masking policies** — the same table shows different data depending on whether a human, an agent, or a privileged role queries it
- **CI/CD gated by eval thresholds** — agents must pass `answer_correctness >= 0.75`, `logical_consistency >= 0.80`, `pii_safety >= 0.99` before promotion to production
- **Versioning + rollback** — immutable versions, alias-based promotion, one-statement rollback
- **Full observability** — per-agent traces, cost attribution, and certification history
- **MCP servers** — each sub-agent is also exposed as an MCP server, making it callable from external tools (Cursor, Claude Desktop) via the same governed endpoint

All reproducible from a single Git repo with environment-aware scripts.

## Design Principles Coverage

This demo maps to the [12 Design Principles for Scaling Enterprise Agents](https://github.com/sfc-gh-tpetrache/agents-design-principles/blob/main/design-principles-v2.md). The governed path is the scripted path — every compliance requirement is built into the tooling, not bolted on as an approval queue.

| # | Principle | Demo implementation | Snowflake primitives |
|---|-----------|--------------------|--------------------|
| P1 | Outcomes before agents | Each agent maps to a business requirement from the [company brief](assets/company_brief.md): Marketing → campaign ROI visibility, Sales → pipeline coverage by channel, HR → headcount/attrition + policy access. Eval thresholds serve as proxy metrics for business success (`answer_correctness >= 0.75`, `pii_safety >= 0.99`). | `assets/company_brief.md`, `EXECUTE_AI_EVALUATION`, quality_gate.py |
| P2 | No anonymous agents | Agent identity via `SYS_CONTEXT(AGENT_NAME/AGENT_DATABASE)`. `MP_MASK_SALARY` blocks all agents universally (query-time enforcement on `dim_employee`). `MP_MASK_EMAIL` grants partial access to HR_AGENT specifically. Identity travels through router → MCP → sub-agent chain | `SYS_CONTEXT('SNOWFLAKE$CURRENT')`, `IS_AGENT_ACTIVATED`, `AGENT_NAME` |
| P3 | One front door, one control plane | ELT_ROUTER is the single user-facing agent. One AGENTS schema, one GOVERNANCE schema, one Git repo | `CREATE AGENT`, `CREATE MCP SERVER`, schema design |
| P4 | Specs as code | Agent specs in SQL files, skills in Git, version history tracked in `04_router_v2_version.sql`, promotion from Git tags | `CREATE GIT REPOSITORY`, `GIT_INTEGRATION` skill source |
| P5 | Reuse before build | MCP servers expose sub-agents for reuse by any consumer (router, external clients, other agents). Skills shared via Git | `CREATE MCP SERVER`, `CORTEX_AGENT_RUN` tool type |
| P6 | One vocabulary, enforced at launch | Semantic views enforce shared business terms (channels, regions, product lines). Certification tag validates definitions | `CREATE SEMANTIC VIEW`, `TAG GOVERNANCE.CERTIFIED` |
| P7 | Least context, least privilege | Each agent only accesses its own semantic view. Role-based skill routing — skill only delegates to sub-agents matching `CURRENT_ROLE()`. Router's `SV_USER_CONTEXT` gives it identity data only, not domain data. RAP limits row visibility. Masking hides PII. | Masking policies, Row Access Policies, role hierarchy, `CURRENT_ROLE()` in skill |
| P8 | Gates on inputs, outputs, approvals | Input gate: masking on RAW tables + query-time masking on mart (`MP_MASK_SALARY` on `dim_employee`). Output gate: agent instructions refuse out-of-scope questions ([`sql/06_agents/02_hr_agent.sql`](sql/06_agents/02_hr_agent.sql)). Row access policy gates row visibility ([`sql/02_governance/02_row_access_policies.sql`](sql/02_governance/02_row_access_policies.sql)). Certification gate blocks uncertified SVs | Masking policies, `RAP_HR_EMPLOYEE_SCOPE`, agent instruction refusals |
| P9 | Trust earned and re-earned | Eval runs before promotion (DEV). Quality gate enforces thresholds. Continuous eval possible via scheduled tasks | `EXECUTE_AI_EVALUATION`, `EVAL_RUN_HISTORY`, quality_gate.py |
| P10 | If you can't see it, you can't trust it | Per-agent observability events via `GET_AI_OBSERVABILITY_EVENTS`. Policy enforcement logged in `ACCESS_HISTORY.policies_referenced`. Certification history table. Eval trend queries. | `SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS`, `ACCESS_HISTORY`, `CERTIFICATION_HISTORY` |
| P11 | Lifecycle is mandatory | Agent versioning (VERSION$1→$N), aliases (production), COMMIT workflow, rollback in one statement, sunset task placeholder | `ALTER AGENT ADD VERSION`, `SET ALIAS`, `SET DEFAULT_VERSION` |
| P12 | Pave the road | Env-aware scripts (run same SQL in DEV or PROD), runbook automation, deploy_candidate.py, quality_gate.py — compliant path = scripted path. `SV_USER_CONTEXT` pattern for giving router SQL execution without coupling to domain SVs | `CURRENT_DATABASE()`, `EXECUTE IMMEDIATE`, CI/CD scripts |

## What's in this folder

```
multi-agent-pipeline/
├── assets/                          # Story + plan documents
│   ├── company_brief.md             # Frostbyte storyline
│   └── build_plan.md                # 9-step plan
├── sql/                             # Execution-ordered SQL scripts
│   ├── 01_setup/                    # Databases, roles, warehouses, Git integration
│   ├── 02_governance/               # PII tags, masking, RAP, audit event table
│   ├── 03_data_pipeline/            # RAW base tables + Dynamic Tables + Semantic Views
│   ├── 04_search/                   # Cortex Search service over redacted DT
│   ├── 05_certification/            # SV certification chain (tag, procedure, runtime gate)
│   ├── 06_agents/                   # 3 sub-agents + 3 MCP servers + router
│   └── 07_eval/                     # Eval datasets registration + RUN_EVAL procedure
├── data/                            # Synthetic data
│   ├── generators/generate_synthetic_data.py
│   └── seeds/                       # Generated CSVs land here (gitignored)
├── agent-skills/
│   └── summit_sync_briefing/        # Git-sourced router skill
├── registries/
│   ├── certified_semantic_views.yml
│   └── agent_registry.yml
├── eval/                            # Eval datasets per agent (YAML)
│   ├── marketing/dataset.yaml
│   ├── sales/dataset.yaml
│   ├── hr/dataset.yaml
│   └── router/dataset.yaml
├── scripts/                         # CI pipeline scripts
│   ├── deploy_candidate.py
│   ├── run_evaluation_ci.py
│   ├── poll_evaluation.py
│   ├── quality_gate.py
│   ├── promote_version.py
│   └── rollback.py
└── .github/workflows/agent-cicd.yml
```

## Execution order

Each numbered SQL directory is run in order. Within a directory, files run in lexical order (00, 01, 02, ...).

```bash
# Example: run setup with the snow CLI
for f in sql/01_setup/*.sql; do snow sql -f "$f" --connection my_dev; done
# Repeat for 02_governance, 03_data_pipeline, 04_search, 05_certification, 06_agents, 07_eval
```

## Connections

Two connections are expected (named however you like):
- `frostbyte_dev` -> `FROSTBYTE_AI_DEV` database
- `frostbyte_prod` -> `FROSTBYTE_AI_PROD` database

The scripts use `CURRENT_DATABASE()` for FQN resolution, so the same script works in either environment.

## Demo runbook

See [RUNBOOK.md](RUNBOOK.md) for the full live demo script, PROD promotion flow, and inspection queries.
