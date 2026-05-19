--!jinja
-- 00_database_and_schemas.sql
-- Database and schemas as DEFINE statements.
-- Order doesn't matter, Snowflake sorts dependencies itself.

DEFINE DATABASE {{ env_db }}
    COMMENT = 'AMI native Git integration demo (DCM-managed)';

DEFINE SCHEMA {{ env_db }}.{{ corp_sch }}    COMMENT = 'CORP_SCH';
DEFINE SCHEMA {{ env_db }}.{{ comm_sch }}    COMMENT = 'COMM_SCH';
DEFINE SCHEMA {{ env_db }}.{{ frmwk_sch }}   COMMENT = 'FRMWK_SCH';
DEFINE SCHEMA {{ env_db }}.{{ stage_sch }}   COMMENT = 'STAGE_SCH';
