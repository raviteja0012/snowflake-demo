# Expected outputs at each step

Cross-check your runs against these. Exact text shifts between Snowflake releases, but the shape is stable.

---

## After `bootstrap/01_account_setup.sql`

`SHOW WAREHOUSES LIKE 'NONPROD_AMI_ADMIN_WH'`:
```
name                    state      size     auto_suspend  auto_resume
NONPROD_AMI_ADMIN_WH    SUSPENDED  X-Small  60            true
```

`SHOW SCHEMAS IN DATABASE AMI_DEMO_DB`:
```
AMICORP, AMICOMM, FRAMEWORK, AMIRPTS, AMISTAGE, XREF, AMICIAP, AMIINT, GIT_OPS, INFORMATION_SCHEMA
```
(PUBLIC is dropped. GIT_OPS appears after Step 4.)

`SHOW ROLES` filtered:
```
DEV_AMI_ADMIN_ROLE, DEV_AMI_LOAD_ROLE, DEV_AMI_SELECT_ROLE,
DEV_AMI_MLS_ROLE, DEV_AMI_PBI_ROLE, NONPROD_AMI_SUPPORT_ROLE
```

---

## After `bootstrap/02_git_integration.sql`

`SHOW SECRETS IN SCHEMA AMI_DEMO_DB.GIT_OPS` → 1 row, GITHUB_PAT_SECRET, type PASSWORD
`SHOW API INTEGRATIONS` → 1 row, GITHUB_API_INTEGRATION, enabled TRUE
`SHOW GIT REPOSITORIES` → 1 row, AMI_GIT_REPO, origin github.com/raviteja0012/snowflake-demo.git
`SHOW GIT BRANCHES IN AMI_GIT_REPO` → main with non-empty commit_hash
`LIST @AMI_GIT_REPO/branches/main` → all repo files visible

---

## After `bootstrap/03_keypair_auth.sql` (Phase 2)

`DESC USER RAVITEJA0012` (filtered):
```
RSA_PUBLIC_KEY_FP    SHA256:N1DtXEcFMZ9JmqIbb7JmtBYFBk2n/hAY3W4B2+g6fC4=
RSA_PUBLIC_KEY       MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1Za2...
```

`SHOW GRANTS ON GIT REPOSITORY AMI_GIT_REPO`:
```
privilege  granted_on        granted_to  grantee_name
READ       GIT_REPOSITORY    ROLE        DEV_AMI_ADMIN_ROLE
WRITE      GIT_REPOSITORY    ROLE        DEV_AMI_ADMIN_ROLE
READ       GIT_REPOSITORY    ROLE        NONPROD_AMI_SUPPORT_ROLE
```

---

## After DRY_RUN

Single column, single row. Cell contains the fully-rendered deploy.sql with every `{{ var }}` substituted. Top of the cell looks like:

```sql
USE ROLE      DEV_AMI_ADMIN_ROLE;
USE WAREHOUSE NONPROD_AMI_ADMIN_WH;
USE DATABASE  AMI_DEMO_DB;

EXECUTE IMMEDIATE FROM './01_grants/01_BaseGrants_DDL_v1.0.sql'
    USING (env_db => 'AMI_DEMO_DB', ami_mat_role => 'DEV_AMI_LOAD_ROLE', ...);
...
```

DRY_RUN does NOT recurse into nested EIF calls. To preview a child file, target it directly with DRY_RUN.

---

## After real deploy

Result row:
```
STATUS                       DEPLOY_ID  COMMIT_HASH       DEPLOYED_TO   DEPLOYED_BY    DEPLOYED_ROLE         DEPLOYED_AT
AMI demo deploy complete     401        28c4df788a27...   AMI_DEMO_DB   RAVITEJA0012   DEV_AMI_ADMIN_ROLE    2026-05-19 ...
```

Verify counts:
```
SHOW TABLES IN DATABASE AMI_DEMO_DB     -> 5 rows
SHOW PROCEDURES IN SCHEMA FRAMEWORK     -> 1 row (SP_LOG_DEPLOY)
SHOW TASKS IN SCHEMA FRAMEWORK          -> 1 row (FRMWK_RETRY_TASK, SUSPENDED)
SELECT COUNT(*) FROM EMAIL_BODY_DISPLAY_CONFIG -> 14
SELECT COUNT(*) FROM DIM_METER          -> 8
SELECT COUNT(*) FROM FACT_METER_READS   -> 24
```

---

## After `CALL SP_LOG_DEPLOY('SMOKE_TEST', 'DATA_PROCESSED')`

Return:
```
SUCCESS|Process completed
```

`SELECT * FROM PROCESS_LOG ORDER BY LOG_ID DESC LIMIT 5`:
```
LOG_ID  PROCESS_NAME  COMPONENT             PROC_STATUS  STATUS_DESC
3       SMOKE_TEST    PROCESS_COMPLETED     SUCCESS      Process completed
2       SMOKE_TEST    DATA_PROCESSED        SUCCESS      Component reached: DATA_PROCESSED
1       SMOKE_TEST    PROCESS_STARTED       SUCCESS      Process started for SMOKE_TEST
```

---

## After round-trip (Step 7)

`SHOW GIT BRANCHES` shows new commit_hash matching `git log -1 --format=%H`.
`DESC TABLE DIM_METER` includes new SUPPLY_VOLTAGE_NOMINAL column.
`SHOW TABLES` shows `created_on` for DIM_METER is the original timestamp (CREATE OR ALTER preserved table, no recreate).

---

## Phase 2: GitHub Actions deploy log

Workflow run on push to main produces `ami-deploy-log-run<id>.log` artifact, 30-day retention. Sections:

```
===========================================================
  AMI Deploy Log - GitHub Actions native git integration
===========================================================
  Run ID    : 26112767843
  Commit    : 28c4df788a2789617ab8df0a69b719bb9232d9d2
  Started   : 2026-05-19 17:06:46 UTC
  Account   : KEGHDAI-GVA52989
===========================================================

----- 17:06:50 UTC -- Verify Snowflake connection -----
USER          | ROLE                | WH                       | DB              | TS
RAVITEJA0012  | DEV_AMI_ADMIN_ROLE  | NONPROD_AMI_ADMIN_WH     | AMI_DEMO_DB     | 2026-05-19 ...

----- 17:06:55 UTC -- Fetch from remote git repo -----
ALTER GIT REPOSITORY ... FETCH;
Branch | main | FAST_FORWARD

----- 17:07:05 UTC -- EXECUTE IMMEDIATE FROM deploy.sql -----
STATUS                       | DEPLOY_ID | COMMIT_HASH ...
AMI demo deploy complete     | 401       | 28c4df78...
```

---

## Phase 2 VERBOSE log

`deploy-verbose.yml` adds 3 sections beyond the normal log:

**Section 1: SOURCE CODE** - cats every `bootstrap/*.sql` and `deploy/*.sql` from the checkout into the log. This is the equivalent of the `!source` lines SnowSQL captured in prod.

**Section 3: QUERY_HISTORY** - per-statement audit. Each row in QUERY_HISTORY_BY_USER for the deploy window. Example rows:

```
START_TIME        | STATUS  | ELAPSED_SEC | QUERY_TEXT
10:07:34.110 -07  | SUCCESS | 0.112       | CREATE OR ALTER TABLE EMAIL_BODY_DISPLAY_CONFIG (...)
10:07:40.716 -07  | SUCCESS | 0.153       | CREATE OR ALTER TABLE DEPLOY_LOG (...)
10:07:49.699 -07  | SUCCESS | 0.205       | CREATE OR REPLACE PROCEDURE SP_LOG_DEPLOY(...)
10:08:43.625 -07  | SUCCESS | 0.089       | CREATE OR ALTER TABLE DIM_METER (...)
10:08:53.298 -07  | SUCCESS | 0.085       | CREATE OR ALTER TABLE FACT_METER_READS (...)
10:08:58.994 -07  | SUCCESS | 0.088       | CREATE OR REPLACE TASK FRMWK_RETRY_TASK (...)
10:09:05.325 -07  | SUCCESS | 0.592       | INSERT INTO EMAIL_BODY_DISPLAY_CONFIG (...)
10:09:11.662 -07  | SUCCESS | 0.616       | MERGE INTO DIM_METER tgt USING (...)
10:09:12.304 -07  | SUCCESS | 0.477       | MERGE INTO FACT_METER_READS tgt USING (...)
10:09:12.846 -07  | SUCCESS | 0.272       | UPDATE AMI_DEMO_DB.FRAMEWORK.DEPLOY_LOG SET DEPLOY_STATUS = 'SUCCESS' ...
10:09:13.131 -07  | SUCCESS | 1.482       | CALL AMI_DEMO_DB.FRAMEWORK.SP_LOG_DEPLOY('AMI_DEPLOY', 'GIT_INTEGRATION_DEPLOY')
```

This is the SnowSQL .log file equivalent. Every child statement EIF triggered is visible with status, timing, and error code.

**Section 4: SMOKE TEST** - row counts post-deploy.

---

## Phase 3: DCM PLAN output

```sql
EXECUTE DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT PLAN
    USING CONFIGURATION (target => 'dev');
```

Expected first-run output (no existing objects from DCM perspective):
```
operation  object_type  object_name                              status
CREATE     SCHEMA       AMI_DEMO_DB.AMICORP                      planned
CREATE     SCHEMA       AMI_DEMO_DB.AMICOMM                      planned
CREATE     SCHEMA       AMI_DEMO_DB.FRAMEWORK                    planned
CREATE     SCHEMA       AMI_DEMO_DB.AMISTAGE                     planned
CREATE     TABLE        AMI_DEMO_DB.AMISTAGE.DIM_METER           planned
CREATE     TABLE        AMI_DEMO_DB.AMISTAGE.FACT_METER_READS    planned
CREATE     TABLE        AMI_DEMO_DB.FRAMEWORK.EMAIL_BODY_DISPLAY_CONFIG  planned
CREATE     TABLE        AMI_DEMO_DB.FRAMEWORK.DEPLOY_LOG         planned
CREATE     TABLE        AMI_DEMO_DB.FRAMEWORK.PROCESS_LOG        planned
GRANT      ...                                                   planned
```

On second run (no changes): all rows show `unchanged`. Snowflake compares declared vs current and only re-applies the diff.

After making a column change in a `dcm/definitions/*.sql` file, push, and re-PLAN:
```
ALTER      TABLE        AMI_DEMO_DB.AMISTAGE.DIM_METER           planned (column added)
```

DEPLOY then applies the planned changes.

---

## What "good" looks like in one screen

- `SHOW GIT REPOSITORIES` returns AMI_GIT_REPO
- `SHOW GIT BRANCHES` returns main with non-empty commit_hash
- Deploy last row reads `AMI demo deploy complete`
- `SHOW TABLES IN DATABASE AMI_DEMO_DB` returns 5
- Re-deploy after push shows new commit_hash, DESC TABLE has new column, no data loss
- GitHub Actions workflow has green checkmark with log artifact attached
- `EXECUTE DCM PROJECT ... PLAN` returns expected operations (Phase 3)

All present = demo works end to end.
