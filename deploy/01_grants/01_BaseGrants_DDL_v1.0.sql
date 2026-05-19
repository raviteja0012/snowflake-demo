--!jinja
-- =====================================================================
-- 01_BaseGrants_DDL_v1.0.sql
--
-- Schema USAGE grants for the four consumer roles.
-- Loader role gets USAGE everywhere it writes. Reader gets USAGE on
-- everything it reads. Support gets USAGE on everything for incident triage.
--
-- These are idempotent. Running twice is fine, Snowflake just no-ops.
-- =====================================================================

GRANT USAGE ON SCHEMA {{ env_db }}.{{ corp_sch }}  TO ROLE {{ ami_mat_role }};
GRANT USAGE ON SCHEMA {{ env_db }}.{{ corp_sch }}  TO ROLE {{ ami_sel_role }};
GRANT USAGE ON SCHEMA {{ env_db }}.{{ corp_sch }}  TO ROLE {{ ami_support_role }};

GRANT USAGE ON SCHEMA {{ env_db }}.{{ comm_sch }}  TO ROLE {{ ami_mat_role }};
GRANT USAGE ON SCHEMA {{ env_db }}.{{ comm_sch }}  TO ROLE {{ ami_sel_role }};
GRANT USAGE ON SCHEMA {{ env_db }}.{{ comm_sch }}  TO ROLE {{ ami_support_role }};

GRANT USAGE ON SCHEMA {{ env_db }}.{{ frmwk_sch }} TO ROLE {{ ami_mat_role }};
GRANT USAGE ON SCHEMA {{ env_db }}.{{ frmwk_sch }} TO ROLE {{ ami_sel_role }};
GRANT USAGE ON SCHEMA {{ env_db }}.{{ frmwk_sch }} TO ROLE {{ ami_support_role }};

GRANT USAGE ON SCHEMA {{ env_db }}.{{ stage_sch }} TO ROLE {{ ami_mat_role }};
GRANT USAGE ON SCHEMA {{ env_db }}.{{ stage_sch }} TO ROLE {{ ami_sel_role }};
GRANT USAGE ON SCHEMA {{ env_db }}.{{ stage_sch }} TO ROLE {{ ami_support_role }};
