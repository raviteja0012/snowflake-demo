-- Create schemas
USE DATABASE COMMON_DB;

CREATE SCHEMA IF NOT EXISTS FILE_FORMATS
    COMMENT = 'Shared file format definitions';

-- Create a sample file format
CREATE OR REPLACE FILE FORMAT FILE_FORMATS.CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('NULL', 'null')
    EMPTY_FIELD_AS_NULL = TRUE;
