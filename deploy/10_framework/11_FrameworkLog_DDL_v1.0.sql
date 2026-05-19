--!jinja
-- =====================================================================
-- 11_FrameworkLog_DDL_v1.0.sql
--
-- Two logging tables:
--   DEPLOY_LOG  - one row per deploy run (audit who/when/which commit)
--   PROCESS_LOG - one row per process step (mirror of prod
--                 UPDATE_PROCESS_LOGS sink)
--
-- Query history covers everything too, but a structured log table makes
-- "what did the last deploy do" answerable with one SELECT.
-- =====================================================================

USE SCHEMA {{ frmwk_sch }};

CREATE OR ALTER TABLE DEPLOY_LOG (
    DEPLOY_ID         NUMBER(38,0) IDENTITY(1,1)  NOT NULL  COMMENT 'Surrogate run id',
    GIT_COMMIT_HASH   VARCHAR(64)                           COMMENT 'SHOW GIT BRANCHES commit hash at deploy time',
    GIT_BRANCH        VARCHAR(200)                          COMMENT 'Branch the deploy pulled from',
    DEPLOYED_BY_USER  VARCHAR(200)  NOT NULL  DEFAULT CURRENT_USER()  COMMENT 'Who ran it',
    DEPLOYED_BY_ROLE  VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE()  COMMENT 'Active role at run time',
    DEPLOY_STATUS     VARCHAR(20)   NOT NULL  DEFAULT 'STARTED'       COMMENT 'STARTED, SUCCESS, ERROR',
    STATUS_DESC       VARCHAR(4000)                                   COMMENT 'Detail or error message',
    DEPLOY_START_TS   TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP() COMMENT 'Run start',
    DEPLOY_END_TS     TIMESTAMP_TZ                                    COMMENT 'Run end (NULL while running)',
    CONSTRAINT PK_DEPLOY_LOG PRIMARY KEY (DEPLOY_ID)
)
COMMENT = 'One row per native-git-integration deploy. Cheap audit trail.';

CREATE OR ALTER TABLE PROCESS_LOG (
    LOG_ID         NUMBER(38,0) IDENTITY(1,1)  NOT NULL  COMMENT 'Surrogate row id',
    PROCESS_ID     VARCHAR(100)                          COMMENT 'session + random suffix, prod convention',
    PROCESS_NAME   VARCHAR(100)                          COMMENT 'Logical process name',
    FILE_ID        VARCHAR(100)                          COMMENT 'Optional file id, if caller passes one',
    COMPONENT      VARCHAR(100)                          COMMENT 'PROCESS_STARTED, DATA_PROCESSED, PROCESS_COMPLETED, etc.',
    PROC_STATUS    VARCHAR(20)                           COMMENT 'SUCCESS, ERROR, WARNING',
    STATUS_DESC    VARCHAR(4000)                         COMMENT 'Detail message',
    LOG_TS         TIMESTAMP_TZ  NOT NULL DEFAULT CURRENT_TIMESTAMP()  COMMENT 'When this step was logged',
    LOGGED_BY_ROLE VARCHAR(200)  NOT NULL DEFAULT CURRENT_ROLE()       COMMENT 'Role that wrote the row',
    CONSTRAINT PK_PROCESS_LOG PRIMARY KEY (LOG_ID)
)
COMMENT = 'Generic per-step process log. Mirror of prod UPDATE_PROCESS_LOGS sink.';

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE DEPLOY_LOG  TO ROLE {{ ami_mat_role }};
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE PROCESS_LOG TO ROLE {{ ami_mat_role }};

GRANT SELECT ON TABLE DEPLOY_LOG  TO ROLE {{ ami_sel_role }};
GRANT SELECT ON TABLE PROCESS_LOG TO ROLE {{ ami_sel_role }};

GRANT SELECT ON TABLE DEPLOY_LOG  TO ROLE {{ ami_support_role }};
GRANT SELECT ON TABLE PROCESS_LOG TO ROLE {{ ami_support_role }};
