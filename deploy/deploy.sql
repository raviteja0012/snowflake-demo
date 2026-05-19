--!jinja
-- deploy.sql - top-level orchestrator (v2: captures GIT_COMMIT_HASH)
--
-- Replaces prod ami_deploy.sql:
--   !source ./SomeDDL.sql                       -> EXECUTE IMMEDIATE FROM '...'
--   &DB_NAME                                    -> {{ env_db }}
--   !SET OUTPUT_FILE=...log                     -> FRAMEWORK.DEPLOY_LOG row
--   CALL FRAMEWORK.UPDATE_PROCESS_LOGS(...)     -> CALL SP_LOG_DEPLOY(...)
--
-- DEPLOY_LOG is the Snowflake-side equivalent of the SnowSQL .log file.
-- One row per deploy: who, when, branch, commit hash, status.
--
-- Quick check after deploy:
--   SELECT * FROM FRAMEWORK.DEPLOY_LOG ORDER BY DEPLOY_ID DESC LIMIT 5;
--
-- Order matters. Framework tables and SP_LOG_DEPLOY must exist before we write to them.

USE ROLE      {{ rl_name }};
USE WAREHOUSE {{ wh_name }};
USE DATABASE  {{ env_db }};

-- Capture which commit we are deploying. SHOW GIT BRANCHES emits commit_hash per branch.
SHOW GIT BRANCHES IN {{ env_db }}.GIT_OPS.AMI_GIT_REPO;
SET v_commit_hash = (
    SELECT "commit_hash"
      FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
     WHERE "name" = 'main'
);

-- Framework FIRST so DEPLOY_LOG, PROCESS_LOG, SP_LOG_DEPLOY exist before we write
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

-- Deploy START row in DEPLOY_LOG
INSERT INTO {{ env_db }}.{{ frmwk_sch }}.DEPLOY_LOG
    (GIT_COMMIT_HASH, GIT_BRANCH, DEPLOY_STATUS, STATUS_DESC)
VALUES
    ($v_commit_hash, 'main', 'STARTED', 'AMI deploy started via native git integration');

SET v_deploy_id = (SELECT MAX(DEPLOY_ID) FROM {{ env_db }}.{{ frmwk_sch }}.DEPLOY_LOG);

-- Schema USAGE grants
EXECUTE IMMEDIATE FROM './01_grants/01_BaseGrants_DDL_v1.0.sql'
    USING (env_db           => '{{ env_db }}',
           ami_mat_role     => '{{ ami_mat_role }}',
           ami_sel_role     => '{{ ami_sel_role }}',
           ami_support_role => '{{ ami_support_role }}',
           corp_sch         => '{{ corp_sch }}',
           comm_sch         => '{{ comm_sch }}',
           frmwk_sch        => '{{ frmwk_sch }}',
           stage_sch        => '{{ stage_sch }}');

-- Dims and facts. CREATE OR ALTER so data is safe on re-runs.
EXECUTE IMMEDIATE FROM './20_dimensions/20_MeterDim_DDL_v1.0.sql'
    USING (stage_sch    => '{{ stage_sch }}',
           ami_mat_role => '{{ ami_mat_role }}',
           ami_sel_role => '{{ ami_sel_role }}');

EXECUTE IMMEDIATE FROM './30_facts/30_MeterReadsFact_DDL_v1.0.sql'
    USING (stage_sch    => '{{ stage_sch }}',
           ami_mat_role => '{{ ami_mat_role }}',
           ami_sel_role => '{{ ami_sel_role }}');

-- Hourly task, ships SUSPENDED, ops resumes manually
EXECUTE IMMEDIATE FROM './50_tasks/50_RetryTask_DDL_v1.0.sql'
    USING (frmwk_sch        => '{{ frmwk_sch }}',
           wh_name          => '{{ wh_name }}',
           ami_mat_role     => '{{ ami_mat_role }}',
           ami_support_role => '{{ ami_support_role }}');

-- Seed config rows. Idempotent via WHERE NOT EXISTS.
EXECUTE IMMEDIATE FROM './60_dml/60_FrameworkEmailSeed_DML_v1.0.sql'
    USING (frmwk_sch => '{{ frmwk_sch }}');

-- Sample meter data for demo only
EXECUTE IMMEDIATE FROM './70_sample_data/70_SampleData_DML_v1.0.sql'
    USING (stage_sch => '{{ stage_sch }}');

-- Deploy END row. If anything above failed, execution stops here and DEPLOY_END_TS stays NULL.
UPDATE {{ env_db }}.{{ frmwk_sch }}.DEPLOY_LOG
   SET DEPLOY_STATUS = 'SUCCESS',
       STATUS_DESC   = 'All phases ok: framework, grants, dims, facts, tasks, dml, sample data',
       DEPLOY_END_TS = CURRENT_TIMESTAMP()
 WHERE DEPLOY_ID = $v_deploy_id;

-- Also write to PROCESS_LOG (mirrors prod UPDATE_PROCESS_LOGS pattern)
CALL {{ env_db }}.{{ frmwk_sch }}.SP_LOG_DEPLOY('AMI_DEPLOY', 'GIT_INTEGRATION_DEPLOY');

-- Final status row visible to caller (Snowsight or GitHub Action)
SELECT
    'AMI demo deploy complete' AS status,
    $v_deploy_id               AS deploy_id,
    $v_commit_hash             AS commit_hash,
    '{{ env_db }}'             AS deployed_to,
    CURRENT_USER()             AS deployed_by,
    CURRENT_ROLE()             AS deployed_role,
    CURRENT_TIMESTAMP()        AS deployed_at;
