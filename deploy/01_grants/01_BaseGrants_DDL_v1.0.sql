--!jinja
-- 01_BaseGrants_DDL_v1.0.sql
-- Schema USAGE for the four consumer roles. Idempotent (Snowflake no-ops if already granted).

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
