--!jinja
---------------------------------------------------------------------
-- Script   : deploy.sql
-- Purpose  : Top-level orchestrator. Equivalent of ami_deploy.sql (SnowSQL).
-- Called   : EXECUTE IMMEDIATE FROM
--              @AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main/deploy/deploy.sql
--              USING (env_db => 'AMI_DEMO_DB', ...);
-- Created  : 2026-05-19
-- Notes    : - First line MUST be `--!jinja` (templating directive).
--            - Every {{ var }} below must be provided in the USING clause
--              of the caller, otherwise UndefinedError fires.
--            - Chained EXECUTE IMMEDIATE FROM uses relative paths against
--              the parent file's location in the repo.
---------------------------------------------------------------------

USE ROLE      {{ rl_name }};
USE WAREHOUSE {{ wh_name }};
USE DATABASE  {{ env_db }};

-- ===================================================================
-- 01_grants   Base schema-level grants for consumer roles
-- ===================================================================
EXECUTE IMMEDIATE FROM './01_grants/01_BaseGrants_DDL_v1.0.sql'
    USING (env_db           => '{{ env_db }}',
           ami_mat_role     => '{{ ami_mat_role }}',
           ami_sel_role     => '{{ ami_sel_role }}',
           ami_support_role => '{{ ami_support_role }}',
           corp_sch         => '{{ corp_sch }}',
           comm_sch         => '{{ comm_sch }}',
           frmwk_sch        => '{{ frmwk_sch }}',
           stage_sch        => '{{ stage_sch }}');

-- ===================================================================
-- 10_framework  FRAMEWORK schema config + deploy log
-- ===================================================================
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

-- ===================================================================
-- 20_dimensions / 30_facts   AMISTAGE tables (CREATE OR ALTER, data-safe)
-- ===================================================================
EXECUTE IMMEDIATE FROM './20_dimensions/20_MeterDim_DDL_v1.0.sql'
    USING (stage_sch    => '{{ stage_sch }}',
           ami_mat_role => '{{ ami_mat_role }}',
           ami_sel_role => '{{ ami_sel_role }}');

EXECUTE IMMEDIATE FROM './30_facts/30_MeterReadsFact_DDL_v1.0.sql'
    USING (stage_sch    => '{{ stage_sch }}',
           ami_mat_role => '{{ ami_mat_role }}',
           ami_sel_role => '{{ ami_sel_role }}');

-- ===================================================================
-- 40_procedures   FRAMEWORK.SP_LOG_DEPLOY (mirrors UPDATE_PROCESS_LOGS pattern)
-- ===================================================================
EXECUTE IMMEDIATE FROM './40_procedures/40_LogDeploySP_DDL_v1.0.sql'
    USING (frmwk_sch        => '{{ frmwk_sch }}',
           ami_mat_role     => '{{ ami_mat_role }}',
           ami_support_role => '{{ ami_support_role }}');

-- ===================================================================
-- 50_tasks   Hourly retry task, ships SUSPENDED (mirrors prod Retry pattern)
-- ===================================================================
EXECUTE IMMEDIATE FROM './50_tasks/50_RetryTask_DDL_v1.0.sql'
    USING (frmwk_sch        => '{{ frmwk_sch }}',
           wh_name          => '{{ wh_name }}',
           ami_mat_role     => '{{ ami_mat_role }}',
           ami_support_role => '{{ ami_support_role }}');

-- ===================================================================
-- 60_dml   Seed FRAMEWORK.EMAIL_BODY_DISPLAY_CONFIG (mirrors prod DML pattern)
-- ===================================================================
EXECUTE IMMEDIATE FROM './60_dml/60_FrameworkEmailSeed_DML_v1.0.sql'
    USING (frmwk_sch => '{{ frmwk_sch }}');

-- ===================================================================
-- Final status row (returned to the caller of EXECUTE IMMEDIATE FROM)
-- ===================================================================
SELECT
    'AMI demo deploy complete' AS status,
    '{{ env_db }}'             AS deployed_to,
    CURRENT_USER()             AS deployed_by,
    CURRENT_ROLE()             AS deployed_role,
    CURRENT_TIMESTAMP()        AS deployed_at;
