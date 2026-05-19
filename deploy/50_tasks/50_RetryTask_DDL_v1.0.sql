--!jinja
-- =====================================================================
-- 50_RetryTask_DDL_v1.0.sql
--
-- FRMWK_RETRY_TASK - hourly heartbeat. Demo mirror of prod
-- RETRY_VALIDATED_READS_EXCEPTIONS_TSK.
--
-- Ships SUSPENDED. Always. Even on first deploy, even on a redeploy.
-- The prod habit is to never let a task auto-resume on its own,
-- because a misconfigured task that starts firing during a deploy
-- creates noise that is painful to back out.
--
-- Ops runs ALTER TASK ... RESUME manually after they validate.
-- =====================================================================

USE SCHEMA {{ frmwk_sch }};

-- Suspend first if it exists, then CREATE OR REPLACE. Prod pattern.
ALTER TASK IF EXISTS FRMWK_RETRY_TASK SUSPEND;

CREATE OR REPLACE TASK FRMWK_RETRY_TASK
    WAREHOUSE  = {{ wh_name }}
    AUTOCOMMIT = TRUE
    SCHEDULE   = 'USING CRON 0 * * * * UTC'
    COMMENT    = 'Hourly heartbeat task. Ships SUSPENDED on every deploy.'
AS
    CALL SP_LOG_DEPLOY('FRMWK_RETRY_TASK', 'HEARTBEAT');

-- DO NOT resume here. Ops resumes after validation:
--   ALTER TASK FRMWK_RETRY_TASK RESUME;

GRANT MONITOR, OPERATE ON TASK FRMWK_RETRY_TASK TO ROLE {{ ami_mat_role }};
GRANT MONITOR           ON TASK FRMWK_RETRY_TASK TO ROLE {{ ami_support_role }};
