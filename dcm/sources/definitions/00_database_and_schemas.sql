-- 00_database_and_schemas.sql
-- DCM-managed schemas for AMI demo.
-- Order does not matter inside DCM. Snowflake sorts internally.
--
-- IMPORTANT: NO DEFINE DATABASE here.
-- A DCM project cannot manage the database it lives in.
-- AMI_DEMO_DB is created by Phase 1 bootstrap (script 01) and stays outside DCM.

DEFINE SCHEMA {{ env_db }}.{{ corp_sch }}
    COMMENT = 'Corporate reference (CIM-aligned), DCM-managed';

DEFINE SCHEMA {{ env_db }}.{{ comm_sch }}
    COMMENT = 'Common conformed objects, DCM-managed';

DEFINE SCHEMA {{ env_db }}.{{ frmwk_sch }}
    COMMENT = 'Logging, deploy, email config, DCM-managed';

DEFINE SCHEMA {{ env_db }}.{{ stage_sch }}
    COMMENT = 'Staging + curated AMI reads, DCM-managed';
