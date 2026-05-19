# snowflake-demo

AMI Snowflake CI/CD demo using native Git integration. No external runner needed, no SnowSQL CLI.

The engine is one statement:
```sql
EXECUTE IMMEDIATE FROM @AMI_GIT_REPO/branches/main/deploy/deploy.sql USING (...);
```

Replaces SnowSQL `!source` + `&VAR` substitution from prod AMI.

## Why this exists

Prod AMI uses `ami_deploy.sql` orchestrator with SnowSQL CLI on a Jenkins box. Works fine, but ties deploys to one runner box. Native Git Integration moves the engine into Snowflake itself, so anyone with the right role can deploy from Snowsight directly. GitHub Actions is optional, not required.

Snowflake account: `KEGHDAI-GVA52989` (Azure East US 2, Enterprise trial, 30 day window).

Schema and role names mirror `ami_env_dev.cfg` so scripts can be lifted into prod without rename.

## Phases done

| Phase | What | Status |
|---|---|---|
| 1 | Manual EIF in Snowsight worksheet | done |
| 1.5 | Snowsight Workspaces edit + push + redeploy | done |
| 2 | GitHub Actions auto-deploy on push to main, JWT keypair | done |
| 3 | DCM Projects (declarative, plan-then-deploy) | done, round-trip verified |

## Layout

```
snowflake-demo/
├── README.md
├── PROJECT_KNOWLEDGE.md             single source of truth, full design + bug log
├── bootstrap/                       one-time setup, ACCOUNTADMIN
│   ├── 01_account_setup.sql         DB, WH, schemas, roles
│   ├── 02_git_integration.sql       PAT secret, API integration, GIT REPOSITORY
│   ├── 03_keypair_auth.sql          Phase 2 keypair + GRANT WRITE
│   └── 04_dcm_project_bootstrap.sql Phase 3 DCM PROJECT object
├── deploy/                          imperative deploy (Phase 1/2)
│   ├── deploy.sql                   orchestrator, Jinja templated
│   ├── View_Deploy_History.sql      audit queries
│   ├── 01_grants/ … 70_sample_data/
├── dcm/                             declarative deploy (Phase 3)
│   ├── manifest.yml
│   └── sources/definitions/
├── .github/workflows/
│   ├── deploy.yml                   Phase 2 auto-deploy
│   ├── deploy-verbose.yml           Phase 2 manual full audit
│   └── dcm-deploy.yml               Phase 3 PLAN + DEPLOY
├── Snow_Config/                     reference only
└── docs/                            SETUP.md, EXPECTED_LOGS.md, PHASE_3_DCM.md
```

## Run the demo

See `docs/SETUP.md`. Seven steps, 20-25 min.

## What this shows

- Jinja templated SQL in Git, Snowflake reads and runs it directly
- Fine grained PAT, Contents + Metadata read only
- `ALTER GIT REPOSITORY ... FETCH` pulls latest commit into Snowflake clone
- `EXECUTE IMMEDIATE FROM ... DRY_RUN = TRUE` for preview
- `EXECUTE IMMEDIATE FROM ... USING (...)` for actual deploy
- Nested EIF with relative paths, replaces SnowSQL `!source`
- Idempotent re-runs via `CREATE OR ALTER TABLE` and `INSERT ... WHERE NOT EXISTS`
- Prod patterns: process logging with exception handlers, SUSPENDED tasks, audit cols

## Limitations

- Jinja2 + USING + DRY_RUN is Open Preview as of May 2026. Functional but no GA flag.
- Partial failures don't roll back. Statements before failure are already committed.
- Audit: `FRAMEWORK.DEPLOY_LOG` (own) plus `INFORMATION_SCHEMA.QUERY_HISTORY` (7 days) or `ACCOUNT_USAGE.QUERY_HISTORY` (365 days, 45 min lag).

## Internal use only

NG AMI demo. Not for redistribution.
