--!jinja
---------------------------------------------------------------------
-- Script   : 20_MeterDim_DDL_v1.0.sql
-- Purpose  : Meter dimension. Stripped-down demo mirror of the prod
--            END_DEVICE_IDENTIFICATION / METER master pattern.
-- Version  : 1.0
-- Created  : 2026-05-19
-- Notes    : Uses CREATE OR ALTER so reruns preserve data.
---------------------------------------------------------------------

USE SCHEMA {{ stage_sch }};

CREATE OR ALTER TABLE DIM_METER (
    METER_KEY              NUMBER(18,0)  NOT NULL  COMMENT 'Surrogate key for the meter',
    METER_SERIAL_NBR       VARCHAR(50)   NOT NULL  COMMENT 'Vendor meter serial number',
    DEVICE_MFG_NBR         VARCHAR(50)             COMMENT 'Manufacturer device identifier (mirrors prod DEVICE_MFG_NBR)',
    SERVICE_POINT_ID       VARCHAR(50)             COMMENT 'Service point or installation location identifier',
    METER_TYPE_CD          VARCHAR(20)             COMMENT 'ELEC / GAS / WATER',
    METER_STATUS_CD        VARCHAR(20)   DEFAULT 'ACTIVE'  COMMENT 'ACTIVE / RETIRED / SUSPENDED',
    INSTALL_DTTM           TIMESTAMP_TZ            COMMENT 'When meter was placed in service',
    LAST_READ_DTTM         TIMESTAMP_TZ            COMMENT 'Most recent successful read',
    REGION_CD              VARCHAR(20)             COMMENT 'Operating region',

    -- Audit columns (mirrors prod pattern from MDMS_STG_VALIDATED_READS)
    ACTIVE_IND             BOOLEAN       NOT NULL  DEFAULT TRUE,
    CREATE_BY_ID           VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE()      COMMENT 'Role that created the record',
    CREATE_DTTM            TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP() COMMENT 'Timestamp record created',
    UPDATE_BY_ID           VARCHAR(200)  NOT NULL  DEFAULT CURRENT_ROLE()      COMMENT 'Role that last updated record',
    UPDATE_DTTM            TIMESTAMP_TZ  NOT NULL  DEFAULT CURRENT_TIMESTAMP() COMMENT 'Timestamp record last updated',

    CONSTRAINT PK_DIM_METER PRIMARY KEY (METER_KEY)
)
COMMENT = 'Meter dimension. Demo mirror of the prod AMI END_DEVICE / METER master pattern.';

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE DIM_METER TO ROLE {{ ami_mat_role }};
GRANT SELECT ON TABLE DIM_METER TO ROLE {{ ami_sel_role }};
