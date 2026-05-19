--!jinja
-- =====================================================================
-- 60_FrameworkEmailSeed_DML_v1.0.sql
--
-- Seed rows for EMAIL_BODY_DISPLAY_CONFIG.
-- Idempotent: INSERT...WHERE NOT EXISTS so reruns don't duplicate.
--
-- Direct port of the Validated_Reads_Load_Email_Config_DML prod pattern,
-- scaled to two demo processes (METER_READS_LOAD, METER_READS_RETRY).
-- =====================================================================

USE SCHEMA {{ frmwk_sch }};

INSERT INTO EMAIL_BODY_DISPLAY_CONFIG (PROCESS_NAME, EMAIL_BODY_SECTION, EMAIL_BODY_DISPLAY)
SELECT * FROM (VALUES
    ('METER_READS_LOAD',  'INBOUND_FILES_PROCESSED',  'N'),
    ('METER_READS_LOAD',  'OUTBOUND_FILES_GENERATED', 'N'),
    ('METER_READS_LOAD',  'DATA_PROCESSED',           'Y'),
    ('METER_READS_LOAD',  'TABLES_PROCESSED',         'N'),
    ('METER_READS_LOAD',  'PROCESS_WARNINGS_ERRORS',  'Y'),
    ('METER_READS_LOAD',  'DATA_EXCEPTIONS',          'Y'),
    ('METER_READS_LOAD',  'NOTE',                     'Y'),
    ('METER_READS_RETRY', 'INBOUND_FILES_PROCESSED',  'N'),
    ('METER_READS_RETRY', 'OUTBOUND_FILES_GENERATED', 'N'),
    ('METER_READS_RETRY', 'DATA_PROCESSED',           'Y'),
    ('METER_READS_RETRY', 'TABLES_PROCESSED',         'N'),
    ('METER_READS_RETRY', 'PROCESS_WARNINGS_ERRORS',  'Y'),
    ('METER_READS_RETRY', 'DATA_EXCEPTIONS',          'Y'),
    ('METER_READS_RETRY', 'NOTE',                     'Y')
)
WHERE NOT EXISTS (
    SELECT 'x' FROM EMAIL_BODY_DISPLAY_CONFIG
     WHERE PROCESS_NAME       = COLUMN1
       AND EMAIL_BODY_SECTION = COLUMN2
);
