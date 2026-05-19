--!jinja
---------------------------------------------------------------------
-- Script   : 50_RetryTask_DDL_v1.0.sql
-- Purpose  : Hourly retry task. Demo mirror of prod
--            RETRY_VALIDATED_READS_EXCEPTIONS_TSK.
--            Ships SUSPENDED, ops resumes manually.
-- Version  : 1.0
-- Created  : 2026-05-19
---------------------------------------------------------------------

USE SCHEMA {{ frmwk_sch }};

-- Always SUSPEND before recreate (mirrors prod pattern)
ALTER TASK IF EXISTS FRMWK_RETRY_TASK SUSPEND;

CREATE OR REPLACE TASK FRMWK_RETRY_TASK
    WAREHOUSE  = {{ wh_name }}
    AUTOCOMMIT = TRUE
    SCHEDULE   = 'USING CRON 0 * * * * UTC'
    COMMENT    = 'Hourly heartbeat task. Mirrors prod RETRY_VALIDATED_READS_EXCEPTIONS_TSK pattern.'
AS
    CALL SP_LOG_DEPLOY('FRMWK_RETRY_TASK', 'HEARTBEAT');

-- Task ships SUSPENDED (mirrors prod). Ops resumes when ready.
-- ALTER TASK FRMWK_RETRY_TASK RESUME;

GRANT MONITOR, OPERATE ON TASK FRMWK_RETRY_TASK TO ROLE {{ ami_mat_role }};
GRANT MONITOR           ON TASK FRMWK_RETRY_TASK TO ROLE {{ ami_support_role }};
