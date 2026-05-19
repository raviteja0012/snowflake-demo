--!jinja
---------------------------------------------------------------------
-- Script   : 40_LogDeploySP_DDL_v1.0.sql
-- Purpose  : Demo stored procedure mirroring the prod pattern:
--              - Process id from session + random()
--              - UPDATE_PROCESS_LOGS sink (here: FRAMEWORK.PROCESS_LOG)
--              - STATEMENT_ERROR / EXPRESSION_ERROR / OTHER handlers
--              - Returns 'STATUS|DESC' string
--            Writes one row at start, one row at end of every call.
-- Version  : 1.0
-- Created  : 2026-05-19
---------------------------------------------------------------------

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

    -- Heartbeat row for the component passed in
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
