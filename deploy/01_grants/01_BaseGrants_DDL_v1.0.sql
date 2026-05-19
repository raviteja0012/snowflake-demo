--!jinja
---------------------------------------------------------------------
-- Script   : 01_BaseGrants_DDL_v1.0.sql
-- Purpose  : Schema USAGE grants for consumer roles
-- Version  : 1.0
-- Created  : 2026-05-19
---------------------------------------------------------------------

-- Schema USAGE for the loader, reader, and support roles
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
