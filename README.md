# Frostbyte ELT Multi-Agent Demo

End-to-end build of a Snowflake Intelligence multi-agent system for the Frostbyte ELT.

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

The scripts use unqualified database references where possible so they work in either env via `USE DATABASE`.

## Demo runbook

See `assets/build_plan.md` Step 9 for the 9-beat live demo script.
