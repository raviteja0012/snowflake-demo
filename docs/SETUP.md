# Setup guide, click by click

Total time: 20-25 min. Order matters, don't skip.

Account: **KEGHDAI-GVA52989** (Azure East US 2, Enterprise trial)
User: **RAVITEJA0012** (ACCOUNTADMIN)
Repo: **github.com/raviteja0012/snowflake-demo**

---

## Step 1. Generate GitHub fine-grained PAT (3 min)

1. Sign in to GitHub as `raviteja0012`.
2. Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token.
3. Token name: `snowflake-demo-git-integration`
4. Resource owner: `raviteja0012`
5. Expiration: **90 days** (calendar reminder for day 75)
6. Repository access: **Only select repositories → `raviteja0012/snowflake-demo`**
7. Repository permissions (both **Read-only**):
   - Contents: Read-only
   - Metadata: Read-only (auto-selected)
   - Everything else: No access
8. Generate token. Copy the `github_pat_…` string. GitHub never shows it again. Paste in password manager.

---

## Step 2. Push scaffold to repo (2 min)

```bash
# In local clone of github.com/raviteja0012/snowflake-demo
git add .
git commit -m "Initial AMI native git integration demo scaffold"
git push origin main
```

Repo on GitHub should now have bootstrap/, deploy/, dcm/, .github/workflows/, Snow_Config/, docs/, README.md.

---

## Step 3. Account bootstrap in Snowsight (3 min)

1. Sign in as RAVITEJA0012, switch role to **ACCOUNTADMIN** (top-right).
2. New worksheet.
3. Paste `bootstrap/01_account_setup.sql`.
4. Run All.

Expected last results:
- `SHOW WAREHOUSES` → 1 row, NONPROD_AMI_ADMIN_WH
- `SHOW DATABASES` → 1 row, AMI_DEMO_DB
- `SHOW SCHEMAS` → 9 rows (8 AMI schemas + INFORMATION_SCHEMA)
- `SHOW ROLES` filter → 6 AMI roles

---

## Step 4. Git integration bootstrap (3 min)

1. Open `bootstrap/02_git_integration.sql`.
2. Paste in Snowsight worksheet, role **ACCOUNTADMIN**.
3. Run All.

PAT is hardcoded in script (expires Aug 17, 2026). When you rotate:
```sql
ALTER SECRET AMI_DEMO_DB.GIT_OPS.GITHUB_PAT_SECRET SET PASSWORD = 'github_pat_new';
ALTER GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO FETCH;
```

Expected:
- `SHOW SECRETS` → GITHUB_PAT_SECRET, type PASSWORD
- `SHOW API INTEGRATIONS` → GITHUB_API_INTEGRATION, enabled TRUE
- `SHOW GIT REPOSITORIES` → AMI_GIT_REPO
- `SHOW GIT BRANCHES` → main with non-empty commit_hash
- `LIST @AMI_GIT_REPO/branches/main` lists all repo files

If FETCH errors with auth message: PAT wrong or expired. Regenerate and update secret.

---

## Step 5. First deploy from git integration (3 min)

Switch role to **DEV_AMI_ADMIN_ROLE**.

```sql
USE ROLE DEV_AMI_ADMIN_ROLE;
USE WAREHOUSE NONPROD_AMI_ADMIN_WH;
USE DATABASE AMI_DEMO_DB;

-- Dry-run first to see rendered top-level SQL
EXECUTE IMMEDIATE FROM @AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main/deploy/deploy.sql
    USING (env_db => 'AMI_DEMO_DB', wh_name => 'NONPROD_AMI_ADMIN_WH',
           rl_name => 'DEV_AMI_ADMIN_ROLE',
           ami_mat_role => 'DEV_AMI_LOAD_ROLE',
           ami_sel_role => 'DEV_AMI_SELECT_ROLE',
           ami_mls_role => 'DEV_AMI_MLS_ROLE',
           ami_pbi_role => 'DEV_AMI_PBI_ROLE',
           ami_support_role => 'NONPROD_AMI_SUPPORT_ROLE',
           corp_sch => 'AMICORP', comm_sch => 'AMICOMM',
           frmwk_sch => 'FRAMEWORK', rpts_sch => 'AMIRPTS',
           stage_sch => 'AMISTAGE', xref_sch => 'XREF',
           ciap_sch => 'AMICIAP', int_sch => 'AMIINT')
    DRY_RUN = TRUE;
```

Result: one cell containing fully rendered deploy.sql. Every `{{ var }}` is a real value. Nested EIF calls show as text in the rendered output. DRY_RUN doesn't recurse.

Now run for real. Same statement, drop `DRY_RUN = TRUE`.

Result: row with STATUS = 'AMI demo deploy complete', DEPLOY_ID, COMMIT_HASH, etc. Takes 30-60 sec on XSMALL.

---

## Step 6. Verify (2 min)

```sql
USE ROLE DEV_AMI_ADMIN_ROLE;

SHOW TABLES IN DATABASE AMI_DEMO_DB;
-- Expect 5: EMAIL_BODY_DISPLAY_CONFIG, DEPLOY_LOG, PROCESS_LOG, DIM_METER, FACT_METER_READS

SHOW PROCEDURES IN SCHEMA AMI_DEMO_DB.FRAMEWORK;
-- Expect 1: SP_LOG_DEPLOY(VARCHAR, VARCHAR)

SHOW TASKS IN SCHEMA AMI_DEMO_DB.FRAMEWORK;
-- Expect 1: FRMWK_RETRY_TASK, state SUSPENDED

SELECT COUNT(*) FROM AMI_DEMO_DB.FRAMEWORK.EMAIL_BODY_DISPLAY_CONFIG;
-- Expect 14

CALL AMI_DEMO_DB.FRAMEWORK.SP_LOG_DEPLOY('SMOKE_TEST', 'DATA_PROCESSED');
-- Expect: SUCCESS|Process completed

SELECT COUNT(*) FROM AMI_DEMO_DB.AMISTAGE.DIM_METER;         -- 8
SELECT COUNT(*) FROM AMI_DEMO_DB.AMISTAGE.FACT_METER_READS;  -- 24

-- The interesting one: join and aggregate
SELECT m.SERVICE_POINT_ID, m.METER_TYPE_CD, COUNT(*) AS reads,
       ROUND(AVG(r.MEASUREMENT_QUANTITY), 2) AS avg_reading
  FROM AMI_DEMO_DB.AMISTAGE.FACT_METER_READS r
  JOIN AMI_DEMO_DB.AMISTAGE.DIM_METER m USING (METER_KEY)
 GROUP BY 1, 2 ORDER BY 1, 2;

-- Find the SUSPECT read (the DQ flag example)
SELECT m.METER_SERIAL_NBR, r.READING_QUALITY_CODE, r.MEASUREMENT_QUANTITY
  FROM AMI_DEMO_DB.AMISTAGE.FACT_METER_READS r
  JOIN AMI_DEMO_DB.AMISTAGE.DIM_METER m USING (METER_KEY)
 WHERE r.READING_QUALITY_CODE = 'SUSPECT';
-- Expect 1 row: MTR-1005, 0.0
```

---

## Step 7. Round-trip demo (the actual point) (3 min)

Make a real change locally, push, re-fetch, re-deploy. Full CI/CD loop.

```bash
# Edit deploy/20_dimensions/20_MeterDim_DDL_v1.0.sql
# Add a new column at end of column list:
#     SUPPLY_VOLTAGE_NOMINAL NUMBER(8,2)  COMMENT 'Nominal supply voltage',

git add deploy/20_dimensions/20_MeterDim_DDL_v1.0.sql
git commit -m "Add SUPPLY_VOLTAGE_NOMINAL to DIM_METER"
git push origin main
```

Back in Snowsight, role **DEV_AMI_ADMIN_ROLE**:

```sql
-- Re-fetch picks up new commit
ALTER GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO FETCH;
SHOW GIT BRANCHES IN AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO;
-- commit_hash should match the SHA you pushed

-- Re-deploy (same EXECUTE IMMEDIATE FROM as Step 5)

-- Verify new column landed
DESC TABLE AMI_DEMO_DB.AMISTAGE.DIM_METER;
-- SUPPLY_VOLTAGE_NOMINAL in column list

-- CREATE OR ALTER preserved existing data
SELECT COUNT(*) FROM AMI_DEMO_DB.AMISTAGE.DIM_METER;
```

That's the full CI/CD cycle. Edit → push → ALTER FETCH → EXECUTE IMMEDIATE FROM → done.

---

## Step 8 (Phase 2). GitHub Actions auto-deploy

Done already. See `.github/workflows/deploy.yml`. Set 3 GitHub Secrets:
- `SNOWFLAKE_ACCOUNT` = `KEGHDAI-GVA52989`
- `SNOWFLAKE_USER` = `RAVITEJA0012`
- `SNOWFLAKE_PRIVATE_KEY` = contents of `~/.snowflake-demo-ci/rsa_key.p8`

Every push to main with changes to `deploy/**`, `bootstrap/**`, or workflow file → auto-deploy. Log uploaded as artifact, 30-day retention.

For verbose audit: trigger `deploy-verbose.yml` manually. Captures source code AND per-statement QUERY_HISTORY. 60-day retention.

---

## Step 9 (Phase 3). DCM Projects

See `docs/PHASE_3_DCM.md`.

Short version:
1. Run `bootstrap/04_dcm_project_bootstrap.sql` as ACCOUNTADMIN. Creates DCM project object.
2. Edit files under `dcm/sources/definitions/`. Push to main.
3. PR to main → `dcm-deploy.yml` runs PLAN (preview only).
4. Push to main → PLAN then DEPLOY.

Manual run from Snowsight:
```sql
USE ROLE DEV_AMI_ADMIN_ROLE;
USE SECONDARY ROLES NONE;

ALTER GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO FETCH;

EXECUTE DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT PLAN
    USING CONFIGURATION DEV
FROM '@AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main/dcm/';

-- After reviewing the PLAN JSON, deploy:
EXECUTE DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT DEPLOY AS 'first_deploy'
    USING CONFIGURATION DEV
FROM '@AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main/dcm/';
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `001501 File '<path>' not found in stage` | Typo or skipped FETCH | `LIST @AMI_GIT_REPO/branches/main`, re-fetch |
| `Jinja UndefinedError: '<key>' is undefined` | Var not passed in USING | Add to USING clause |
| Auth error on FETCH | PAT expired or wrong scope | Regenerate PAT, update secret |
| `Insufficient privileges to operate on schema` | Wrong role active | `USE ROLE DEV_AMI_ADMIN_ROLE` |
| `Object 'AMISTAGE' does not exist` | Forgot USE DATABASE | Set DB before EIF |
| `Stage 'AMI_GIT_REPO' does not exist` | Missing READ grant | Re-run grants in 02_git_integration.sql |
| FETCH returns old commit hash | Cache, pushed but FETCH skipped | Always FETCH before deploy |
| GitHub Action: "Connection default not configured" | Missing `-x` flag on `snow sql` | Add `-x` to every `snow sql` call |
| GitHub Action: snowflake-cli-action 404 | Wrong path | `snowflakedb/snowflake-cli-action@v2.0` |
| GitHub Action: `cli-version: latest` fails | uv can't parse "latest" | Remove the `with: cli-version` block |
