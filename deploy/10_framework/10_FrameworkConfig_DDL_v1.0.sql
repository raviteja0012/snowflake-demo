--!jinja
---------------------------------------------------------------------
-- Script   : 10_FrameworkConfig_DDL_v1.0.sql
-- Purpose  : FRAMEWORK config tables. Mirrors the prod
--            EMAIL_BODY_DISPLAY_CONFIG pattern at small scale.
-- Version  : 1.0
-- Created  : 2026-05-19
---------------------------------------------------------------------

USE SCHEMA {{ frmwk_sch }};

-- ===================================================================
-- EMAIL_BODY_DISPLAY_CONFIG: which sections of the process email render
-- (Mirror of the prod table from Validated_Reads_Load_Email_Config_DML.sql)
-- ===================================================================
CREATE OR ALTER TABLE EMAIL_BODY_DISPLAY_CONFIG (
    PROCESS_NAME        VARCHAR(100)  NOT NULL  COMMENT 'Logical process identifier',
    EMAIL_BODY_SECTION  VARCHAR(50)   NOT NULL  COMMENT 'Section key e.g. DATA_PROCESSED',
    EMAIL_BODY_DISPLAY  VARCHAR(1)    NOT NULL  COMMENT 'Y or N',
    CREATE_BY_ID        VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE()       COMMENT 'Role that inserted',
    CREATE_DTTM         TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP()  COMMENT 'Insert timestamp',
    UPDATE_BY_ID        VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE()       COMMENT 'Role that last updated',
    UPDATE_DTTM         TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP()  COMMENT 'Last update timestamp',
    CONSTRAINT PK_EMAIL_BODY_DISPLAY_CONFIG PRIMARY KEY (PROCESS_NAME, EMAIL_BODY_SECTION)
)
COMMENT = 'Holds the configuration info for email body display (per process).';

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE EMAIL_BODY_DISPLAY_CONFIG
    TO ROLE {{ ami_mat_role }};
GRANT SELECT ON TABLE EMAIL_BODY_DISPLAY_CONFIG
    TO ROLE {{ ami_sel_role }};
GRANT SELECT ON TABLE EMAIL_BODY_DISPLAY_CONFIG
    TO ROLE {{ ami_support_role }};
