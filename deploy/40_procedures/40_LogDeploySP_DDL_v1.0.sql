--!jinja
-- 40_LogDeploySP_DDL_v1.0.sql
-- SP_LOG_DEPLOY - Snowflake Scripting proc.
-- Writes START, COMPONENT, COMPLETED rows to PROCESS_LOG.
-- On error, writes one ERROR row instead of COMPLETED and returns 'ERROR|<sqlcode>:<sqlerrm>'.
--
-- EXECUTE AS OWNER on purpose: caller only needs USAGE on the proc, not INSERT on PROCESS_LOG.
-- Keeps the log table locked down to one writer.

USE SCHEMA {{ frmwk_sch }};

CREATE OR REPLACE PROCEDURE SP_LOG_DEPLOY(
    P_PROCESS_NAME VARCHAR,
    P_COMPONENT    VARCHAR
)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
    v_Proc_Status  STRING := 'SUCCESS';
    v_Process_ID   STRING := CURRENT_SESSION() || '.' || UNIFORM(100, 999, RANDOM());
    v_Status_Desc  STRING := 'Process started for ' || COALESCE(:P_PROCESS_NAME, 'unknown');
    v_ReturnStr    STRING := '';
BEGIN
    -- Start row
    INSERT INTO PROCESS_LOG (PROCESS_ID, PROCESS_NAME, COMPONENT, PROC_STATUS, STATUS_DESC)
    VALUES (:v_Process_ID, :P_PROCESS_NAME, 'PROCESS_STARTED', :v_Proc_Status, :v_Status_Desc);

    -- Heartbeat row for the named component
    v_Status_Desc := 'Component reached: ' || COALESCE(:P_COMPONENT, 'unspecified');
    INSERT INTO PROCESS_LOG (PROCESS_ID, PROCESS_NAME, COMPONENT, PROC_STATUS, STATUS_DESC)
    VALUES (:v_Process_ID, :P_PROCESS_NAME, :P_COMPONENT, :v_Proc_Status, :v_Status_Desc);

    -- Completion row
    v_Status_Desc := 'Process completed';
    INSERT INTO PROCESS_LOG (PROCESS_ID, PROCESS_NAME, COMPONENT, PROC_STATUS, STATUS_DESC)
    VALUES (:v_Process_ID, :P_PROCESS_NAME, 'PROCESS_COMPLETED', :v_Proc_Status, :v_Status_Desc);

    v_ReturnStr := v_Proc_Status || '|' || v_Status_Desc;
    RETURN v_ReturnStr;

EXCEPTION
    WHEN STATEMENT_ERROR THEN
        v_Proc_Status := 'ERROR';
        v_Status_Desc := 'STATEMENT_ERROR ' || sqlcode || ':' || sqlerrm;
        INSERT INTO PROCESS_LOG (PROCESS_ID, PROCESS_NAME, COMPONENT, PROC_STATUS, STATUS_DESC)
        VALUES (:v_Process_ID, :P_PROCESS_NAME, 'PROCESS_COMPLETED', :v_Proc_Status, :v_Status_Desc);
        RETURN v_Proc_Status || '|' || v_Status_Desc;

    WHEN EXPRESSION_ERROR THEN
        v_Proc_Status := 'ERROR';
        v_Status_Desc := 'EXPRESSION_ERROR ' || sqlcode || ':' || sqlerrm;
        INSERT INTO PROCESS_LOG (PROCESS_ID, PROCESS_NAME, COMPONENT, PROC_STATUS, STATUS_DESC)
        VALUES (:v_Process_ID, :P_PROCESS_NAME, 'PROCESS_COMPLETED', :v_Proc_Status, :v_Status_Desc);
        RETURN v_Proc_Status || '|' || v_Status_Desc;

    WHEN OTHER THEN
        v_Proc_Status := 'ERROR';
        v_Status_Desc := 'OTHER ' || sqlcode || ':' || sqlerrm;
        INSERT INTO PROCESS_LOG (PROCESS_ID, PROCESS_NAME, COMPONENT, PROC_STATUS, STATUS_DESC)
        VALUES (:v_Process_ID, :P_PROCESS_NAME, 'PROCESS_COMPLETED', :v_Proc_Status, :v_Status_Desc);
        RETURN v_Proc_Status || '|' || v_Status_Desc;
END;
$$;

GRANT USAGE ON PROCEDURE SP_LOG_DEPLOY(VARCHAR, VARCHAR) TO ROLE {{ ami_mat_role }};
GRANT USAGE ON PROCEDURE SP_LOG_DEPLOY(VARCHAR, VARCHAR) TO ROLE {{ ami_support_role }};
