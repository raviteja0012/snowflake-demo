# snowflake-demo

AMI Snowflake native git integration demo. CI/CD for Snowflake schema deployment
without GitHub Actions, without a CLI runner, and without DCM Projects.

Engine: `EXECUTE IMMEDIATE FROM @git_repo/branches/main/deploy/deploy.sql USING (...)`.
Replaces SnowSQL `!source` + `&VAR` substitution from the production AMI codebase.

## What this is

Phase 1 of a multi-phase plan to bring National Grid's AMI deployment pattern
into a git-driven CI/CD workflow. Stripped-down example codebase that mirrors
the prod AMI patterns at small scale, deployed via Snowflake's native git
integration to a single demo account (KEGHDAI-GVA52989, Azure East US 2).

The prod codebase uses SnowSQL `ami_deploy.sql` orchestrator + `!source ./Snow_Config/ami_env_dev.cfg`
+ `&VAR` substitution. This demo replaces that with:

- A Jinja-templated `deploy/deploy.sql` orchestrator
- `EXECUTE IMMEDIATE FROM` for both top-level and nested script chaining
- `USING (var => 'value', ...)` for per-env value injection
- The repo registered as a `GIT REPOSITORY` object in Snowflake, refreshed by `ALTER GIT REPOSITORY ... FETCH`

Roles and schemas mirror `ami_env_dev.cfg` so the scripts could be lifted into
the prod codebase with no rename.

## Repo layout

```
snowflake-demo/
├── README.md                                  this file
├── bootstrap/
│   ├── 01_account_setup.sql                   one-time: DB, WH, schemas, roles, grants
│   └── 02_git_integration.sql                 one-time: PAT secret, API integration, GIT REPOSITORY
├── deploy/
│   ├── deploy.sql                             top-level orchestrator (Jinja-templated)
│   ├── 01_grants/
│   │   └── 01_BaseGrants_DDL_v1.0.sql
│   ├── 10_framework/
│   │   ├── 10_FrameworkConfig_DDL_v1.0.sql    EMAIL_BODY_DISPLAY_CONFIG
│   │   └── 11_FrameworkLog_DDL_v1.0.sql       DEPLOY_LOG + PROCESS_LOG
│   ├── 20_dimensions/
│   │   └── 20_MeterDim_DDL_v1.0.sql           DIM_METER
│   ├── 30_facts/
│   │   └── 30_MeterReadsFact_DDL_v1.0.sql     FACT_METER_READS
│   ├── 40_procedures/
│   │   └── 40_LogDeploySP_DDL_v1.0.sql        SP_LOG_DEPLOY with exception handlers
│   ├── 50_tasks/
│   │   └── 50_RetryTask_DDL_v1.0.sql          Hourly task, ships SUSPENDED
│   └── 60_dml/
│       └── 60_FrameworkEmailSeed_DML_v1.0.sql Idempotent seed
├── Snow_Config/                               REFERENCE ONLY (not consumed at runtime)
│   ├── README.md
│   └── ami_env_dev.cfg
└── docs/
    ├── SETUP.md                               click-by-click setup, 7 steps, 20-25 min
    └── EXPECTED_LOGS.md                       what each step should look like
```

## To run the demo

Read `docs/SETUP.md`. Follow the seven steps.

After the first green deploy, cross-check what you see against `docs/EXPECTED_LOGS.md`.

## What this demonstrates

- Jinja-templated SQL committed to git, deployed by Snowflake reading directly from the repo
- PAT authentication (fine-grained, Contents+Metadata Read only)
- `ALTER GIT REPOSITORY ... FETCH` as the pull-to-Snowflake step
- `EXECUTE IMMEDIATE FROM ... USING (...) DRY_RUN = TRUE` as the preview step
- `EXECUTE IMMEDIATE FROM ... USING (...)` as the actual deploy
- Nested EXECUTE IMMEDIATE FROM with relative paths (the equivalent of SnowSQL `!source`)
- Idempotent deploys via `CREATE OR ALTER TABLE` and `INSERT ... WHERE NOT EXISTS`
- Mirror of prod patterns: process logging with exception handlers, SUSPENDED tasks, audit columns

## What this does NOT demonstrate (later phases)

- PR review gate (GitHub Actions + `snow sql` is Phase 2)
- Automatic deploy on `git push` (Phase 2 via GitHub Actions, or a Snowflake TASK on schedule)
- Declarative diff against current state (DCM Projects is Phase 3)
- Multi-environment promotion (single-env demo; multi-env is Phase 1.5)

Each is a follow-on, not a rebuild. The Phase 1 deploy.sql + Jinja templates remain useful in Phase 2.

## Limitations

See `docs/SETUP.md` "Troubleshooting fast-path" and the project plan for the full list.
Headline ones:

- Jinja2 templating + USING + DRY_RUN are labelled "Preview - Open, Available to all accounts" on the docs as of May 2026. Functionally stable but not GA-stamped per a release note.
- No automatic trigger. Every deploy needs manual FETCH + EIF, a scheduled TASK, or external CI.
- Partial failures are not rolled back. Statements prior to the failure are committed.
- Audit trail is `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` plus the demo's own `FRAMEWORK.DEPLOY_LOG`.

## License / context

Internal demo for National Grid AMI deployment pattern research. Not for redistribution.
