--!jinja
-- =====================================================================
-- deploy.sql - top-level orchestrator (v2 adds GIT_COMMIT_HASH capture)
--
-- Replaces prod ami_deploy.sql:
--   prod: !source ./SomeDDL.sql       → EXECUTE IMMEDIATE FROM '...'
--   prod: &DB_NAME                    → {{ env_db }}
--   prod: !SET OUTPUT_FILE=...log     → FRAMEWORK.DEPLOY_LOG row
--   prod: CALL FRAMEWORK.UPDATE_PROCESS_LOGS(...) → CALL SP_LOG_DEPLOY(...)
--
-- DEPLOY_LOG is the server-side equivalent of prod's SnowSQL log file.
-- Each row captures: who, when, from which branch, which commit hash,
-- success/error, status description.
--
-- View recent deploys:
--   SELECT * FROM FRAMEWORK.DEPLOY_LOG ORDER BY DEPLOY_ID DESC LIMIT 10;
--
-- Order: framework objects (DEPLOY_LOG, SP_LOG_DEPLOY) must exist BEFORE
-- we write to them. So 10_framework runs first.
-- =====================================================================

USE ROLE      {{ rl_name }};
USE WAREHOUSE {{ wh_name }};
USE DATABASE  {{ env_db }};

-- ---------------------------------------------------------------------
-- Capture which commit we're deploying. SHOW GIT BRANCHES emits the
-- current commit_hash for each branch in the local clone.
-- We pull the hash for 'main' into a session variable so the deploy log
-- row can record the exact source-of-truth commit.
-- ---------------------------------------------------------------------
SHOW GIT BRANCHES IN {{ env_db }}.GIT_OPS.AMI_GIT_REPO;

SET v_commit_hash = (
    SELECT "commit_hash"
      FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
     WHERE "name" = 'main'
);

-- ---------------------------------------------------------------------
-- 10 framework FIRST so DEPLOY_LOG, PROCESS_LOG, SP_LOG_DEPLOY exist
-- before we try to write deploy log entries
-- ---------------------------------------------------------------------
EXECUTE IMMEDIATE FROM './10_framework/10_FrameworkConfig_DDL_v1.0.sql'
    USING (frmwk_sch        => '{{ frmwk_sch }}',
           ami_mat_role     => '{{ ami_mat_role }}',
           ami_sel_role     => '{{ ami_sel_role }}',
           ami_support_role => '{{ ami_support_role }}');

EXECUTE IMMEDIATE FROM './10_framework/11_FrameworkLog_DDL_v1.0.sql'
    USING (frmwk_sch        => '{{ frmwk_sch }}',
           ami_mat_role     => '{{ ami_mat_role }}',
           ami_sel_role     => '{{ ami_sel_role }}',
           ami_support_role => '{{ ami_support_role }}');

EXECUTE IMMEDIATE FROM './40_procedures/40_LogDeploySP_DDL_v1.0.sql'
    USING (frmwk_sch        => '{{ frmwk_sch }}',
           ami_mat_role     => '{{ ami_mat_role }}',
           ami_support_role => '{{ ami_support_role }}');

-- ---------------------------------------------------------------------
-- Log deploy START to FRAMEWORK.DEPLOY_LOG, including the commit hash
-- ---------------------------------------------------------------------
INSERT INTO {{ env_db }}.{{ frmwk_sch }}.DEPLOY_LOG
    (GIT_COMMIT_HASH, GIT_BRANCH, DEPLOY_STATUS, STATUS_DESC)
VALUES
    ($v_commit_hash, 'main', 'STARTED', 'AMI deploy started via native git integration');

-- Capture surrogate id of the row we just inserted
SET v_deploy_id = (SELECT MAX(DEPLOY_ID)
                     FROM {{ env_db }}.{{ frmwk_sch }}.DEPLOY_LOG);

-- ---------------------------------------------------------------------
-- 01 grants - base schema USAGE for the consumer roles
-- ---------------------------------------------------------------------
EXECUTE IMMEDIATE FROM './01_grants/01_BaseGrants_DDL_v1.0.sql'
    USING (env_db           => '{{ env_db }}',
           ami_mat_role     => '{{ ami_mat_role }}',
           ami_sel_role     => '{{ ami_sel_role }}',
           ami_support_role => '{{ ami_support_role }}',
           corp_sch         => '{{ corp_sch }}',
           comm_sch         => '{{ comm_sch }}',
           frmwk_sch        => '{{ frmwk_sch }}',
           stage_sch        => '{{ stage_sch }}');

-- ---------------------------------------------------------------------
-- 20/30 dims and facts - AMISTAGE tables. CREATE OR ALTER for data safety
-- ---------------------------------------------------------------------
EXECUTE IMMEDIATE FROM './20_dimensions/20_MeterDim_DDL_v1.0.sql'
    USING (stage_sch    => '{{ stage_sch }}',
           ami_mat_role => '{{ ami_mat_role }}',
           ami_sel_role => '{{ ami_sel_role }}');

EXECUTE IMMEDIATE FROM './30_facts/30_MeterReadsFact_DDL_v1.0.sql'
    USING (stage_sch    => '{{ stage_sch }}',
           ami_mat_role => '{{ ami_mat_role }}',
           ami_sel_role => '{{ ami_sel_role }}');

-- ---------------------------------------------------------------------
-- 50 tasks - hourly heartbeat. Ships SUSPENDED, ops resumes manually
-- ---------------------------------------------------------------------
EXECUTE IMMEDIATE FROM './50_tasks/50_RetryTask_DDL_v1.0.sql'
    USING (frmwk_sch        => '{{ frmwk_sch }}',
           wh_name          => '{{ wh_name }}',
           ami_mat_role     => '{{ ami_mat_role }}',
           ami_support_role => '{{ ami_support_role }}');

-- ---------------------------------------------------------------------
-- 60 dml - seed config table. Idempotent via INSERT...WHERE NOT EXISTS
-- ---------------------------------------------------------------------
EXECUTE IMMEDIATE FROM './60_dml/60_FrameworkEmailSeed_DML_v1.0.sql'
    USING (frmwk_sch => '{{ frmwk_sch }}');

-- ---------------------------------------------------------------------
-- 70 sample data - small generic seed for demo purposes only
-- ---------------------------------------------------------------------
EXECUTE IMMEDIATE FROM './70_sample_data/70_SampleData_DML_v1.0.sql'
    USING (stage_sch => '{{ stage_sch }}');

-- ---------------------------------------------------------------------
-- Log deploy END (SUCCESS path)
-- If anything above failed, execution stops before this UPDATE.
-- DEPLOY_LOG rows with DEPLOY_END_TS = NULL = failed/interrupted deploys.
-- ---------------------------------------------------------------------
UPDATE {{ env_db }}.{{ frmwk_sch }}.DEPLOY_LOG
   SET DEPLOY_STATUS = 'SUCCESS',
       STATUS_DESC   = 'All deploy phases completed: framework, grants, dims, facts, tasks, dml, sample data',
       DEPLOY_END_TS = CURRENT_TIMESTAMP()
 WHERE DEPLOY_ID = $v_deploy_id;

-- Also write to PROCESS_LOG via the proc (mirrors prod UPDATE_PROCESS_LOGS pattern)
CALL {{ env_db }}.{{ frmwk_sch }}.SP_LOG_DEPLOY('AMI_DEPLOY', 'GIT_INTEGRATION_DEPLOY');

-- ---------------------------------------------------------------------
-- Final status row. Caller (Snowsight or GitHub Action) sees this.
-- ---------------------------------------------------------------------
SELECT
    'AMI demo deploy complete' AS status,
    $v_deploy_id               AS deploy_id,
    $v_commit_hash             AS commit_hash,
    '{{ env_db }}'             AS deployed_to,
    CURRENT_USER()             AS deployed_by,
    CURRENT_ROLE()             AS deployed_role,
    CURRENT_TIMESTAMP()        AS deployed_at;