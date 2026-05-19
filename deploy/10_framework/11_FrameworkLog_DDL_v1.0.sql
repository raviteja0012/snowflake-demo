--!jinja
-- 11_FrameworkLog_DDL_v1.0.sql
-- Two log tables:
--   DEPLOY_LOG  - one row per deploy run (who, when, branch, commit, status)
--   PROCESS_LOG - one row per process step (mirror of prod UPDATE_PROCESS_LOGS sink)
--
-- QUERY_HISTORY also has all this, but a structured table makes
-- "what did the last deploy do" answerable in one SELECT.

USE SCHEMA {{ frmwk_sch }};

CREATE OR ALTER TABLE DEPLOY_LOG (
    DEPLOY_ID         NUMBER(38,0) IDENTITY(1,1) NOT NULL  COMMENT 'Surrogate run id',
    GIT_COMMIT_HASH   VARCHAR(64)                          COMMENT 'commit_hash from SHOW GIT BRANCHES at deploy time',
    GIT_BRANCH        VARCHAR(200)                         COMMENT 'Branch we deployed from',
    DEPLOYED_BY_USER  VARCHAR(200) NOT NULL DEFAULT CURRENT_USER(),
    DEPLOYED_BY_ROLE  VARCHAR(200) NOT NULL DEFAULT CURRENT_ROLE(),
    DEPLOY_STATUS     VARCHAR(20)  NOT NULL DEFAULT 'STARTED'  COMMENT 'STARTED, SUCCESS, ERROR',
    STATUS_DESC       VARCHAR(4000)                              COMMENT 'Detail or error message',
    DEPLOY_START_TS   TIMESTAMP_TZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    DEPLOY_END_TS     TIMESTAMP_TZ                              COMMENT 'NULL while running',
    CONSTRAINT PK_DEPLOY_LOG PRIMARY KEY (DEPLOY_ID)
)
COMMENT = 'One row per native-git-integration deploy. Cheap audit trail.';

CREATE OR ALTER TABLE PROCESS_LOG (
    LOG_ID         NUMBER(38,0) IDENTITY(1,1) NOT NULL,
    PROCESS_ID     VARCHAR(100)              COMMENT 'session_id + random suffix, prod convention',
    PROCESS_NAME   VARCHAR(100),
    FILE_ID        VARCHAR(100),
    COMPONENT      VARCHAR(100)              COMMENT 'PROCESS_STARTED, DATA_PROCESSED, PROCESS_COMPLETED, etc.',
    PROC_STATUS    VARCHAR(20)               COMMENT 'SUCCESS, ERROR, WARNING',
    STATUS_DESC    VARCHAR(4000),
    LOG_TS         TIMESTAMP_TZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    LOGGED_BY_ROLE VARCHAR(200) NOT NULL DEFAULT CURRENT_ROLE(),
    CONSTRAINT PK_PROCESS_LOG PRIMARY KEY (LOG_ID)
)
COMMENT = 'Per-step process log. Mirror of prod UPDATE_PROCESS_LOGS sink.';

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE DEPLOY_LOG  TO ROLE {{ ami_mat_role }};
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE PROCESS_LOG TO ROLE {{ ami_mat_role }};

GRANT SELECT ON TABLE DEPLOY_LOG  TO ROLE {{ ami_sel_role }};
GRANT SELECT ON TABLE PROCESS_LOG TO ROLE {{ ami_sel_role }};
GRANT SELECT ON TABLE DEPLOY_LOG  TO ROLE {{ ami_support_role }};
GRANT SELECT ON TABLE PROCESS_LOG TO ROLE {{ ami_support_role }};
