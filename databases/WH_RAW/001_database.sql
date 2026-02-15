-- =====================================================
-- WHOLESALE HUB - RAW DATABASE
-- Stores raw inbound data from all channels
-- Retention: 7 days (transient)
-- =====================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS WH_RAW
    COMMENT = 'Wholesale Hub RAW layer - ingested data from email, files, API, barcode scans';

USE DATABASE WH_RAW;

-- Create schemas for different inbound channels
CREATE SCHEMA IF NOT EXISTS INBOUND
    COMMENT = 'Raw inbound data from suppliers (email, file, API)';

CREATE SCHEMA IF NOT EXISTS SCANNING
    COMMENT = 'Barcode scan events from warehouse mobile app';

CREATE SCHEMA IF NOT EXISTS AUDIT
    COMMENT = 'Audit trail for all raw data ingestion';

-- Grant usage to roles
GRANT USAGE ON DATABASE WH_RAW TO ROLE PUBLIC;
GRANT USAGE ON ALL SCHEMAS IN DATABASE WH_RAW TO ROLE PUBLIC;
