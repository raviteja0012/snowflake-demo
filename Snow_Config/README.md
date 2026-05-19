# Snow_Config — reference only

This folder mirrors the prod AMI SnowSQL config pattern (`ami_env_*.cfg` files with
`!define VAR=VALUE` lines). It is **not consumed at runtime** by Snowflake native
git integration.

Why it's here:
- Side-by-side readability against the production AMI codebase
- Reviewers see exactly which variables map to which deploy-time values
- Phase 2 (GitHub Actions + Snowflake CLI) can read these via shell parsing

At deploy time (Phase 1), values are passed to the Jinja template through the
`USING (...)` clause of the `EXECUTE IMMEDIATE FROM` call. See the worksheet
commands in `docs/SETUP.md`.

## Mapping cheat sheet

| Prod `ami_env_dev.cfg` variable | Demo Jinja key       | Demo value             |
|---------------------------------|----------------------|------------------------|
| `DB_NAME`                       | `env_db`             | `AMI_DEMO_DB`          |
| `RL_NAME`                       | `rl_name`            | `DEV_AMI_ADMIN_ROLE`   |
| `WH_NAME`                       | `wh_name`            | `NONPROD_AMI_ADMIN_WH` |
| `AMI_MAT_ROLE`                  | `ami_mat_role`       | `DEV_AMI_LOAD_ROLE`    |
| `AMI_SEL_ROLE`                  | `ami_sel_role`       | `DEV_AMI_SELECT_ROLE`  |
| `AMI_MLS_ROLE`                  | `ami_mls_role`       | `DEV_AMI_MLS_ROLE`     |
| `AMI_PBI_ROLE`                  | `ami_pbi_role`       | `DEV_AMI_PBI_ROLE`     |
| `AMI_SUPPORT_ROLE`              | `ami_support_role`   | `NONPROD_AMI_SUPPORT_ROLE` |
| `CORP_SCH`                      | `corp_sch`           | `AMICORP`              |
| `COMM_SCH`                      | `comm_sch`           | `AMICOMM`              |
| `FRMWK_SCH`                     | `frmwk_sch`          | `FRAMEWORK`            |
| `STAGE_SCH`                     | `stage_sch`          | `AMISTAGE`             |
| `RPTS_SCH`                      | `rpts_sch`           | `AMIRPTS`              |
| `XREF_SCH`                      | `xref_sch`           | `XREF`                 |
| `CIAP_SCH`                      | `ciap_sch`           | `AMICIAP`              |
| `INT_SCH`                       | `int_sch`            | `AMIINT`               |
