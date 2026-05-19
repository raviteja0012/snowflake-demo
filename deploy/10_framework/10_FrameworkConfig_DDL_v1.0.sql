--!jinja
-- =====================================================================
-- 10_FrameworkConfig_DDL_v1.0.sql
--
-- EMAIL_BODY_DISPLAY_CONFIG table. Tells the notification proc which
-- sections to render in the email body for each process.
--
-- Same shape as the prod table from Validated_Reads_Load_Email_Config_DML.
-- Audit cols default to CURRENT_ROLE() and CURRENT_TIMESTAMP() so we
-- always know who and when, no INSERT statement needs to bother with it.
-- =====================================================================

USE SCHEMA {{ frmwk_sch }};

CREATE OR ALTER TABLE EMAIL_BODY_DISPLAY_CONFIG (
    PROCESS_NAME        VARCHAR(100)  NOT NULL  COMMENT 'Logical process this row applies to',
    EMAIL_BODY_SECTION  VARCHAR(50)   NOT NULL  COMMENT 'Section key (DATA_PROCESSED, DATA_EXCEPTIONS, etc.)',
    EMAIL_BODY_DISPLAY  VARCHAR(1)    NOT NULL  COMMENT 'Y to render, N to skip',
    CREATE_BY_ID        VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE()       COMMENT 'Who inserted',
    CREATE_DTTM         TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP()  COMMENT 'When inserted',
    UPDATE_BY_ID        VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE()       COMMENT 'Who last updated',
    UPDATE_DTTM         TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP()  COMMENT 'When last updated',
    CONSTRAINT PK_EMAIL_BODY_DISPLAY_CONFIG PRIMARY KEY (PROCESS_NAME, EMAIL_BODY_SECTION)
)
COMMENT = 'Per-process email body section toggles. Demo-scale mirror of prod.';

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE EMAIL_BODY_DISPLAY_CONFIG
    TO ROLE {{ ami_mat_role }};
GRANT SELECT ON TABLE EMAIL_BODY_DISPLAY_CONFIG TO ROLE {{ ami_sel_role }};
GRANT SELECT ON TABLE EMAIL_BODY_DISPLAY_CONFIG TO ROLE {{ ami_support_role }};
