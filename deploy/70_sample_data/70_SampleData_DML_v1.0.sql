--!jinja
-- =====================================================================
-- 70_SampleData_DML_v1.0.sql
--
-- Tiny generic sample data so the demo has something to query after
-- deploy. Eight meters, 24 reads (three per meter spanning three hours).
--
-- Idempotent: MERGE on the natural keys so reruns don't duplicate and
-- don't lose updates if the seed values change.
--
-- This is demo data only. Real loads come through the
-- Validated_Reads_Load_SP / Snowpipe path in prod.
-- =====================================================================

USE SCHEMA {{ stage_sch }};

-- ---------------------------------------------------------------------
-- DIM_METER: 8 meters across 4 service points, mixed types and regions
-- ---------------------------------------------------------------------
MERGE INTO DIM_METER tgt USING (
    SELECT * FROM (VALUES
        (1001, 'MTR-1001', 'MFG-A1001', 'SP-001', 'ELEC', 'ACTIVE',  '2023-01-15 00:00:00'::TIMESTAMP_TZ, 'NORTH'),
        (1002, 'MTR-1002', 'MFG-A1002', 'SP-001', 'GAS',  'ACTIVE',  '2023-01-15 00:00:00'::TIMESTAMP_TZ, 'NORTH'),
        (1003, 'MTR-1003', 'MFG-B2003', 'SP-002', 'ELEC', 'ACTIVE',  '2023-04-22 00:00:00'::TIMESTAMP_TZ, 'NORTH'),
        (1004, 'MTR-1004', 'MFG-B2004', 'SP-002', 'WATER','ACTIVE',  '2023-04-22 00:00:00'::TIMESTAMP_TZ, 'NORTH'),
        (1005, 'MTR-1005', 'MFG-C3005', 'SP-003', 'ELEC', 'ACTIVE',  '2024-02-10 00:00:00'::TIMESTAMP_TZ, 'SOUTH'),
        (1006, 'MTR-1006', 'MFG-C3006', 'SP-003', 'GAS',  'SUSPENDED','2024-02-10 00:00:00'::TIMESTAMP_TZ, 'SOUTH'),
        (1007, 'MTR-1007', 'MFG-D4007', 'SP-004', 'ELEC', 'ACTIVE',  '2024-09-05 00:00:00'::TIMESTAMP_TZ, 'WEST'),
        (1008, 'MTR-1008', 'MFG-D4008', 'SP-004', 'WATER','RETIRED', '2024-09-05 00:00:00'::TIMESTAMP_TZ, 'WEST')
    ) AS s(METER_KEY, METER_SERIAL_NBR, DEVICE_MFG_NBR, SERVICE_POINT_ID, METER_TYPE_CD, METER_STATUS_CD, INSTALL_DTTM, REGION_CD)
) src ON tgt.METER_KEY = src.METER_KEY
WHEN MATCHED THEN UPDATE SET
    METER_SERIAL_NBR = src.METER_SERIAL_NBR,
    DEVICE_MFG_NBR   = src.DEVICE_MFG_NBR,
    SERVICE_POINT_ID = src.SERVICE_POINT_ID,
    METER_TYPE_CD    = src.METER_TYPE_CD,
    METER_STATUS_CD  = src.METER_STATUS_CD,
    INSTALL_DTTM     = src.INSTALL_DTTM,
    REGION_CD        = src.REGION_CD,
    UPDATE_BY_ID     = CURRENT_ROLE(),
    UPDATE_DTTM      = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    METER_KEY, METER_SERIAL_NBR, DEVICE_MFG_NBR, SERVICE_POINT_ID,
    METER_TYPE_CD, METER_STATUS_CD, INSTALL_DTTM, REGION_CD
)
VALUES (
    src.METER_KEY, src.METER_SERIAL_NBR, src.DEVICE_MFG_NBR, src.SERVICE_POINT_ID,
    src.METER_TYPE_CD, src.METER_STATUS_CD, src.INSTALL_DTTM, src.REGION_CD
);

-- ---------------------------------------------------------------------
-- FACT_METER_READS: 3 reads per meter at 06:00, 07:00, 08:00 UTC
-- ---------------------------------------------------------------------
MERGE INTO FACT_METER_READS tgt USING (
    SELECT * FROM (VALUES
        -- meter 1001 (ELEC) - kWh values rising through the morning
        (90001, 1001, 'MFG-A1001', 'SP-001', 'ENERGY_KWH',    'VALID',  'METER', '2026-05-19 06:00:00'::TIMESTAMP_NTZ,  142.500000, 'sample_2026-05-19.csv',  1),
        (90002, 1001, 'MFG-A1001', 'SP-001', 'ENERGY_KWH',    'VALID',  'METER', '2026-05-19 07:00:00'::TIMESTAMP_NTZ,  148.700000, 'sample_2026-05-19.csv',  2),
        (90003, 1001, 'MFG-A1001', 'SP-001', 'ENERGY_KWH',    'VALID',  'METER', '2026-05-19 08:00:00'::TIMESTAMP_NTZ,  155.200000, 'sample_2026-05-19.csv',  3),
        -- meter 1002 (GAS) - therms
        (90004, 1002, 'MFG-A1002', 'SP-001', 'GAS_THERMS',    'VALID',  'METER', '2026-05-19 06:00:00'::TIMESTAMP_NTZ,   12.300000, 'sample_2026-05-19.csv',  4),
        (90005, 1002, 'MFG-A1002', 'SP-001', 'GAS_THERMS',    'VALID',  'METER', '2026-05-19 07:00:00'::TIMESTAMP_NTZ,   12.450000, 'sample_2026-05-19.csv',  5),
        (90006, 1002, 'MFG-A1002', 'SP-001', 'GAS_THERMS',    'VALID',  'METER', '2026-05-19 08:00:00'::TIMESTAMP_NTZ,   12.600000, 'sample_2026-05-19.csv',  6),
        -- meter 1003 (ELEC)
        (90007, 1003, 'MFG-B2003', 'SP-002', 'ENERGY_KWH',    'VALID',  'METER', '2026-05-19 06:00:00'::TIMESTAMP_NTZ,  205.100000, 'sample_2026-05-19.csv',  7),
        (90008, 1003, 'MFG-B2003', 'SP-002', 'ENERGY_KWH',    'VALID',  'METER', '2026-05-19 07:00:00'::TIMESTAMP_NTZ,  211.400000, 'sample_2026-05-19.csv',  8),
        (90009, 1003, 'MFG-B2003', 'SP-002', 'ENERGY_KWH',    'VALID',  'METER', '2026-05-19 08:00:00'::TIMESTAMP_NTZ,  218.900000, 'sample_2026-05-19.csv',  9),
        -- meter 1004 (WATER) - gallons
        (90010, 1004, 'MFG-B2004', 'SP-002', 'WATER_GAL',     'VALID',  'METER', '2026-05-19 06:00:00'::TIMESTAMP_NTZ,   45.000000, 'sample_2026-05-19.csv', 10),
        (90011, 1004, 'MFG-B2004', 'SP-002', 'WATER_GAL',     'VALID',  'METER', '2026-05-19 07:00:00'::TIMESTAMP_NTZ,   47.200000, 'sample_2026-05-19.csv', 11),
        (90012, 1004, 'MFG-B2004', 'SP-002', 'WATER_GAL',     'VALID',  'METER', '2026-05-19 08:00:00'::TIMESTAMP_NTZ,   49.100000, 'sample_2026-05-19.csv', 12),
        -- meter 1005 (ELEC) - one read with a DQ error to show the flag pattern
        (90013, 1005, 'MFG-C3005', 'SP-003', 'ENERGY_KWH',    'VALID',  'METER', '2026-05-19 06:00:00'::TIMESTAMP_NTZ,   88.300000, 'sample_2026-05-19.csv', 13),
        (90014, 1005, 'MFG-C3005', 'SP-003', 'ENERGY_KWH',    'SUSPECT','METER', '2026-05-19 07:00:00'::TIMESTAMP_NTZ,    0.000000, 'sample_2026-05-19.csv', 14),
        (90015, 1005, 'MFG-C3005', 'SP-003', 'ENERGY_KWH',    'VALID',  'METER', '2026-05-19 08:00:00'::TIMESTAMP_NTZ,   95.700000, 'sample_2026-05-19.csv', 15),
        -- meter 1006 (GAS) - SUSPENDED meter, still gets reads via MDMS catch-up
        (90016, 1006, 'MFG-C3006', 'SP-003', 'GAS_THERMS',    'VALID',  'MDMS',  '2026-05-19 06:00:00'::TIMESTAMP_NTZ,    8.100000, 'sample_2026-05-19.csv', 16),
        (90017, 1006, 'MFG-C3006', 'SP-003', 'GAS_THERMS',    'VALID',  'MDMS',  '2026-05-19 07:00:00'::TIMESTAMP_NTZ,    8.250000, 'sample_2026-05-19.csv', 17),
        (90018, 1006, 'MFG-C3006', 'SP-003', 'GAS_THERMS',    'VALID',  'MDMS',  '2026-05-19 08:00:00'::TIMESTAMP_NTZ,    8.400000, 'sample_2026-05-19.csv', 18),
        -- meter 1007 (ELEC)
        (90019, 1007, 'MFG-D4007', 'SP-004', 'ENERGY_KWH',    'VALID',  'METER', '2026-05-19 06:00:00'::TIMESTAMP_NTZ,  178.600000, 'sample_2026-05-19.csv', 19),
        (90020, 1007, 'MFG-D4007', 'SP-004', 'ENERGY_KWH',    'VALID',  'METER', '2026-05-19 07:00:00'::TIMESTAMP_NTZ,  184.200000, 'sample_2026-05-19.csv', 20),
        (90021, 1007, 'MFG-D4007', 'SP-004', 'ENERGY_KWH',    'VALID',  'METER', '2026-05-19 08:00:00'::TIMESTAMP_NTZ,  190.500000, 'sample_2026-05-19.csv', 21),
        -- meter 1008 (WATER) - RETIRED, historical reads only
        (90022, 1008, 'MFG-D4008', 'SP-004', 'WATER_GAL',     'VALID',  'IMPORT','2024-08-01 06:00:00'::TIMESTAMP_NTZ,   30.000000, 'sample_2024-08-01.csv',  1),
        (90023, 1008, 'MFG-D4008', 'SP-004', 'WATER_GAL',     'VALID',  'IMPORT','2024-08-01 07:00:00'::TIMESTAMP_NTZ,   31.200000, 'sample_2024-08-01.csv',  2),
        (90024, 1008, 'MFG-D4008', 'SP-004', 'WATER_GAL',     'VALID',  'IMPORT','2024-08-01 08:00:00'::TIMESTAMP_NTZ,   32.500000, 'sample_2024-08-01.csv',  3)
    ) AS s(READ_ID, METER_KEY, DEVICE_MFG_NBR, SERVICE_POINT_ID, READING_TYPE_CODE,
           READING_QUALITY_CODE, READING_SOURCE_CODE, MEASUREMENT_DATETIME,
           MEASUREMENT_QUANTITY, FILE_NAME, FILE_REC_NUM)
) src ON tgt.READ_ID = src.READ_ID
WHEN MATCHED THEN UPDATE SET
    METER_KEY            = src.METER_KEY,
    DEVICE_MFG_NBR       = src.DEVICE_MFG_NBR,
    SERVICE_POINT_ID     = src.SERVICE_POINT_ID,
    READING_TYPE_CODE    = src.READING_TYPE_CODE,
    READING_QUALITY_CODE = src.READING_QUALITY_CODE,
    READING_SOURCE_CODE  = src.READING_SOURCE_CODE,
    MEASUREMENT_DATETIME = src.MEASUREMENT_DATETIME,
    MEASUREMENT_QUANTITY = src.MEASUREMENT_QUANTITY,
    FILE_NAME            = src.FILE_NAME,
    FILE_REC_NUM         = src.FILE_REC_NUM,
    UPDATE_BY_ID         = CURRENT_ROLE(),
    UPDATE_DTTM          = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    READ_ID, METER_KEY, DEVICE_MFG_NBR, SERVICE_POINT_ID,
    READING_TYPE_CODE, READING_QUALITY_CODE, READING_SOURCE_CODE,
    MEASUREMENT_DATETIME, MEASUREMENT_QUANTITY, FILE_NAME, FILE_REC_NUM
) VALUES (
    src.READ_ID, src.METER_KEY, src.DEVICE_MFG_NBR, src.SERVICE_POINT_ID,
    src.READING_TYPE_CODE, src.READING_QUALITY_CODE, src.READING_SOURCE_CODE,
    src.MEASUREMENT_DATETIME, src.MEASUREMENT_QUANTITY, src.FILE_NAME, src.FILE_REC_NUM
);
