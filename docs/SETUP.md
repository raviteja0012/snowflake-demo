# Setup Sheet, click by click

Total time: 20–25 minutes. Order matters. Do not skip steps.

Demo account: **KEGHDAI-GVA52989** (Azure East US 2, Enterprise trial)
Demo user: **RAVITEJA0012** (ACCOUNTADMIN)
GitHub repo: **github.com/raviteja0012/snowflake-demo**

---

## Step 1, generate the GitHub fine-grained PAT (3 min)

1. Sign in to GitHub as `raviteja0012`.
2. Go to **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
3. Token name: `snowflake-demo-git-integration`
4. Resource owner: `raviteja0012`
5. Expiration: **90 days** (set a calendar reminder for day 75)
6. Repository access: **Only select repositories → `raviteja0012/snowflake-demo`**
7. Repository permissions (set both to **Read-only**):
   - **Contents: Read-only**
   - **Metadata: Read-only** (auto-selected)
   - Leave everything else as "No access"
8. Click **Generate token**, copy the `github_pat_…` string immediately. GitHub never shows it again. Paste into a password manager.

---

## Step 2, push this scaffold to the repo (2 min)

```bash
# In a local clone of github.com/raviteja0012/snowflake-demo
# Copy every file from the snowflake-demo/ output into the repo root
git add .
git commit -m "Initial AMI native git integration demo scaffold"
git push origin main
```

The repo on GitHub should now show:
- `bootstrap/01_account_setup.sql`
- `bootstrap/02_git_integration.sql`
- `deploy/deploy.sql`
- `deploy/01_grants/`, `deploy/10_framework/`, etc.
- `Snow_Config/ami_env_dev.cfg`
- `docs/SETUP.md`, `docs/EXPECTED_LOGS.md`
- `README.md`

---

## Step 3, run the account bootstrap in Snowsight (3 min)

1. Sign in to Snowsight as RAVITEJA0012, switch role to **ACCOUNTADMIN** (top-right).
2. Open a new worksheet.
3. Paste the entire contents of `bootstrap/01_account_setup.sql`.
4. Click **Run All** (Ctrl/Cmd + Shift + Enter).

Expected last results, top to bottom:

- `SHOW WAREHOUSES` returns one row, name `NONPROD_AMI_ADMIN_WH`
- `SHOW DATABASES` returns one row, name `AMI_DEMO_DB`
- `SHOW SCHEMAS` returns 9 rows: `AMICORP`, `AMICOMM`, `FRAMEWORK`, `AMIRPTS`, `AMISTAGE`, `XREF`, `AMICIAP`, `AMIINT`, plus `INFORMATION_SCHEMA`
- `SHOW ROLES` returns 6 rows: `DEV_AMI_ADMIN_ROLE`, `DEV_AMI_LOAD_ROLE`, `DEV_AMI_SELECT_ROLE`, `DEV_AMI_MLS_ROLE`, `DEV_AMI_PBI_ROLE`, `NONPROD_AMI_SUPPORT_ROLE`

If any row is missing, scroll up in the results pane for the failing statement.

---

## Step 4, run the git integration bootstrap (3 min)

1. Open `bootstrap/02_git_integration.sql`.
2. Paste the entire contents into a Snowsight worksheet, role **ACCOUNTADMIN**.
3. Click **Run All**.

The PAT is already hardcoded in the script (expires Aug 17, 2026). When you need to rotate, generate a new PAT on GitHub and run:

```sql
ALTER SECRET AMI_DEMO_DB.GIT_OPS.GITHUB_PAT_SECRET
    SET PASSWORD = 'github_pat_new_value';
ALTER GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO FETCH;
```

Expected last results:

- `SHOW SECRETS` returns one row, name `GITHUB_PAT_SECRET`, type `PASSWORD`
- `SHOW API INTEGRATIONS` returns one row, name `GITHUB_API_INTEGRATION`, enabled `TRUE`
- `SHOW GIT REPOSITORIES` returns one row, name `AMI_GIT_REPO`, origin pointing at github.com/raviteja0012/snowflake-demo.git
- `SHOW GIT BRANCHES` returns one row for `main` with a non-empty `commit_hash`
- `LIST @AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main` lists all the repo files (deploy.sql, 01_account_setup.sql, etc.)

If `ALTER GIT REPOSITORY … FETCH` errors with an auth message, the PAT is wrong or expired. Regenerate it on GitHub and update the secret with `ALTER SECRET ... SET PASSWORD = 'github_pat_new'`.

---

## Step 5, run the first deploy from the git integration (3 min)

Switch role to **DEV_AMI_ADMIN_ROLE** in Snowsight (top-right).

Open a new worksheet and paste:

```sql
USE ROLE DEV_AMI_ADMIN_ROLE;
USE WAREHOUSE NONPROD_AMI_ADMIN_WH;
USE DATABASE AMI_DEMO_DB;

-- First, dry-run to see the rendered top-level SQL
EXECUTE IMMEDIATE FROM @AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main/deploy/deploy.sql
    USING (env_db           => 'AMI_DEMO_DB',
           wh_name          => 'NONPROD_AMI_ADMIN_WH',
           rl_name          => 'DEV_AMI_ADMIN_ROLE',
           ami_mat_role     => 'DEV_AMI_LOAD_ROLE',
           ami_sel_role     => 'DEV_AMI_SELECT_ROLE',
           ami_mls_role     => 'DEV_AMI_MLS_ROLE',
           ami_pbi_role     => 'DEV_AMI_PBI_ROLE',
           ami_support_role => 'NONPROD_AMI_SUPPORT_ROLE',
           corp_sch         => 'AMICORP',
           comm_sch         => 'AMICOMM',
           frmwk_sch        => 'FRAMEWORK',
           rpts_sch         => 'AMIRPTS',
           stage_sch        => 'AMISTAGE',
           xref_sch         => 'XREF',
           ciap_sch         => 'AMICIAP',
           int_sch          => 'AMIINT')
    DRY_RUN = TRUE;
```

Expected: a single result row whose cell contains the fully rendered orchestrator SQL. Every `{{ var }}` is now a concrete value. The nested `EXECUTE IMMEDIATE FROM './01_grants/...'` calls appear as text in the rendered output (DRY_RUN doesn't recurse).

Now run for real. Same statement, drop the `DRY_RUN = TRUE` line:

```sql
EXECUTE IMMEDIATE FROM @AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main/deploy/deploy.sql
    USING (env_db           => 'AMI_DEMO_DB',
           wh_name          => 'NONPROD_AMI_ADMIN_WH',
           rl_name          => 'DEV_AMI_ADMIN_ROLE',
           ami_mat_role     => 'DEV_AMI_LOAD_ROLE',
           ami_sel_role     => 'DEV_AMI_SELECT_ROLE',
           ami_mls_role     => 'DEV_AMI_MLS_ROLE',
           ami_pbi_role     => 'DEV_AMI_PBI_ROLE',
           ami_support_role => 'NONPROD_AMI_SUPPORT_ROLE',
           corp_sch         => 'AMICORP',
           comm_sch         => 'AMICOMM',
           frmwk_sch        => 'FRAMEWORK',
           rpts_sch         => 'AMIRPTS',
           stage_sch        => 'AMISTAGE',
           xref_sch         => 'XREF',
           ciap_sch         => 'AMICIAP',
           int_sch          => 'AMIINT');
```

Expected: a single result row with columns `STATUS`, `DEPLOYED_TO`, `DEPLOYED_BY`, `DEPLOYED_ROLE`, `DEPLOYED_AT`. STATUS reads `AMI demo deploy complete`.

Runtime usually 30–60 seconds on the XSMALL warehouse.

---

## Step 6, verify the deploy created everything (2 min)

```sql
USE ROLE DEV_AMI_ADMIN_ROLE;

-- Tables
SHOW TABLES IN DATABASE AMI_DEMO_DB;
-- Expect 4 rows:
--   FRAMEWORK.EMAIL_BODY_DISPLAY_CONFIG
--   FRAMEWORK.DEPLOY_LOG
--   FRAMEWORK.PROCESS_LOG
--   AMISTAGE.DIM_METER
--   AMISTAGE.FACT_METER_READS

-- Procedure
SHOW PROCEDURES IN SCHEMA AMI_DEMO_DB.FRAMEWORK;
-- Expect 1 row: SP_LOG_DEPLOY(VARCHAR, VARCHAR)

-- Task (suspended on create, mirrors prod)
SHOW TASKS IN SCHEMA AMI_DEMO_DB.FRAMEWORK;
-- Expect 1 row: FRMWK_RETRY_TASK, state = SUSPENDED

-- Seed data
SELECT * FROM AMI_DEMO_DB.FRAMEWORK.EMAIL_BODY_DISPLAY_CONFIG ORDER BY PROCESS_NAME, EMAIL_BODY_SECTION;
-- Expect 14 rows: 7 for METER_READS_LOAD, 7 for METER_READS_RETRY

-- Smoke-test the stored procedure
CALL AMI_DEMO_DB.FRAMEWORK.SP_LOG_DEPLOY('SMOKE_TEST', 'DATA_PROCESSED');
-- Expect return value: SUCCESS|Process completed

SELECT * FROM AMI_DEMO_DB.FRAMEWORK.PROCESS_LOG ORDER BY LOG_ID DESC LIMIT 5;
-- Expect 3 rows for SMOKE_TEST (PROCESS_STARTED, DATA_PROCESSED, PROCESS_COMPLETED)
```

---

## Step 7, the round-trip demo (the actual point of the demo) (3 min)

Make a real change locally, push, re-fetch, re-deploy. The full CI/CD loop.

```bash
# In a local clone
# Edit deploy/20_dimensions/20_MeterDim_DDL_v1.0.sql
# Add a new column inside the table definition:
#     SUPPLY_VOLTAGE_NOMINAL NUMBER(8,2)  COMMENT 'Nominal supply voltage',
```

```bash
git add deploy/20_dimensions/20_MeterDim_DDL_v1.0.sql
git commit -m "Add SUPPLY_VOLTAGE_NOMINAL to DIM_METER"
git push origin main
```

Back in Snowsight, role **DEV_AMI_ADMIN_ROLE**:

```sql
-- Re-fetch picks up the new commit
ALTER GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO FETCH;
SHOW GIT BRANCHES IN AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO;
-- Verify commit_hash matches the SHA you just pushed (first 7 chars in the row)

-- Re-deploy
EXECUTE IMMEDIATE FROM @AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main/deploy/deploy.sql
    USING (env_db           => 'AMI_DEMO_DB',
           wh_name          => 'NONPROD_AMI_ADMIN_WH',
           rl_name          => 'DEV_AMI_ADMIN_ROLE',
           ami_mat_role     => 'DEV_AMI_LOAD_ROLE',
           ami_sel_role     => 'DEV_AMI_SELECT_ROLE',
           ami_mls_role     => 'DEV_AMI_MLS_ROLE',
           ami_pbi_role     => 'DEV_AMI_PBI_ROLE',
           ami_support_role => 'NONPROD_AMI_SUPPORT_ROLE',
           corp_sch         => 'AMICORP',
           comm_sch         => 'AMICOMM',
           frmwk_sch        => 'FRAMEWORK',
           rpts_sch         => 'AMIRPTS',
           stage_sch        => 'AMISTAGE',
           xref_sch         => 'XREF',
           ciap_sch         => 'AMICIAP',
           int_sch          => 'AMIINT');

-- Verify the new column landed without losing data
DESC TABLE AMI_DEMO_DB.AMISTAGE.DIM_METER;
-- Expect SUPPLY_VOLTAGE_NOMINAL in the column list

-- Confirm CREATE OR ALTER preserved any existing data
SELECT COUNT(*) FROM AMI_DEMO_DB.AMISTAGE.DIM_METER;
-- (will be 0 because no data was inserted; the point is the table wasn't recreated)
```

That is the full CI/CD cycle. Edit a file locally → push → ALTER FETCH → EXECUTE IMMEDIATE FROM → done.

---

## Troubleshooting fast-path

| Symptom                                                              | Cause                                              | Fix |
|----------------------------------------------------------------------|----------------------------------------------------|-----|
| `001501 File '<path>' not found in stage`                            | Typo, or skipped FETCH                             | Re-fetch, then `LIST @AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main` |
| `Python Interpreter Error: jinja2 ... UndefinedError: '<key>' is undefined` | Variable in template not passed in USING     | Add the key to the USING clause |
| Auth error on FETCH                                                  | PAT expired / wrong scope / not authorized for SSO | Regenerate PAT, `ALTER SECRET ... SET PASSWORD = 'github_pat_new'` |
| `Insufficient privileges to operate on schema`                       | Wrong role active                                  | `USE ROLE DEV_AMI_ADMIN_ROLE` |
| `Object 'AMISTAGE' does not exist or not authorized`                 | Forgot `USE DATABASE AMI_DEMO_DB`                  | Set the database before running the EIF call |
| `Stage 'AMI_GIT_REPO' does not exist or not authorized`              | Missing `READ ON GIT REPOSITORY` grant             | Re-run the grants block in `02_git_integration.sql` |
| FETCH returns the old commit hash                                    | Cache; pushed but FETCH didn't run                 | Always run `ALTER GIT REPOSITORY … FETCH` before deploy |
