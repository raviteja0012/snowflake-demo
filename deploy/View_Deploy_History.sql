-- =====================================================================
-- View_Deploy_History.sql
--
-- Quick observability queries against FRAMEWORK.DEPLOY_LOG and
-- FRAMEWORK.PROCESS_LOG. Run any time to see what deploys ran, when,
-- by whom, with what outcome.
--
-- Replaces "cat ami_deploy_*.log" from the prod SnowSQL world.
-- =====================================================================

USE ROLE DEV_AMI_ADMIN_ROLE;
USE WAREHOUSE NONPROD_AMI_ADMIN_WH;
USE DATABASE AMI_DEMO_DB;
USE SCHEMA FRAMEWORK;

-- ---------------------------------------------------------------------
-- 1. Last 10 deploys (most recent first)
-- ---------------------------------------------------------------------
SELECT DEPLOY_ID,
       GIT_BRANCH,
       GIT_COMMIT_HASH,
       DEPLOYED_BY_USER,
       DEPLOYED_BY_ROLE,
       DEPLOY_STATUS,
       STATUS_DESC,
       DEPLOY_START_TS,
       DEPLOY_END_TS,
       DATEDIFF(SECOND, DEPLOY_START_TS, DEPLOY_END_TS) AS DURATION_SEC
  FROM DEPLOY_LOG
 ORDER BY DEPLOY_ID DESC
 LIMIT 10;

-- ---------------------------------------------------------------------
-- 2. Failed or stuck deploys (no end timestamp = interrupted)
-- ---------------------------------------------------------------------
SELECT DEPLOY_ID,
       DEPLOYED_BY_USER,
       DEPLOY_STATUS,
       STATUS_DESC,
       DEPLOY_START_TS,
       DATEDIFF(MINUTE, DEPLOY_START_TS, CURRENT_TIMESTAMP()) AS MINS_AGO
  FROM DEPLOY_LOG
 WHERE DEPLOY_END_TS IS NULL
    OR DEPLOY_STATUS = 'ERROR'
 ORDER BY DEPLOY_ID DESC;

-- ---------------------------------------------------------------------
-- 3. Deploy frequency by user (who deploys most)
-- ---------------------------------------------------------------------
SELECT DEPLOYED_BY_USER,
       COUNT(*) AS DEPLOY_COUNT,
       MIN(DEPLOY_START_TS) AS FIRST_DEPLOY,
       MAX(DEPLOY_START_TS) AS LAST_DEPLOY
  FROM DEPLOY_LOG
 GROUP BY DEPLOYED_BY_USER
 ORDER BY DEPLOY_COUNT DESC;

-- ---------------------------------------------------------------------
-- 4. Most recent PROCESS_LOG entries (last 20)
-- ---------------------------------------------------------------------
SELECT LOG_ID,
       PROCESS_NAME,
       COMPONENT,
       PROC_STATUS,
       STATUS_DESC,
       LOG_TS,
       LOGGED_BY_ROLE
  FROM PROCESS_LOG
 ORDER BY LOG_ID DESC
 LIMIT 20;

-- ---------------------------------------------------------------------
-- 5. Cross-reference: Snowflake QUERY_HISTORY for the last deploy
-- (this is the "ground truth" log of every SQL statement executed)
-- ---------------------------------------------------------------------
SELECT QUERY_ID,
       QUERY_TEXT,
       EXECUTION_STATUS,
       ERROR_CODE,
       ERROR_MESSAGE,
       START_TIME,
       TOTAL_ELAPSED_TIME / 1000 AS ELAPSED_SEC
  FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
 WHERE USER_NAME = CURRENT_USER()
   AND DATABASE_NAME = 'AMI_DEMO_DB'
   AND START_TIME > DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
 ORDER BY START_TIME DESC
 LIMIT 30;