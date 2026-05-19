--!jinja
-- 50_RetryTask_DDL_v1.0.sql
-- FRMWK_RETRY_TASK - hourly heartbeat. Demo mirror of prod RETRY_VALIDATED_READS_EXCEPTIONS_TSK.
--
-- Ships SUSPENDED. Always. Even on first deploy.
-- Prod rule: tasks never auto-resume on deploy. A misconfigured task firing mid-deploy
-- creates noise that is painful to back out. Ops resumes after validation.

USE SCHEMA {{ frmwk_sch }};

-- Suspend first if it already exists, then CREATE OR REPLACE. Prod pattern.
ALTER TASK IF EXISTS FRMWK_RETRY_TASK SUSPEND;

CREATE OR REPLACE TASK FRMWK_RETRY_TASK
    WAREHOUSE  = {{ wh_name }}
    AUTOCOMMIT = TRUE
    SCHEDULE   = 'USING CRON 0 * * * * UTC'
    COMMENT    = 'Hourly heartbeat. Ships SUSPENDED on every deploy.'
AS
    CALL SP_LOG_DEPLOY('FRMWK_RETRY_TASK', 'HEARTBEAT');

-- Ops resumes after validation:
--   ALTER TASK FRMWK_RETRY_TASK RESUME;

GRANT MONITOR, OPERATE ON TASK FRMWK_RETRY_TASK TO ROLE {{ ami_mat_role }};
GRANT MONITOR           ON TASK FRMWK_RETRY_TASK TO ROLE {{ ami_support_role }};
