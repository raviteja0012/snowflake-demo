# Phase 3: DCM Projects

Declarative deploys. Plan-then-apply, like Terraform for Snowflake objects. Open Preview as of March 20, 2026, available on AWS, Azure, GCP.

What you describe is the desired end state. Snowflake figures out the diff and applies only what changed. You don't write CREATE OR ALTER scripts. You write DEFINE statements and the engine handles CREATE/ALTER/DROP.

---

## How Phase 3 differs from Phase 2

| Aspect | Phase 2 (EIF) | Phase 3 (DCM) |
|---|---|---|
| Style | Imperative. CREATE OR ALTER per object | Declarative. DEFINE the desired state |
| Drift detection | None | Built-in. PLAN shows the diff before DEPLOY |
| Drop on remove | Manual. Need explicit DROP | Automatic. Remove a DEFINE -> object dropped next deploy |
| History | Custom DEPLOY_LOG table | Native. SHOW DEPLOYMENTS IN DCM PROJECT |
| Audit artifact | GitHub Actions log | Immutable artifact stored in Snowflake per deploy |
| Object scope | Anything Snowflake supports | Only DCM-supported objects (see below) |
| File path | Any .sql files | Strict structure: `manifest.yml` + `sources/definitions/*.sql` |
| Allowed statements | Any SQL | DEFINE, GRANT, ATTACH only |
| Procedures, DML | Yes | No. Not supported |

Both can coexist. That's the **hybrid pattern**.

---

## Hybrid: what DCM owns vs what Phase 2 owns

In this demo, DCM and Phase 2 split responsibilities:

| Layer | Tool | Why |
|---|---|---|
| Database `AMI_DEMO_DB` | Phase 1 bootstrap | DCM cannot manage its own parent database |
| Schema `GIT_OPS` | Phase 1 bootstrap | Holds the DCM project + git integration. Stays out of DCM. |
| Schemas (AMICORP, AMICOMM, FRAMEWORK, AMISTAGE) | DCM | Declarative. |
| Tables (DIM_METER, FACT_METER_READS, framework tables) | DCM | DEFINE TABLE supported |
| Grants on tables | DCM | GRANT supported, dropped automatically on revoke |
| Procedure `SP_LOG_DEPLOY` | Phase 2 EIF | DCM does NOT support procedures with body |
| Task `FRMWK_RETRY_TASK` | Phase 2 EIF | Could move to DCM (DEFINE TASK supported) but starts SUSPENDED, simpler to keep in EIF for now |
| Sample DML (MERGE INTO meter rows) | Phase 2 EIF | DML not allowed in DEFINE files |
| Email config seed DML | Phase 2 EIF | Same. DCM only handles DDL. |
| Git repo + secret + API integration | Phase 1 bootstrap | One-time |
| DCM project object itself | Phase 1 bootstrap (script 04) | One-time CREATE DCM PROJECT |

That is realistic. DCM gives you safe table/schema/grant management for everything below its parent database. Phase 2 handles everything DCM can't (procedures, DML, tasks) and Phase 1 handles the bootstrap (database, the DCM project's parent schema).

**Hard rule from Snowflake:** A DCM project cannot define its own parent database or parent schema. Our project lives at `AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT`, so DEFINE DATABASE AMI_DEMO_DB and DEFINE SCHEMA AMI_DEMO_DB.GIT_OPS are both forbidden. Everything else under AMI_DEMO_DB is fair game.

---

## DCM-supported object types (preview as of 2026-03-20)

DEFINE works for: database, schema, table, dynamic table, view, secure view, internal stage, warehouse, role, database role, data metric function, task, SQL function (SQL language only), tag, authentication policy.

Plus GRANT (for any grantable privilege) and ATTACH (for data metric expectations).

NOT supported: procedures, JS/Python/Java functions, external functions, pipes, streams, external tables, sequences, file formats, network policies, masking/row-access policies (on column definitions), application roles.

References to other objects must use fully qualified names. All DEFINE statements must use `database.schema.object_name`.

---

## Folder structure (mandatory)

DCM expects this exact layout:

```
dcm/
├── manifest.yml                          <- required, at root
├── sources/
│   └── definitions/                      <- required, definition files go here
│       ├── 00_database_and_schemas.sql
│       ├── 10_framework_tables.sql
│       ├── 20_dim_meter.sql
│       └── 30_fact_meter_reads.sql
└── out/                                  <- auto-generated, gitignored
```

File names and nesting under `definitions/` and `macros/` are flexible. Anything outside `sources/` is ignored by DCM.

`out/` holds local PLAN/DEPLOY output when running from CLI. Must be in .gitignore.

---

## How CREATE DCM PROJECT actually works

DCM project is a **schema-level object** in Snowflake. Looks like this:

```sql
CREATE [OR REPLACE] DCM PROJECT [IF NOT EXISTS] <name>
    [LOG_LEVEL = { DEBUG | INFO | WARN | ERROR }]
    [COMMENT = '<string>'];
```

That's it. No FROM, no LOCATION, no API_INTEGRATION at CREATE time. The project object is just an engine. It doesn't hold the SQL files.

Files are passed at EXECUTE time via `FROM '<path>'`. Path can be:
- `@<git_repo_stage>/branches/main/dcm/` (git repo clone in Snowflake, like Phase 2)
- `@<my_stage>/path/` (regular stage)
- `snow://workspace/...` (Snowsight Workspace)
- local path via Snowflake CLI

Role that creates the project gets OWNERSHIP automatically. EXECUTE requires OWNERSHIP. So the deploy role must own the project.

---

## EXECUTE DCM PROJECT syntax (canonical)

```sql
EXECUTE DCM PROJECT <name>
    PLAN
    [USING [CONFIGURATION <config_name>] [(<expr>, [<expr>, ...])]]
    FROM '<source_files_path>';

EXECUTE DCM PROJECT <name>
    DEPLOY [AS "<deployment_alias>"]
    [USING [CONFIGURATION <config_name>] [(<expr>, [<expr>, ...])]]
    FROM '<source_files_path>';
```

Other variants:
- `EXECUTE DCM PROJECT <name> REFRESH ALL`: refresh dynamic tables
- `EXECUTE DCM PROJECT <name> TEST ALL`: run data quality expectations
- `EXECUTE DCM PROJECT <name> PREVIEW <table>`: sample data from rendered definition
- `EXECUTE DCM PROJECT <name> PURGE`: drop everything DCM manages

`FROM '<path>'` is the folder containing `manifest.yml`, NOT the file itself.

PLAN output is JSON with a `changeset` array showing CREATE/ALTER/DROP operations per object. Same shape as DEPLOY output. Difference: PLAN doesn't actually change anything. Same JSON schema, no side effects.

---

## manifest.yml (required structure)

```yaml
manifest_version: 2
type: DCM_PROJECT
default_target: <target_name>

targets:
  <target_name>:
    account_identifier: <ORG-ACCOUNT>
    project_name: <db.schema.project_object_name>
    project_owner: <role with OWNERSHIP on project>
    templating_config: <name from templating.configurations>

templating:
  defaults:
    <var>: <value>
  configurations:
    <CONFIG_NAME>:
      <var>: <value>
```

`templating_config` must match a key under `templating.configurations`. Variables resolve in order: global defaults < configuration < runtime `USING (...)` overrides.

This demo uses `default_target: dev`, points at our trial account, and currently has only the DEV configuration. TEST and PROD are stubbed in comments.

---

## Setup, click by click

### Prereq: Phase 1 + Phase 2 done

DCM piggybacks on the Phase 1 git integration. Repo, branches, API integration, secret, role with READ on git repo. If `LIST @AMI_GIT_REPO/branches/main` returns files, you're ready.

### Step 1. Push the Phase 3 files

```bash
git add dcm/ bootstrap/04_dcm_project_bootstrap.sql .github/workflows/dcm-deploy.yml docs/PHASE_3_DCM.md
git commit -m "Phase 3: DCM Projects scaffold"
git push origin main
```

### Step 2. Bootstrap the DCM project object

Run `bootstrap/04_dcm_project_bootstrap.sql` as ACCOUNTADMIN in Snowsight. It:

1. Grants `CREATE DCM PROJECT ON SCHEMA AMI_DEMO_DB.GIT_OPS` to DEV_AMI_ADMIN_ROLE.
2. Switches to DEV_AMI_ADMIN_ROLE and creates `AMI_DCM_PROJECT` (so that role owns it).
3. Grants READ to NONPROD_AMI_SUPPORT_ROLE.
4. FETCHes the git repo (so DCM sees the latest manifest).
5. Runs the first PLAN.

Expected PLAN output: JSON `changeset` array with CREATE operations for **4 schemas, 5 tables, and grants**. All `"type": "CREATE"` because nothing exists in DCM-managed state yet. The database `AMI_DEMO_DB` is NOT in the changeset (created by Phase 1 bootstrap, outside DCM).

If PLAN looks right, uncomment the DEPLOY at the bottom of the script and run it. Or skip directly to Step 3.

### Step 3. Deploy via GitHub Actions

Already automatic. After step 1 (push to main with `dcm/**` changes), `.github/workflows/dcm-deploy.yml` triggers:

- PR to main with `dcm/**` changes -> PLAN only, log uploaded as artifact
- Push to main with `dcm/**` changes -> PLAN + DEPLOY (alias = `gha_run_<runid>_<sha7>`)
- Manual `workflow_dispatch` with `plan_only=true` -> PLAN only

The workflow uses the same JWT keypair as Phase 2 (3 secrets: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PRIVATE_KEY). Already set in Phase 2.

### Step 4. Verify

Back in Snowsight as DEV_AMI_ADMIN_ROLE:

```sql
SHOW DEPLOYMENTS IN DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT;
-- Latest row should be your alias, status SUCCESS

SHOW ENTITIES IN DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT;
-- Should list: 4 schemas (AMICORP, AMICOMM, FRAMEWORK, AMISTAGE) + 5 tables
-- (matches what DCM is currently managing; database AMI_DEMO_DB is NOT here)

SHOW GRANTS IN DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT;
-- Lists every grant DCM is managing

-- Existing data from Phase 2 should still be there
SELECT COUNT(*) FROM AMI_DEMO_DB.AMISTAGE.DIM_METER;          -- 8
SELECT COUNT(*) FROM AMI_DEMO_DB.AMISTAGE.FACT_METER_READS;   -- 24
```

CREATE OR ALTER semantics for DEFINE TABLE means data is preserved. DCM only added column metadata where needed.

---

## Round-trip demo (full Phase 3 loop)

Make a real schema change, push, watch DCM compute the diff, apply just the diff.

```bash
# Edit dcm/sources/definitions/20_dim_meter.sql
# Add a new column at end of column list, before the CONSTRAINT:
#     METER_FIRMWARE_VERSION VARCHAR(20),

git add dcm/sources/definitions/20_dim_meter.sql
git commit -m "Add METER_FIRMWARE_VERSION to DIM_METER"
git push origin main
```

GitHub Actions runs. In the workflow log, the PLAN step shows:

```json
{
  "changeset": [
    {
      "type": "ALTER",
      "object_id": {
        "domain": "TABLE",
        "name": "DIM_METER",
        "fqn": "AMI_DEMO_DB.AMISTAGE.DIM_METER"
      },
      "changes": [
        {
          "kind": "collection",
          "collection_name": "columns",
          "changes": [
            {"kind": "added", "item_id": "METER_FIRMWARE_VERSION",
             "changes": [{"kind": "set", "attribute_name": "data_type", "value": "VARCHAR(20)"}]}
          ]
        }
      ]
    }
  ]
}
```

Only the diff. Not a full recreate. DEPLOY applies the ALTER.

```sql
-- Verify in Snowsight
DESC TABLE AMI_DEMO_DB.AMISTAGE.DIM_METER;
-- METER_FIRMWARE_VERSION now in column list

SELECT COUNT(*) FROM AMI_DEMO_DB.AMISTAGE.DIM_METER;
-- Still 8 rows, data preserved
```

---

## Snowsight UI alternative (no SQL needed for PLAN/DEPLOY)

If team prefers UI for day-to-day PLAN/DEPLOY:

1. Snowsight left nav -> Projects -> Workspaces.
2. Top-left workspace selector -> `+ Workspace` -> `From Git repository`.
3. Connect to `github.com/raviteja0012/snowflake-demo`, pick branch `main`.
4. Snowflake clones the repo files into the workspace editor.
5. In the file tree on the left, click into the `dcm/` folder (the one with `manifest.yml`).
6. Top toolbar shows DCM controls because `manifest.yml` is detected. Target dropdown (DEV) plus `PLAN` and `DEPLOY` buttons appear.
7. Click PLAN. The plan_result.json renders below the workspace.
8. If happy, click DEPLOY. Optionally enter a deployment alias when prompted.
9. From the database catalog, navigate to `AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT`. The `Deployments` tab shows every deploy with alias, status, and downloadable artifact bundle.

UI uses the SAME `CREATE DCM PROJECT` object underneath. Bootstrap/04 still has to run once (as ACCOUNTADMIN) to grant `CREATE DCM PROJECT` and create the project object itself. The UI only handles PLAN/DEPLOY, not initial object creation.

Workspaces also support direct `EXECUTE DCM PROJECT ... FROM 'snow://workspace/...'` SQL if you want to mix UI editing with manual SQL execution.

---

## Common errors and fixes

| Error | Cause | Fix |
|---|---|---|
| `Object 'AMI_DCM_PROJECT' does not exist` | Forgot bootstrap/04 | Run script 04 as ACCOUNTADMIN first |
| `Project cannot manage its parent database 'AMI_DEMO_DB'` | DEFINE DATABASE in a project that lives inside that database | Remove the DEFINE DATABASE statement. Database creation is bootstrap, not DCM |
| `syntax error ... unexpected ''alias_name''` on DEPLOY | Single quotes around `DEPLOY AS '<alias>'` | Alias is an IDENTIFIER, not a string literal. Use `DEPLOY AS "<alias>"` (double quotes) or no quotes |
| `Manifest file not found at path` | FROM points to wrong folder | Path must be the directory containing `manifest.yml`, ends with `/` |
| `Target 'dev' references templating_config 'DEV' which is not defined` | manifest.yml mismatch | `templating_config` value must match a key under `templating.configurations` |
| `Statement 'INSERT INTO ...' is not supported in DCM project definition files` | DML in definition file | Move DML to Phase 2 EIF. Definition files only allow DEFINE, GRANT, ATTACH |
| `Object 'X' is already managed by another DCM project` | Two DCM projects fighting over the same object | Either drop one project or rename objects. Two projects cannot share managed objects |
| `Insufficient privileges to execute DCM project` | Role doesn't own the project | EXECUTE requires OWNERSHIP on the project, not just READ |
| PLAN shows DROP for objects you didn't change | Removed a DEFINE statement | DCM treats missing DEFINE as "should not exist". Restore the DEFINE or accept the drop |
| `unknown variable 'X' in template` | manifest didn't declare it | Add to manifest.yml `templating.defaults` or `configurations.<NAME>` |
| Workflow says PLAN succeeded but DEPLOY fails on grant | Project owner role lacks privilege on managed object | DCM project owner needs all privileges to create/alter/drop managed objects. Re-check grants in bootstrap/01 |

---

## Limitations to know before scaling up

1. **Up to 20,000 entities, max 10 MB total** rendered definitions per project. For larger workloads split into multiple DCM projects.
2. **No rename support** for table, schema, database, view. Rename = DROP + CREATE = data loss. Plan migrations carefully.
3. **No column reorder** for tables or views. Always append new columns at the end.
4. **Dynamic table body changes** trigger full refresh. Plan the refresh cost.
5. **Tasks start SUSPENDED**. DCM cannot resume them. Manual `ALTER TASK ... RESUME` needed post-deploy.
6. **Procedures, JS/Python/Java functions, pipes, streams** are NOT supported. Keep in Phase 2 EIF.
7. **Open Preview**. The output JSON schema can still change. Don't write production-critical parsers against the changeset format yet.

---

## Migration path: Phase 2 -> Phase 3

For an existing object that Phase 2 created with `CREATE OR ALTER`, moving it under DCM is a one-time operation:

1. Add the DEFINE statement to `dcm/sources/definitions/`.
2. Remove the matching `CREATE OR ALTER` from `deploy/**`.
3. Push and let `dcm-deploy.yml` PLAN. Output should show ALTER or no-op (DCM matches existing object).
4. DEPLOY. Object is now DCM-managed.
5. From now on, edits to that object go through the DCM file, not the Phase 2 deploy.

Important: once DCM manages an object, do NOT keep a CREATE OR ALTER in Phase 2 for it. Both fighting over the same object = drift = pain. One owner per object.

---

## What's next for this demo

- [ ] Run bootstrap/04 against the real account
- [ ] Push Phase 3 to main, watch GitHub Actions DCM workflow turn green
- [ ] Verify SHOW DEPLOYMENTS returns the first row
- [ ] Demo the round-trip (add a column, push, see ALTER in the PLAN JSON)
- [ ] Add TEST account configuration to manifest.yml when ready
- [ ] Consider moving FRMWK_RETRY_TASK to DEFINE TASK (currently Phase 2)
- [ ] Once stable, add a `dcm-purge.yml` manual workflow for tearing down a dev env (uses EXECUTE DCM PROJECT PURGE)
