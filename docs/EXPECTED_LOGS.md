# Expected outputs at each step

Use this to verify each piece worked. Exact text shifts between Snowflake releases, but the shape stays.

---

## After `bootstrap/01_account_setup.sql`

`SHOW WAREHOUSES LIKE 'NONPROD_AMI_ADMIN_WH'`:
```
name                    state      size    auto_suspend  auto_resume
NONPROD_AMI_ADMIN_WH    SUSPENDED  X-Small  60            true
```

`SHOW SCHEMAS IN DATABASE AMI_DEMO_DB`:
```
name                  database_name   owner
AMICORP               AMI_DEMO_DB     DEV_AMI_ADMIN_ROLE
AMICOMM               AMI_DEMO_DB     DEV_AMI_ADMIN_ROLE
FRAMEWORK             AMI_DEMO_DB     DEV_AMI_ADMIN_ROLE
AMIRPTS               AMI_DEMO_DB     DEV_AMI_ADMIN_ROLE
AMISTAGE              AMI_DEMO_DB     DEV_AMI_ADMIN_ROLE
XREF                  AMI_DEMO_DB     DEV_AMI_ADMIN_ROLE
AMICIAP               AMI_DEMO_DB     DEV_AMI_ADMIN_ROLE
AMIINT                AMI_DEMO_DB     DEV_AMI_ADMIN_ROLE
INFORMATION_SCHEMA    AMI_DEMO_DB     (system)
```

(PUBLIC is dropped by the bootstrap.)

`SHOW ROLES;` then filter via `RESULT_SCAN`:
```sql
SHOW ROLES;
SELECT "name", "owner", "comment"
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
 WHERE "name" LIKE 'DEV_AMI_%' OR "name" LIKE 'NONPROD_AMI_%'
 ORDER BY "name";
```
Result:
```
name                          owner          granted_to_users
DEV_AMI_ADMIN_ROLE            USERADMIN      1
DEV_AMI_LOAD_ROLE             USERADMIN      0
DEV_AMI_SELECT_ROLE           USERADMIN      0
DEV_AMI_MLS_ROLE              USERADMIN      0
DEV_AMI_PBI_ROLE              USERADMIN      0
NONPROD_AMI_SUPPORT_ROLE      USERADMIN      1
```

---

## After `bootstrap/02_git_integration.sql`

`SHOW SECRETS IN SCHEMA AMI_DEMO_DB.GIT_OPS`:
```
name                  schema_name    secret_type
GITHUB_PAT_SECRET     GIT_OPS        PASSWORD
```

`SHOW API INTEGRATIONS LIKE 'GITHUB_API_INTEGRATION'`:
```
name                       type      enabled   api_type
GITHUB_API_INTEGRATION     EXTERNAL_API   true   GIT_HTTPS_API
```

`SHOW GIT REPOSITORIES IN SCHEMA AMI_DEMO_DB.GIT_OPS`:
```
name              schema_name   origin                                                      api_integration
AMI_GIT_REPO      GIT_OPS       https://github.com/raviteja0012/snowflake-demo.git          GITHUB_API_INTEGRATION
```

`SHOW GIT BRANCHES IN AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO`:
```
name      path                                  checkouts   commit_hash                            author                  message
main      /branches/main                        (count)     a1b2c3d4e5f6789...                     Raviteja Potluru        Initial AMI native git integration demo scaffold
```

`LIST @AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main`:
```
name                                                                                  size   md5         last_modified
ami_git_repo/branches/main/README.md                                                  …
ami_git_repo/branches/main/bootstrap/01_account_setup.sql                             …
ami_git_repo/branches/main/bootstrap/02_git_integration.sql                           …
ami_git_repo/branches/main/deploy/deploy.sql                                          …
ami_git_repo/branches/main/deploy/01_grants/01_BaseGrants_DDL_v1.0.sql                …
ami_git_repo/branches/main/deploy/10_framework/10_FrameworkConfig_DDL_v1.0.sql        …
ami_git_repo/branches/main/deploy/10_framework/11_FrameworkLog_DDL_v1.0.sql           …
ami_git_repo/branches/main/deploy/20_dimensions/20_MeterDim_DDL_v1.0.sql              …
ami_git_repo/branches/main/deploy/30_facts/30_MeterReadsFact_DDL_v1.0.sql             …
ami_git_repo/branches/main/deploy/40_procedures/40_LogDeploySP_DDL_v1.0.sql           …
ami_git_repo/branches/main/deploy/50_tasks/50_RetryTask_DDL_v1.0.sql                  …
ami_git_repo/branches/main/deploy/60_dml/60_FrameworkEmailSeed_DML_v1.0.sql           …
ami_git_repo/branches/main/Snow_Config/README.md                                      …
ami_git_repo/branches/main/Snow_Config/ami_env_dev.cfg                                …
ami_git_repo/branches/main/docs/SETUP.md                                              …
ami_git_repo/branches/main/docs/EXPECTED_LOGS.md                                      …
```

---

## After the DRY_RUN deploy

A single column / single row result. The cell holds the fully-rendered deploy.sql with every `{{ var }}` substituted. Snippet of what you'll see:

```sql
USE ROLE      DEV_AMI_ADMIN_ROLE;
USE WAREHOUSE NONPROD_AMI_ADMIN_WH;
USE DATABASE  AMI_DEMO_DB;

EXECUTE IMMEDIATE FROM './01_grants/01_BaseGrants_DDL_v1.0.sql'
    USING (env_db           => 'AMI_DEMO_DB',
           ami_mat_role     => 'DEV_AMI_LOAD_ROLE',
           ami_sel_role     => 'DEV_AMI_SELECT_ROLE',
           ...
...
```

DRY_RUN does **not** recurse into nested EXECUTE IMMEDIATE FROM calls. To preview a child, target it directly with DRY_RUN.

---

## After the real deploy

Result row:
```
STATUS                            DEPLOYED_TO     DEPLOYED_BY      DEPLOYED_ROLE          DEPLOYED_AT
AMI demo deploy complete          AMI_DEMO_DB     RAVITEJA0012     DEV_AMI_ADMIN_ROLE     2026-05-19 14:23:11.123 -0700
```

Verify counts:

```
SHOW TABLES IN DATABASE AMI_DEMO_DB     → 5 rows (CONFIG, DEPLOY_LOG, PROCESS_LOG, DIM_METER, FACT_METER_READS)
SHOW PROCEDURES IN SCHEMA FRAMEWORK     → 1 row  (SP_LOG_DEPLOY)
SHOW TASKS IN SCHEMA FRAMEWORK          → 1 row  (FRMWK_RETRY_TASK, state SUSPENDED)
SELECT COUNT(*) FROM FRAMEWORK.EMAIL_BODY_DISPLAY_CONFIG  → 14
```

---

## After `CALL SP_LOG_DEPLOY('SMOKE_TEST', 'DATA_PROCESSED')`

Return value:
```
SUCCESS|Process completed
```

`SELECT * FROM AMI_DEMO_DB.FRAMEWORK.PROCESS_LOG ORDER BY LOG_ID DESC LIMIT 5`:
```
LOG_ID   PROCESS_ID                  PROCESS_NAME   COMPONENT             PROC_STATUS   STATUS_DESC
3        <session>.<n>               SMOKE_TEST     PROCESS_COMPLETED     SUCCESS       Process completed
2        <session>.<n>               SMOKE_TEST     DATA_PROCESSED        SUCCESS       Component reached: DATA_PROCESSED
1        <session>.<n>               SMOKE_TEST     PROCESS_STARTED       SUCCESS       Process started for SMOKE_TEST
```

---

## After Step 7 (round-trip)

`SHOW GIT BRANCHES IN AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO` after the FETCH shows the new commit_hash matching what `git log -1 --format=%H` returns locally.

`DESC TABLE AMI_DEMO_DB.AMISTAGE.DIM_METER` includes the new `SUPPLY_VOLTAGE_NOMINAL` column.

`SHOW TABLES IN SCHEMA AMI_DEMO_DB.AMISTAGE` shows `created_on` for `DIM_METER` is the original create timestamp (CREATE OR ALTER preserved the table; not a recreate).

---

## What "good" looks like in one screen

- Snowsight: `SHOW GIT REPOSITORIES` returns `AMI_GIT_REPO`
- Snowsight: `SHOW GIT BRANCHES` returns `main` with a non-empty `commit_hash`
- Snowsight: the deploy's last result row reads `AMI demo deploy complete`
- Snowsight: `SHOW TABLES IN DATABASE AMI_DEMO_DB` returns 5 rows
- Snowsight: a re-deploy after `git push` shows the new commit_hash and DESC TABLE shows the new column without data loss

If all five are present, the demo works end to end.
