--!jinja
-- =====================================================================
-- 40_LogDeploySP_DDL_v1.0.sql
--
-- SP_LOG_DEPLOY - Snowflake Scripting proc that mirrors the prod
-- exception-handling and PROCESS_LOG-writing pattern.
--
-- Writes a row at start, a heartbeat row for the component passed in,
-- and a completion row. On any error, writes one ERROR row instead of
-- the completion and returns 'ERROR|<sqlcode>:<sqlerrm>' so the caller
-- can decide what to do.
--
-- EXECUTE AS OWNER is intentional: the role calling this proc only
-- needs USAGE on it, not INSERT on PROCESS_LOG. Keeps the logging
-- table locked down to one writer (the proc).
-- =====================================================================

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
    v_Proc_Name    STRING := 'SP_LOG_DEPLOY';
    v_Proc_Status  STRING := 'SUCCESS';
    v_Process_ID   STRING := CURRENT_SESSION() || '.' || UNIFORM(100, 999, RANDOM());
    v_Status_Desc  STRING := 'Process started for ' || COALESCE(:P_PROCESS_NAME, 'unknown');
    v_ReturnStr    STRING := '';
BEGIN
    -- Start row
    INSERT INTO PROCESS_LOG (PROCESS_ID, PROCESS_NAME, COMPONENT, PROC_STATUS, STATUS_DESC)
    VALUES (:v_Process_ID, :P_PROCESS_NAME, 'PROCESS_STARTED', :v_Proc_Status, :v_Status_Desc);

    -- Heartbeat row for the component the caller named
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
        v_ReturnStr := v_Proc_Status || '|' || v_Status_Desc;
        RETURN v_ReturnStr;

    WHEN EXPRESSION_ERROR THEN
        v_Proc_Status := 'ERROR';
        v_Status_Desc := 'EXPRESSION_ERROR ' || sqlcode || ':' || sqlerrm;
        INSERT INTO PROCESS_LOG (PROCESS_ID, PROCESS_NAME, COMPONENT, PROC_STATUS, STATUS_DESC)
        VALUES (:v_Process_ID, :P_PROCESS_NAME, 'PROCESS_COMPLETED', :v_Proc_Status, :v_Status_Desc);
        v_ReturnStr := v_Proc_Status || '|' || v_Status_Desc;
        RETURN v_ReturnStr;

    WHEN OTHER THEN
        v_Proc_Status := 'ERROR';
        v_Status_Desc := 'OTHER ' || sqlcode || ':' || sqlerrm;
        INSERT INTO PROCESS_LOG (PROCESS_ID, PROCESS_NAME, COMPONENT, PROC_STATUS, STATUS_DESC)
        VALUES (:v_Process_ID, :P_PROCESS_NAME, 'PROCESS_COMPLETED', :v_Proc_Status, :v_Status_Desc);
        v_ReturnStr := v_Proc_Status || '|' || v_Status_Desc;
        RETURN v_ReturnStr;
END;
$$;

GRANT USAGE ON PROCEDURE SP_LOG_DEPLOY(VARCHAR, VARCHAR) TO ROLE {{ ami_mat_role }};
GRANT USAGE ON PROCEDURE SP_LOG_DEPLOY(VARCHAR, VARCHAR) TO ROLE {{ ami_support_role }};
