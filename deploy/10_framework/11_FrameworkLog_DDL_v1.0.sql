--!jinja
---------------------------------------------------------------------
-- Script   : 11_FrameworkLog_DDL_v1.0.sql
-- Purpose  : Deployment + process logging tables. Demo equivalent of the
--            prod FRAMEWORK.UPDATE_PROCESS_LOGS sink.
-- Version  : 1.0
-- Created  : 2026-05-19
---------------------------------------------------------------------

USE SCHEMA {{ frmwk_sch }};

-- ===================================================================
-- DEPLOY_LOG: one row per native-git-integration deploy run
-- ===================================================================
CREATE OR ALTER TABLE DEPLOY_LOG (
    DEPLOY_ID         NUMBER(38,0) IDENTITY(1,1)  NOT NULL  COMMENT 'Surrogate deploy run id',
    GIT_COMMIT_HASH   VARCHAR(64)                           COMMENT 'commit_hash from SHOW GIT BRANCHES at deploy time',
    GIT_BRANCH        VARCHAR(200)                          COMMENT 'Branch deployed from',
    DEPLOYED_BY_USER  VARCHAR(200)  NOT NULL  DEFAULT CURRENT_USER()  COMMENT 'User who triggered deploy',
    DEPLOYED_BY_ROLE  VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE()  COMMENT 'Role that ran the deploy',
    DEPLOY_STATUS     VARCHAR(20)   NOT NULL  DEFAULT 'STARTED'       COMMENT 'STARTED / SUCCESS / ERROR',
    STATUS_DESC       VARCHAR(4000)                                   COMMENT 'Status detail or error message',
    DEPLOY_START_TS   TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP() COMMENT 'When the deploy started',
    DEPLOY_END_TS     TIMESTAMP_TZ                                    COMMENT 'When the deploy completed (NULL while running)',
    CONSTRAINT PK_DEPLOY_LOG PRIMARY KEY (DEPLOY_ID)
)
COMMENT = 'Records every native git integration deploy run for audit.';

-- ===================================================================
-- PROCESS_LOG: generic process log, mirrors the prod UPDATE_PROCESS_LOGS sink
-- ===================================================================
CREATE OR ALTER TABLE PROCESS_LOG (
    LOG_ID         NUMBER(38,0) IDENTITY(1,1)  NOT NULL  COMMENT 'Surrogate log row id',
    PROCESS_ID     VARCHAR(100)                          COMMENT 'Session+random id used by prod procs',
    PROCESS_NAME   VARCHAR(100)                          COMMENT 'Logical process name',
    FILE_ID        VARCHAR(100)                          COMMENT 'Optional file id passed by caller',
    COMPONENT      VARCHAR(100)                          COMMENT 'PROCESS_STARTED / DATA_PROCESSED / PROCESS_COMPLETED etc.',
    PROC_STATUS    VARCHAR(20)                           COMMENT 'SUCCESS / ERROR / WARNING',
    STATUS_DESC    VARCHAR(4000)                         COMMENT 'Detail message',
    LOG_TS         TIMESTAMP_TZ  NOT NULL DEFAULT CURRENT_TIMESTAMP()  COMMENT 'When the log row was written',
    LOGGED_BY_ROLE VARCHAR(200)  NOT NULL DEFAULT CURRENT_ROLE()       COMMENT 'Role that wrote the log',
    CONSTRAINT PK_PROCESS_LOG PRIMARY KEY (LOG_ID)
)
COMMENT = 'Generic process log table. Mirrors prod UPDATE_PROCESS_LOGS sink.';

-- ===================================================================
-- Grants
-- ===================================================================
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE DEPLOY_LOG  TO ROLE {{ ami_mat_role }};
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE PROCESS_LOG TO ROLE {{ ami_mat_role }};

GRANT SELECT ON TABLE DEPLOY_LOG  TO ROLE {{ ami_sel_role }};
GRANT SELECT ON TABLE PROCESS_LOG TO ROLE {{ ami_sel_role }};

GRANT SELECT ON TABLE DEPLOY_LOG  TO ROLE {{ ami_support_role }};
GRANT SELECT ON TABLE PROCESS_LOG TO ROLE {{ ami_support_role }};
