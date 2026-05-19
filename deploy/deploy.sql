--!jinja
-- =====================================================================
-- deploy.sql - top-level orchestrator
--
-- This is what ami_deploy.sql does in the prod SnowSQL world, just with
-- EXECUTE IMMEDIATE FROM instead of !source and Jinja instead of &VAR.
--
-- Caller passes 16 vars via USING(...). Anything missing here will blow
-- up with jinja UndefinedError - that is the contract, not a bug.
--
-- Nested EIF calls use relative paths. Snowflake resolves them against
-- this file's location in the git repo clone. Depth limit is 5.
-- =====================================================================

USE ROLE      {{ rl_name }};
USE WAREHOUSE {{ wh_name }};
USE DATABASE  {{ env_db }};

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
-- 10 framework - config tables and the process/deploy log tables
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
-- 40 procs - SP_LOG_DEPLOY, prod-style with exception handlers
-- ---------------------------------------------------------------------
EXECUTE IMMEDIATE FROM './40_procedures/40_LogDeploySP_DDL_v1.0.sql'
    USING (frmwk_sch        => '{{ frmwk_sch }}',
           ami_mat_role     => '{{ ami_mat_role }}',
           ami_support_role => '{{ ami_support_role }}');

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
-- Done. Return status row so caller knows it landed clean.
-- ---------------------------------------------------------------------
SELECT
    'AMI demo deploy complete' AS status,
    '{{ env_db }}'             AS deployed_to,
    CURRENT_USER()             AS deployed_by,
    CURRENT_ROLE()             AS deployed_role,
    CURRENT_TIMESTAMP()        AS deployed_at;
