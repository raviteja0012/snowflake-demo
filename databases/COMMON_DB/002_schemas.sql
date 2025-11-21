-- Create schemas
USE DATABASE COMMON_DB;

CREATE SCHEMA IF NOT EXISTS FILE_FORMATS
    COMMENT = 'Shared file format definitions';

CREATE SCHEMA IF NOT EXISTS STAGES
    COMMENT = 'External and internal stages';
