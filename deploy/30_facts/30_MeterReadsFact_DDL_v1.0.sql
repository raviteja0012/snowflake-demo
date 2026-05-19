--!jinja
-- 30_MeterReadsFact_DDL_v1.0.sql
-- FACT_METER_READS - validated meter reads.
-- Demo mirror of prod MDMS_STG_VALIDATED_READS.
-- Real table has more CIM-aligned reading types, quality flags, intervals, DST handling.
-- This keeps the audit + provenance + DQ flag shape.

USE SCHEMA {{ stage_sch }};

CREATE OR ALTER TABLE FACT_METER_READS (
    READ_ID                NUMBER(38,0) NOT NULL COMMENT 'Surrogate key',
    METER_KEY              NUMBER(18,0) NOT NULL COMMENT 'FK to DIM_METER',
    DEVICE_MFG_NBR         VARCHAR(50),
    SERVICE_POINT_ID       VARCHAR(50),

    -- Measurement detail (CIM-aligned names where it matters)
    READING_TYPE_CODE      VARCHAR(50)           COMMENT 'CIM reading type',
    READING_QUALITY_CODE   VARCHAR(50)           COMMENT 'CIM quality code',
    READING_SOURCE_CODE    VARCHAR(50)           COMMENT 'METER, MDMS, IMPORT',
    MEASUREMENT_DATETIME   TIMESTAMP_NTZ         COMMENT 'Read timestamp, no TZ',
    MEASUREMENT_QUANTITY   NUMBER(18,6),
    DST_FLAG               VARCHAR(1) DEFAULT '0' COMMENT '1 = DST, 0 = standard',

    -- Source provenance
    FILE_NAME              VARCHAR(500),
    FILE_REC_NUM           NUMBER(38,0),
    PROCESS_ID             VARCHAR(100),

    -- DQ flags (prod pattern)
    DATA_ERROR_IND         VARCHAR(1)    DEFAULT 'N' COMMENT 'Y = failed validation',
    DATA_QUALITY_ERROR     VARCHAR(500),
    DATA_QUALITY_MESSAGE   VARCHAR(4000),

    -- Audit
    ACTIVE_IND             BOOLEAN      NOT NULL DEFAULT TRUE,
    CREATE_BY_ID           VARCHAR(200) NOT NULL DEFAULT CURRENT_ROLE(),
    CREATE_DTTM            TIMESTAMP_TZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    UPDATE_BY_ID           VARCHAR(200) NOT NULL DEFAULT CURRENT_ROLE(),
    UPDATE_DTTM            TIMESTAMP_TZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_FACT_METER_READS PRIMARY KEY (READ_ID)
)
COMMENT = 'Validated reads fact. Demo mirror of MDMS_STG_VALIDATED_READS.';

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE FACT_METER_READS TO ROLE {{ ami_mat_role }};
GRANT SELECT ON TABLE FACT_METER_READS TO ROLE {{ ami_sel_role }};
