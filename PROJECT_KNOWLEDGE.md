# PROJECT_KNOWLEDGE.md

Single source of truth for the AMI Snowflake native git integration demo. If you're reading this for the first time, start here.

## 1. What this is

A 4-phase build that shows National Grid AMI moving from SnowSQL-on-Jenkins deploys to native Snowflake CI/CD. Same end state, less infrastructure.

Schema and role names mirror prod `ami_env_dev.cfg`, so anything here can be lifted into prod with no rename.

Demo account: `KEGHDAI-GVA52989` (Azure East US 2, Enterprise trial, ends June 18, 2026).

## 2. Phases at a glance

| Phase | Pattern | Who runs it | Auth |
|---|---|---|---|
| 1 | Manual `EXECUTE IMMEDIATE FROM` in Snowsight worksheet | Human | Password |
| 1.5 | Snowsight Workspaces edit + commit + push | Human via Snowsight UI | Password |
| 2 | GitHub Actions auto-deploy on push to main | CI runner | JWT keypair |
| 3 | DCM Projects PLAN/DEPLOY | CI runner or human | JWT keypair |

Status: 1, 1.5, 2 done and verified. 3 scaffolded, first PLAN pending.

## 3. Architecture (one picture in words)

```
GitHub repo (source of truth)
    ↑
    | (1) ALTER GIT REPOSITORY ... FETCH
    |     auth: PAT in AMI_DEMO_DB.GIT_OPS.GITHUB_PAT_SECRET
    |
Snowflake AMI_GIT_REPO (local clone, schema-level object)
    ↑
    | (2a) EXECUTE IMMEDIATE FROM @AMI_GIT_REPO/branches/main/deploy/deploy.sql   (Phase 1/2)
    | (2b) EXECUTE DCM PROJECT AMI_DCM_PROJECT PLAN / DEPLOY                       (Phase 3)
    |     auth: JWT keypair (Phase 2/3) or password (Phase 1)
    |
GitHub Actions runner (Phase 2/3 only)
```

Two distinct auth paths:
- **PAT** = how Snowflake authenticates TO GitHub when FETCHing
- **JWT keypair** = how snow CLI on the runner authenticates TO Snowflake

Both are needed. They serve different legs of the trip.

## 4. Account objects

### Database and warehouse
- `AMI_DEMO_DB` (Phase 1)
- `NONPROD_AMI_ADMIN_WH` (XSMALL, AUTO_SUSPEND=60, INITIALLY_SUSPENDED=TRUE)

### Data schemas (8)
`AMICORP, AMICOMM, FRAMEWORK, AMIRPTS, AMISTAGE, XREF, AMICIAP, AMIINT`

### Ops schema (1)
`GIT_OPS` - holds the secret, API integration, GIT REPOSITORY, and DCM project object

### Roles (6)
```
SYSADMIN
├── DEV_AMI_ADMIN_ROLE         (owns DB + schemas)
│   ├── DEV_AMI_LOAD_ROLE      (loader, INSERT/UPDATE/DELETE on tables)
│   ├── DEV_AMI_SELECT_ROLE    (read only)
│   ├── DEV_AMI_MLS_ROLE       (MLS / masking consumer)
│   └── DEV_AMI_PBI_ROLE       (Power BI consumer)
└── NONPROD_AMI_SUPPORT_ROLE   (ops monitor, SELECT on logs)
```

### Git integration objects (`AMI_DEMO_DB.GIT_OPS`)
- `GITHUB_PAT_SECRET` (PASSWORD type, fine-grained PAT, expires Aug 17, 2026)
- `GITHUB_API_INTEGRATION` (GIT_HTTPS_API, prefix locked to `https://github.com/raviteja0012/`)
- `AMI_GIT_REPO` (GIT REPOSITORY, origin = the snowflake-demo repo)
- `AMI_DCM_PROJECT` (DCM PROJECT, Phase 3, points at dcm/ folder)

### Framework objects (`AMI_DEMO_DB.FRAMEWORK`)
- `EMAIL_BODY_DISPLAY_CONFIG` (14 seed rows)
- `DEPLOY_LOG` (one row per deploy)
- `PROCESS_LOG` (one row per process step)
- `SP_LOG_DEPLOY(VARCHAR, VARCHAR)` (writes 3 PROCESS_LOG rows: start, component, completed)
- `FRMWK_RETRY_TASK` (hourly, SUSPENDED on every deploy)

### Data objects (`AMI_DEMO_DB.AMISTAGE`)
- `DIM_METER` (8 sample rows)
- `FACT_METER_READS` (24 sample rows)

## 5. Auth setup (Phase 2 keypair)

### Keypair generation
Generated in Windows Git Bash, May 19, 2026, at `~/.snowflake-demo-ci/`:
```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

### Public key on user
`ALTER USER RAVITEJA0012 SET RSA_PUBLIC_KEY = '...'` (bootstrap/03_keypair_auth.sql)

User keeps password auth and gets keypair auth simultaneously.

### GitHub Secrets (3 set, all verified)
- `SNOWFLAKE_ACCOUNT` = `KEGHDAI-GVA52989`
- `SNOWFLAKE_USER` = `RAVITEJA0012`
- `SNOWFLAKE_PRIVATE_KEY` = full rsa_key.p8 contents

### Public key fingerprint (verified)
`SHA256:N1DtXEcFMZ9JmqIbb7JmtBYFBk2n/hAY3W4B2+g6fC4=`

### GIT REPOSITORY privileges
Valid: `READ`, `WRITE`. OPERATE is NOT valid for this object.

Grants:
- `DEV_AMI_ADMIN_ROLE` has READ (Phase 1) + WRITE (Phase 2, needed for FETCH from CI)
- `NONPROD_AMI_SUPPORT_ROLE` has READ only

### PAT rotation
Set calendar reminder for Aug 2, 2026 (day 75 of 90-day expiry).

Rotation:
```sql
ALTER SECRET AMI_DEMO_DB.GIT_OPS.GITHUB_PAT_SECRET SET PASSWORD = 'github_pat_new';
ALTER GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO FETCH;
```

## 6. Deploy log (audit trail)

### Where to look
- `AMI_DEMO_DB.FRAMEWORK.DEPLOY_LOG` - one row per deploy (own audit)
- `AMI_DEMO_DB.FRAMEWORK.PROCESS_LOG` - one row per step
- `INFORMATION_SCHEMA.QUERY_HISTORY` - last 7 days, per-statement, real-time
- `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` - 365 days, 45 min latency, ACCOUNTADMIN
- GitHub Actions artifacts - .log files, 30 days (60 for verbose)

### Verified successful deploys
| Run | Trigger | Commit | Status |
|---|---|---|---|
| DEPLOY_ID=1 | Manual Snowsight (Phase 1) | initial scaffold | SUCCESS |
| DEPLOY_ID=101 | Workspaces edit+push (Phase 1.5) | aadecc34 | SUCCESS |
| DEPLOY_ID=201 | GitHub Actions (Phase 2) | 91e8b9eb | SUCCESS in 1m 44s |
| DEPLOY_ID=301 | GitHub Actions (Phase 2 + log artifact) | eb624896 | SUCCESS in 1m 42s |
| DEPLOY_ID=401 | GitHub Actions VERBOSE | 28c4df78 | SUCCESS, full QUERY_HISTORY captured |

### What QUERY_HISTORY exposes
EIF child statements DO appear as individual QUERY_HISTORY rows (verified DEPLOY_ID=401):
- Each `CREATE OR ALTER TABLE`, `GRANT`, `MERGE`, etc. gets its own row
- Each nested `EXECUTE IMMEDIATE FROM ...` also gets a row
- Status, elapsed_sec, error_code per row

This means we have full SnowSQL .log file equivalent visibility via Section 3 of `deploy-verbose.yml`.

## 7. GitHub Actions workflows

### deploy.yml (auto-deploy)
- Triggers: push to main with `deploy/**`, `bootstrap/**`, or workflow file change
- Job-level env vars for snow CLI (SNOWFLAKE_ACCOUNT, USER, JWT, etc.)
- Steps: checkout → init log → install snow CLI → write key → verify → fetch → deploy → smoke test → finalize → upload artifact
- Log artifact: `ami-deploy-log-run<id>`, 30-day retention

### deploy-verbose.yml (manual trigger)
- workflow_dispatch only, with optional `log_query_history_minutes` input (default 5)
- Adds 3 sections to the log:
  - Section 1: cat every .sql file from the checkout
  - Section 3: QUERY_HISTORY for the deploy window (per-statement audit)
  - Section 4: smoke test results
- Artifact: 60-day retention

### dcm-deploy.yml (Phase 3)
- Triggers: push to main with `dcm/**`, or PR to main with `dcm/**`, or workflow_dispatch
- On PR: PLAN only (review the diff)
- On push: PLAN then DEPLOY
- Manual: optional `plan_only=true` to skip DEPLOY

### Required env on the runner
```yaml
SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
SNOWFLAKE_AUTHENTICATOR: SNOWFLAKE_JWT
SNOWFLAKE_PRIVATE_KEY_FILE: /home/runner/.snowflake/rsa_key.p8
SNOWFLAKE_ROLE: DEV_AMI_ADMIN_ROLE
SNOWFLAKE_WAREHOUSE: NONPROD_AMI_ADMIN_WH
SNOWFLAKE_DATABASE: AMI_DEMO_DB
```

### snow CLI flags
- `snowflakedb/snowflake-cli-action@v2.0` (no cli-version specified, uses latest)
- Every `snow sql -x -q "..."` call uses `-x` (--temporary-connection) so it picks up env vars
- `set -o pipefail` on every step that tees to a log file

## 8. Bugs hit and fixed (9 total)

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | `SHOW ROLES LIKE 'X' OR 'Y'` errors | Compound LIKE not supported | `SHOW ROLES` + RESULT_SCAN filter |
| 2 | API_ALLOWED_PREFIXES rejected repo URL | ORIGIN ends in `.git`, literal prefix match | Broadened to `https://github.com/raviteja0012/` |
| 3 | Jinja `UndefinedError` on `{{ var }}` in SQL comment | Jinja parses comments too | Rewrote comment without braces |
| 4 | CREATE OR ALTER mid-column insert fails | Snowflake only allows END-of-list column adds | Moved `SUPPLY_VOLTAGE_NOMINAL` to end |
| 5 | `GRANT OPERATE ON GIT REPOSITORY` invalid | Only READ/WRITE valid for GIT REPOSITORY | Used `GRANT WRITE` |
| 6 | `SHOW USERS` doesn't expose `rsa_public_key_fp` | SHOW USERS only has boolean has_rsa_public_key | Use `DESC USER` + RESULT_SCAN |
| 7 | GitHub Action: snowflake-cli-action repo path 404 | Wrong path `Snowflake-Labs/v1.5` | Corrected to `snowflakedb/snowflake-cli-action@v2.0` |
| 8 | `cli-version: latest` breaks uv parser | uv doesn't parse "latest" as a version | Removed `with: cli-version` block (action defaults to latest) |
| 9 | `snow sql` errors "Connection default is not configured" | snow CLI needs explicit connection | Added `-x` (--temporary-connection) flag to every call |

## 9. File structure

```
snowflake-demo/
├── README.md
├── PROJECT_KNOWLEDGE.md             this file
├── .gitignore
├── bootstrap/
│   ├── 01_account_setup.sql         Phase 1: DB, WH, schemas, roles
│   ├── 02_git_integration.sql       Phase 1: PAT, API integration, GIT REPOSITORY
│   ├── 03_keypair_auth.sql          Phase 2: public key, GRANT WRITE
│   └── 04_dcm_project_bootstrap.sql Phase 3: DCM PROJECT object
├── deploy/                          imperative deploy (Phase 1/2)
│   ├── deploy.sql                   orchestrator
│   ├── View_Deploy_History.sql      5 audit queries
│   ├── 01_grants/01_BaseGrants_DDL_v1.0.sql
│   ├── 10_framework/10_FrameworkConfig_DDL_v1.0.sql
│   ├── 10_framework/11_FrameworkLog_DDL_v1.0.sql
│   ├── 20_dimensions/20_MeterDim_DDL_v1.0.sql
│   ├── 30_facts/30_MeterReadsFact_DDL_v1.0.sql
│   ├── 40_procedures/40_LogDeploySP_DDL_v1.0.sql
│   ├── 50_tasks/50_RetryTask_DDL_v1.0.sql
│   ├── 60_dml/60_FrameworkEmailSeed_DML_v1.0.sql
│   └── 70_sample_data/70_SampleData_DML_v1.0.sql
├── dcm/                             declarative deploy (Phase 3)
│   ├── manifest.yml
│   └── definitions/
│       ├── 00_database_and_schemas.sql
│       ├── 10_framework_tables.sql
│       ├── 20_dim_meter.sql
│       └── 30_fact_meter_reads.sql
├── .github/workflows/
│   ├── deploy.yml                   Phase 2 auto-deploy
│   ├── deploy-verbose.yml           Phase 2 manual full audit
│   └── dcm-deploy.yml               Phase 3 PLAN + DEPLOY
├── Snow_Config/                     reference only (mirrors prod cfg)
└── docs/
    ├── SETUP.md
    ├── EXPECTED_LOGS.md
    └── PHASE_3_DCM.md
```

## 10. Architectural Q&A (for the NG demo)

### Q: Why two auth paths (PAT and JWT)? Aren't they redundant?
A: No. They're for different directions:
- **PAT** is for the leg `Snowflake -> GitHub` (FETCH). Snowflake authenticates itself when reading the repo.
- **JWT keypair** is for the leg `Runner -> Snowflake`. The CI runner's snow CLI authenticates itself to Snowflake.

Removing the GIT REPOSITORY object would remove the need for PAT, but then we lose: commit_hash audit, Snowsight-only deploys (no CI needed), server-side caching, the Snowflake-blessed pattern.

### Q: Why keep both Phase 2 (EIF) and Phase 3 (DCM)?
A: DCM only supports a subset of object types (tables, views, grants, warehouses, roles, schemas, databases). Stages, file formats, secrets, integrations, tasks, procedures still need imperative deploys. Hybrid pattern works fine, both coexist.

### Q: How is this different from schemachange / dbt / Terraform?
- **schemachange** is migration-based (versioned scripts). Good for forward-only changes. DCM is declarative diff-based.
- **dbt** is for transformations (models), not for DDL on the underlying tables.
- **Terraform** can do Snowflake objects but lives outside Snowflake. DCM is native, no external state file.

### Q: What does failure look like?
- Phase 2 EIF: statements before the failure commit, statements after don't run. `DEPLOY_LOG.DEPLOY_END_TS` stays NULL. Re-run idempotent scripts to recover.
- Phase 3 DCM: partial execution possible on DEPLOY failure. Fix the definition file, re-run DEPLOY, Snowflake reconciles.

### Q: Drift detection?
- Phase 2: none. We don't compare deploy.sql to current state.
- Phase 3: built in. `PLAN` shows ALTER/CREATE/DROP per object before you apply.

## 11. Pending and TODOs

- [ ] First DCM PLAN + DEPLOY run on `AMI_DCM_PROJECT` to verify it works end-to-end
- [ ] Update SETUP.md with Phase 3 walkthrough (after first verified DCM deploy)
- [ ] Architecture slide deck for NG team (Bavya, Suresh, Eugene, Ajay)
- [ ] PAT rotation reminder for Aug 2, 2026
- [ ] Decide: keep email seed + sample data in Phase 2 EIF, or move to DCM migrations
- [ ] Multi-env: add test/uat/prod targets to manifest.yml when ready

## 12. Glossary

| Term | Meaning |
|---|---|
| EIF | EXECUTE IMMEDIATE FROM. Runs a SQL file from a stage or git repo. |
| Native Git Integration | Snowflake reads files directly from a Git repo via GIT REPOSITORY object. |
| DCM Projects | Database Change Management. Declarative deploys with PLAN/DEPLOY. |
| DEFINE | DCM keyword to declare an object should exist. Replaces CREATE/CREATE OR ALTER in DCM files. |
| JWT keypair | Service account auth for snow CLI. RSA public key on user, private key on runner. |
| PAT | GitHub Personal Access Token. Fine-grained scope, Contents+Metadata read only. |
| Snowsight Workspaces | Browser IDE inside Snowsight. Can edit a Git repo and push commits back. |
| Snow CLI | `snow` command-line tool. Successor to SnowSQL for newer features. |
