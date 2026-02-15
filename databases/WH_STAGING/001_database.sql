-- =====================================================
-- WHOLESALE HUB - STAGING DATABASE
-- Transforms and validates raw data before loading to curated
-- =====================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS WH_STAGING
    COMMENT = 'Wholesale Hub STAGING layer - normalized and validated data';

USE DATABASE WH_STAGING;

-- Schema for receipt processing
CREATE SCHEMA IF NOT EXISTS RECEIPTS
    COMMENT = 'Staged inventory receipt data awaiting validation';

-- Schema for error handling
CREATE SCHEMA IF NOT EXISTS ERRORS
    COMMENT = 'Failed validations and parse errors';

-- Schema for lookups during staging
CREATE SCHEMA IF NOT EXISTS LOOKUPS
    COMMENT = 'Reference data for validation';

-- Grant usage to roles
GRANT USAGE ON DATABASE WH_STAGING TO ROLE PUBLIC;
GRANT USAGE ON ALL SCHEMAS IN DATABASE WH_STAGING TO ROLE PUBLIC;
