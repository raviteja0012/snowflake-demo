# Phase 3 setup: DCM Projects

Declarative deploys for Snowflake using DCM Projects (open preview, March 2026).

This is parallel to Phase 1 and 2, not a replacement. Phase 2 imperative deploys still work. DCM is for the parts where we want a true diff-and-apply model (mostly tables, views, grants, warehouses, roles).

## What DCM gives you over Phase 2

| Thing | Phase 2 (EIF) | Phase 3 (DCM) |
|---|---|---|
| Mental model | Imperative: run these statements | Declarative: this is the end state |
| What runs | Every statement, every time | Only what differs from current state |
| Preview | `DRY_RUN = TRUE` (rendered SQL only) | `PLAN` (shows CREATE/ALTER/DROP per object) |
| Drift detection | None. We don't know what's "current". | Built in. PLAN compares declared vs actual. |
| Drops on remove | No. Removing from deploy.sql doesn't drop the object. | Yes. Removing from DEFINE drops the object. |
| Audit | Custom DEPLOY_LOG + QUERY_HISTORY | Snowflake stores immutable deployment artifacts per run |
| Supported objects | Anything (it's just SQL) | Limited list. As of May 2026: tables, dynamic tables, views, warehouses, roles, grants, schemas, databases. NOT supported: file formats, stages, secrets, integrations. |

So DCM handles tables/views/grants/warehouses. Stages, file formats, secrets, API integrations, GIT REPOSITORY, tasks still go through Phase 2 EIF.

## One-time setup

1. Phase 1 and 2 bootstrap already done (`AMI_DEMO_DB`, `AMI_GIT_REPO`, keypair). No re-do needed.
2. Run `bootstrap/04_dcm_project_bootstrap.sql` as ACCOUNTADMIN. Creates `AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT`.

## Manual run from Snowsight

```sql
USE ROLE DEV_AMI_ADMIN_ROLE;

-- PLAN: preview without changing anything
EXECUTE DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT PLAN
    USING CONFIGURATION (target => 'dev');

-- DEPLOY: apply
EXECUTE DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT DEPLOY
    USING CONFIGURATION (target => 'dev');

-- See past deployments
SHOW DEPLOYMENTS IN PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT;
```

## GitHub Actions

`.github/workflows/dcm-deploy.yml` does:
- On PR to main with dcm/* changes: PLAN only (review the diff)
- On push to main with dcm/* changes: PLAN then DEPLOY
- Manual trigger: optional `plan_only` to skip the DEPLOY

## What's in dcm/

```
dcm/
├── manifest.yml                       targets + templating
└── definitions/
    ├── 00_database_and_schemas.sql   DB + schemas as DEFINE
    ├── 10_framework_tables.sql       EMAIL_BODY_DISPLAY_CONFIG, DEPLOY_LOG, PROCESS_LOG
    ├── 20_dim_meter.sql              DIM_METER
    └── 30_fact_meter_reads.sql       FACT_METER_READS
```

Order of files doesn't matter. Snowflake sorts dependencies itself.

## What's still on Phase 2

These objects don't have DCM support yet, so they stay in deploy/:
- GIT REPOSITORY, API integration, secret (bootstrap only anyway)
- FRMWK_RETRY_TASK (tasks not in DCM yet)
- SP_LOG_DEPLOY procedure (procedures not in DCM yet)
- Sample data (DML, not DDL)
- Email config seed (DML)

Hybrid pattern is fine. Run DCM for tables/grants, run EIF for everything else. Both can coexist in the same deploy.

## Limits to know

- 1000 source files max per project
- 10000 entities/grants max per project
- 10 MB total project size
- DEFINE statements are order-independent (Snowflake sorts)
- Preview feature, occasional changeset gaps (per Snowflake docs)
- DEPLOY can drop objects. Be careful before merging removes to main.

## Migration path

We're not deleting Phase 2. The plan:
1. Land DCM Project for tables + grants + DB/schema (this commit)
2. Run both pipelines side by side for a sprint
3. Once stable, move sample data + email seed to migrations folder (DCM migration scripts handle DML)
4. Keep Phase 2 EIF for tasks, procs, stages
5. Eventually Phase 2 deploy.sql shrinks to "things DCM doesn't support yet"

## Reference

- https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-overview
- https://docs.snowflake.com/en/release-notes/2026/other/2026-03-20-dcm-projects
