--!jinja
---------------------------------------------------------------------
-- Script   : 30_MeterReadsFact_DDL_v1.0.sql
-- Purpose  : Validated reads fact. Stripped-down demo mirror of
--            MDMS_STG_VALIDATED_READS from the prod codebase.
-- Version  : 1.0
-- Created  : 2026-05-19
-- Notes    : Uses CREATE OR ALTER so reruns preserve data.
---------------------------------------------------------------------

USE SCHEMA {{ stage_sch }};

CREATE OR ALTER TABLE FACT_METER_READS (
    READ_ID                NUMBER(38,0)  NOT NULL  COMMENT 'Surrogate key for the read',
    METER_KEY              NUMBER(18,0)  NOT NULL  COMMENT 'FK to DIM_METER',
    DEVICE_MFG_NBR         VARCHAR(50)             COMMENT 'Manufacturer device id at read time',
    SERVICE_POINT_ID       VARCHAR(50)             COMMENT 'Service point at read time',

    -- Measurement detail (mirrors prod naming)
    READING_TYPE_CODE      VARCHAR(50)             COMMENT 'Type of measurement (CIM code)',
    READING_QUALITY_CODE   VARCHAR(50)             COMMENT 'Quality of measurement (CIM code)',
    READING_SOURCE_CODE    VARCHAR(50)             COMMENT 'Source (METER / MDMS / IMPORT)',
    MEASUREMENT_DATETIME   TIMESTAMP_NTZ           COMMENT 'Read timestamp, no timezone',
    MEASUREMENT_QUANTITY   NUMBER(18,6)            COMMENT 'Measurement value',
    DST_FLAG               VARCHAR(1)    DEFAULT '0' COMMENT '1 = during DST, 0 = standard time',

    -- Provenance
    FILE_NAME              VARCHAR(500)            COMMENT 'Source file name',
    FILE_REC_NUM           NUMBER(38,0)            COMMENT 'Source file row number',
    PROCESS_ID             VARCHAR(100)            COMMENT 'Process id that loaded the row',

    -- Data quality flags (mirrors prod pattern)
    DATA_ERROR_IND         VARCHAR(1)    DEFAULT 'N'  COMMENT 'Y if row failed validation',
    DATA_QUALITY_ERROR     VARCHAR(500)              COMMENT 'Where the error was found',
    DATA_QUALITY_MESSAGE   VARCHAR(4000)             COMMENT 'Error description',

    -- Audit
    ACTIVE_IND             BOOLEAN       NOT NULL  DEFAULT TRUE,
    CREATE_BY_ID           VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE()      COMMENT 'Role that created the record',
    CREATE_DTTM            TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP() COMMENT 'Timestamp record created',
    UPDATE_BY_ID           VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE()      COMMENT 'Role that last updated record',
    UPDATE_DTTM            TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP() COMMENT 'Timestamp record last updated',

    CONSTRAINT PK_FACT_METER_READS PRIMARY KEY (READ_ID)
)
COMMENT = 'Validated meter reads fact. Demo mirror of MDMS_STG_VALIDATED_READS.';

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE FACT_METER_READS TO ROLE {{ ami_mat_role }};
GRANT SELECT ON TABLE FACT_METER_READS TO ROLE {{ ami_sel_role }};
