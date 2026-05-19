-- 20_dim_meter.sql - DCM DEFINE version of DIM_METER.
-- Same shape as deploy/20_dimensions/20_MeterDim_DDL_v1.0.sql.
-- DCM handles CREATE vs ALTER automatically based on current state.

DEFINE TABLE {{ env_db }}.{{ stage_sch }}.DIM_METER (
    METER_KEY              NUMBER(18,0) NOT NULL,
    METER_SERIAL_NBR       VARCHAR(50)  NOT NULL,
    DEVICE_MFG_NBR         VARCHAR(50),
    SERVICE_POINT_ID       VARCHAR(50),
    METER_TYPE_CD          VARCHAR(20),
    METER_STATUS_CD        VARCHAR(20)  DEFAULT 'ACTIVE',
    INSTALL_DTTM           TIMESTAMP_TZ,
    LAST_READ_DTTM         TIMESTAMP_TZ,
    REGION_CD              VARCHAR(20),
    ACTIVE_IND             BOOLEAN      NOT NULL DEFAULT TRUE,
    CREATE_BY_ID           VARCHAR(200) NOT NULL DEFAULT CURRENT_ROLE(),
    CREATE_DTTM            TIMESTAMP_TZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    UPDATE_BY_ID           VARCHAR(200) NOT NULL DEFAULT CURRENT_ROLE(),
    UPDATE_DTTM            TIMESTAMP_TZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    SUPPLY_VOLTAGE_NOMINAL NUMBER(8,2),
    CONSTRAINT PK_DIM_METER PRIMARY KEY (METER_KEY)
)
COMMENT = 'Meter master. DCM-managed.';

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLE {{ env_db }}.{{ stage_sch }}.DIM_METER TO ROLE {{ ami_mat_role }};
GRANT SELECT ON TABLE {{ env_db }}.{{ stage_sch }}.DIM_METER TO ROLE {{ ami_sel_role }};
