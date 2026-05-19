--!jinja
-- =====================================================================
-- 20_MeterDim_DDL_v1.0.sql
--
-- DIM_METER - the meter master.
--
-- Stripped-down mirror of the prod END_DEVICE / METER pattern. Real
-- prod has 30+ cols across SCD2 history and CIM-aligned attributes;
-- this keeps the shape but only what a demo needs.
--
-- CREATE OR ALTER is intentional: reruns add/modify columns without
-- destroying rows. CREATE OR REPLACE would truncate the table.
-- =====================================================================

USE SCHEMA {{ stage_sch }};

CREATE OR ALTER TABLE DIM_METER (
    METER_KEY              NUMBER(18,0)  NOT NULL  COMMENT 'Surrogate key',
    METER_SERIAL_NBR       VARCHAR(50)   NOT NULL  COMMENT 'Vendor meter serial',
    DEVICE_MFG_NBR         VARCHAR(50)             COMMENT 'Manufacturer device id (prod uses this name)',
    SERVICE_POINT_ID       VARCHAR(50)             COMMENT 'Installation location',
    METER_TYPE_CD          VARCHAR(20)             COMMENT 'ELEC, GAS, WATER',
    METER_STATUS_CD        VARCHAR(20)   DEFAULT 'ACTIVE'  COMMENT 'ACTIVE, RETIRED, SUSPENDED',
    INSTALL_DTTM           TIMESTAMP_TZ            COMMENT 'When the meter was placed in service',
    LAST_READ_DTTM         TIMESTAMP_TZ            COMMENT 'Most recent successful read',
    REGION_CD              VARCHAR(20)             COMMENT 'Operating region code',

    -- Standard audit pattern, matches prod MDMS_STG_VALIDATED_READS
    ACTIVE_IND             BOOLEAN       NOT NULL  DEFAULT TRUE,
    CREATE_BY_ID           VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE(),
    CREATE_DTTM            TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP(),
    UPDATE_BY_ID           VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE(),
    UPDATE_DTTM            TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT PK_DIM_METER PRIMARY KEY (METER_KEY)
)
COMMENT = 'Meter master dimension. Demo-scale, prod-shape.';

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE DIM_METER TO ROLE {{ ami_mat_role }};
GRANT SELECT ON TABLE DIM_METER TO ROLE {{ ami_sel_role }};
