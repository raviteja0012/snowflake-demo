-- =====================================================================
-- View_Deploy_History.sql
--
-- All the queries you need to investigate any deploy. This is the
-- SnowSQL .log file equivalent for native git integration deploys.
--
-- Five queries, run as needed:
--   1. Last 10 deploys (high-level)
--   2. Failed or stuck deploys
--   3. Deploy frequency by user
--   4. Recent PROCESS_LOG entries
--   5. FULL PER-STATEMENT AUDIT for a specific deploy_id (the .log equivalent)
-- =====================================================================

USE ROLE DEV_AMI_ADMIN_ROLE;
USE WAREHOUSE NONPROD_AMI_ADMIN_WH;
USE DATABASE AMI_DEMO_DB;
USE SCHEMA FRAMEWORK;

-- ---------------------------------------------------------------------
-- 1. Last 10 deploys (most recent first) - deploy-level audit
-- ---------------------------------------------------------------------
SELECT DEPLOY_ID,
       GIT_BRANCH,
       LEFT(GIT_COMMIT_HASH, 7) AS COMMIT_SHORT,
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
       LEFT(GIT_COMMIT_HASH, 7) AS COMMIT_SHORT,
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
-- 3. Deploy frequency by user
-- ---------------------------------------------------------------------
SELECT DEPLOYED_BY_USER,
       COUNT(*) AS DEPLOY_COUNT,
       SUM(IFF(DEPLOY_STATUS = 'SUCCESS', 1, 0)) AS SUCCESS_COUNT,
       SUM(IFF(DEPLOY_STATUS = 'ERROR' OR DEPLOY_END_TS IS NULL, 1, 0)) AS FAILED_COUNT,
       MIN(DEPLOY_START_TS) AS FIRST_DEPLOY,
       MAX(DEPLOY_START_TS) AS LAST_DEPLOY
  FROM DEPLOY_LOG
 GROUP BY DEPLOYED_BY_USER
 ORDER BY DEPLOY_COUNT DESC;

-- ---------------------------------------------------------------------
-- 4. Recent PROCESS_LOG entries (mirrors prod UPDATE_PROCESS_LOGS view)
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

-- =====================================================================
-- 5. FULL PER-STATEMENT AUDIT for a specific deploy
--    This is the SnowSQL .log file equivalent.
--    
--    Replace <DEPLOY_ID> with the deploy you want to investigate.
--    For deploys older than 7 days, change INFORMATION_SCHEMA to 
--    SNOWFLAKE.ACCOUNT_USAGE (requires ACCOUNTADMIN, 45 min latency).
-- =====================================================================

SET v_target_deploy_id = 101;  -- <-- CHANGE THIS to the deploy you're investigating

WITH target_deploy AS (
    SELECT DEPLOY_ID, DEPLOYED_BY_USER, DEPLOY_START_TS, 
           COALESCE(DEPLOY_END_TS, CURRENT_TIMESTAMP()) AS END_TS
      FROM DEPLOY_LOG
     WHERE DEPLOY_ID = $v_target_deploy_id
)
SELECT
    td.DEPLOY_ID,
    q.START_TIME             AS stmt_start,
    q.TOTAL_ELAPSED_TIME/1000 AS elapsed_sec,
    q.EXECUTION_STATUS        AS status,
    q.ERROR_CODE,
    q.ERROR_MESSAGE,
    q.WAREHOUSE_NAME,
    LEFT(q.QUERY_TEXT, 200)   AS query_preview,
    q.QUERY_ID
  FROM target_deploy td,
       TABLE(INFORMATION_SCHEMA.QUERY_HISTORY_BY_USER(
            USER_NAME            => td.DEPLOYED_BY_USER,
            END_TIME_RANGE_START => DATEADD(MINUTE, -1, td.DEPLOY_START_TS),
            END_TIME_RANGE_END   => DATEADD(MINUTE, 1, td.END_TS),
            RESULT_LIMIT         => 1000)) q
 WHERE q.START_TIME BETWEEN td.DEPLOY_START_TS AND td.END_TS
 ORDER BY q.START_TIME;

-- ---------------------------------------------------------------------
-- 5b. To see the FULL query text of any one statement (no truncation):
-- ---------------------------------------------------------------------
-- SELECT QUERY_TEXT, ERROR_MESSAGE
--   FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
--  WHERE QUERY_ID = '<paste-query-id-from-query-5>';