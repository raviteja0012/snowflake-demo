--!jinja
-- =====================================================================
-- 30_MeterReadsFact_DDL_v1.0.sql
--
-- FACT_METER_READS - validated meter reads.
--
-- Demo mirror of prod MDMS_STG_VALIDATED_READS. Real table has more cols
-- around CIM-aligned reading types, quality flags, intervals, and DST
-- handling. This keeps the audit + provenance + DQ flag pattern intact.
-- =====================================================================

USE SCHEMA {{ stage_sch }};

CREATE OR ALTER TABLE FACT_METER_READS (
    READ_ID                NUMBER(38,0)  NOT NULL  COMMENT 'Surrogate key',
    METER_KEY              NUMBER(18,0)  NOT NULL  COMMENT 'FK to DIM_METER',
    DEVICE_MFG_NBR         VARCHAR(50)             COMMENT 'Manufacturer device id at time of read',
    SERVICE_POINT_ID       VARCHAR(50)             COMMENT 'Service point at time of read',

    -- Measurement detail (CIM-aligned names where it matters)
    READING_TYPE_CODE      VARCHAR(50)             COMMENT 'CIM reading type',
    READING_QUALITY_CODE   VARCHAR(50)             COMMENT 'CIM quality code',
    READING_SOURCE_CODE    VARCHAR(50)             COMMENT 'METER, MDMS, IMPORT',
    MEASUREMENT_DATETIME   TIMESTAMP_NTZ           COMMENT 'Read timestamp, naive (no TZ)',
    MEASUREMENT_QUANTITY   NUMBER(18,6)            COMMENT 'Read value',
    DST_FLAG               VARCHAR(1)    DEFAULT '0' COMMENT '1 during DST, 0 standard time',

    -- Where did this row come from
    FILE_NAME              VARCHAR(500)            COMMENT 'Source file name',
    FILE_REC_NUM           NUMBER(38,0)            COMMENT 'Source row number',
    PROCESS_ID             VARCHAR(100)            COMMENT 'Loading process id',

    -- DQ flags (prod pattern)
    DATA_ERROR_IND         VARCHAR(1)    DEFAULT 'N'  COMMENT 'Y if validation failed',
    DATA_QUALITY_ERROR     VARCHAR(500)              COMMENT 'Where the error was found',
    DATA_QUALITY_MESSAGE   VARCHAR(4000)             COMMENT 'Error description',

    -- Audit
    ACTIVE_IND             BOOLEAN       NOT NULL  DEFAULT TRUE,
    CREATE_BY_ID           VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE(),
    CREATE_DTTM            TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP(),
    UPDATE_BY_ID           VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE(),
    UPDATE_DTTM            TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_FACT_METER_READS PRIMARY KEY (READ_ID)
)
COMMENT = 'Validated reads fact. Demo-scale mirror of MDMS_STG_VALIDATED_READS.';

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE FACT_METER_READS TO ROLE {{ ami_mat_role }};
GRANT SELECT ON TABLE FACT_METER_READS TO ROLE {{ ami_sel_role }};
