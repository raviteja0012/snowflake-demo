--!jinja
-- =====================================================================
-- deploy.sql - top-level orchestrator
--
-- This replaces prod ami_deploy.sql:
--   prod: !source ./SomeDDL.sql       → our: EXECUTE IMMEDIATE FROM '...'
--   prod: &DB_NAME                    → our: {{ env_db }}
--   prod: !SET OUTPUT_FILE=...log     → our: FRAMEWORK.DEPLOY_LOG row
--   prod: CALL FRAMEWORK.UPDATE_PROCESS_LOGS(...) → SP_LOG_DEPLOY call
--
-- DEPLOY_LOG replaces the SnowSQL client-side log file. Server-side,
-- queryable forever, shared across users. To view recent deploys:
--   SELECT * FROM FRAMEWORK.DEPLOY_LOG ORDER BY DEPLOY_ID DESC LIMIT 10;
--
-- Order matters: framework objects (DEPLOY_LOG table, SP_LOG_DEPLOY proc)
-- must exist BEFORE we try to log to them. So 10_framework runs first.
-- =====================================================================

USE ROLE      {{ rl_name }};
USE WAREHOUSE {{ wh_name }};
USE DATABASE  {{ env_db }};

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
-- Log deploy START to FRAMEWORK.DEPLOY_LOG
-- Captures who, when, from which branch. End row updates this on completion.
-- ---------------------------------------------------------------------
INSERT INTO {{ env_db }}.{{ frmwk_sch }}.DEPLOY_LOG
    (GIT_BRANCH, DEPLOY_STATUS, STATUS_DESC)
VALUES
    ('main', 'STARTED', 'AMI deploy started via native git integration');

-- Capture surrogate id of the row we just inserted, into a session variable
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
-- Final status row. This is what the caller (Snowsight worksheet or
-- GitHub Action) sees in the result set.
-- ---------------------------------------------------------------------
SELECT
    'AMI demo deploy complete' AS status,
    $v_deploy_id               AS deploy_id,
    '{{ env_db }}'             AS deployed_to,
    CURRENT_USER()             AS deployed_by,
    CURRENT_ROLE()             AS deployed_role,
    CURRENT_TIMESTAMP()        AS deployed_at;