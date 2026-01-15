-- =====================================================
-- STAGING: INVENTORY_RECEIPT_ERROR
-- Captures validation failures and parsing errors
-- =====================================================

USE DATABASE WH_STAGING;
USE SCHEMA ERRORS;

CREATE OR REPLACE TABLE INVENTORY_RECEIPT_ERROR (
    -- Primary identification
    error_id            VARCHAR(100) NOT NULL,

    -- Source reference
    source_type         VARCHAR(20),             -- EMAIL, FILE, API, MANUAL
    source_id           VARCHAR(100),            -- RAW table ID
    receipt_stg_id      VARCHAR(100),            -- STG receipt if created
    line_stg_id         VARCHAR(100),            -- STG line if applicable

    -- Error classification
    error_category      VARCHAR(50) NOT NULL,
    -- PARSE_ERROR, VALIDATION_ERROR, BUSINESS_RULE, DUPLICATE, UNKNOWN_ENTITY
    error_code          VARCHAR(50) NOT NULL,
    error_severity      VARCHAR(20) DEFAULT 'ERROR',  -- WARNING, ERROR, CRITICAL
    error_message       VARCHAR(2000) NOT NULL,

    -- Context
    field_name          VARCHAR(100),            -- Which field caused error
    field_value         VARCHAR(1000),           -- The problematic value
    expected_value      VARCHAR(1000),           -- What was expected
    raw_data            VARIANT,                 -- Relevant raw data snippet

    -- Resolution tracking
    resolution_status   VARCHAR(30) DEFAULT 'OPEN',  -- OPEN, IN_PROGRESS, RESOLVED, IGNORED
    resolution_method   VARCHAR(50),             -- MANUAL_FIX, AUTO_RETRY, SKIPPED
    resolution_notes    VARCHAR(2000),
    resolved_by         VARCHAR(100),
    resolved_at         TIMESTAMP_NTZ,

    -- Reprocessing
    can_retry           BOOLEAN DEFAULT TRUE,
    retry_count         NUMBER(3) DEFAULT 0,
    last_retry_at       TIMESTAMP_NTZ,
    retry_success       BOOLEAN,

    -- Timestamps
    error_timestamp     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT pk_receipt_error PRIMARY KEY (error_id)
)
COMMENT = 'Error log for inventory receipt processing failures';

-- Sequence
CREATE OR REPLACE SEQUENCE SEQ_ERROR_ID START = 1 INCREMENT = 1;

-- Clustering
ALTER TABLE INVENTORY_RECEIPT_ERROR CLUSTER BY (error_timestamp, error_category, resolution_status);

-- Common error codes reference table
CREATE OR REPLACE TABLE ERROR_CODES (
    error_code          VARCHAR(50) NOT NULL PRIMARY KEY,
    error_category      VARCHAR(50),
    error_description   VARCHAR(500),
    suggested_action    VARCHAR(500),
    auto_resolvable     BOOLEAN DEFAULT FALSE
)
COMMENT = 'Reference table of error codes and resolution guidance';

-- Insert common error codes
INSERT INTO ERROR_CODES VALUES
    ('UNKNOWN_SKU', 'VALIDATION_ERROR', 'Product SKU not found in master', 'Create new product or map to existing', FALSE),
    ('UNKNOWN_UPC', 'VALIDATION_ERROR', 'UPC barcode not found in master', 'Update product with UPC or create new', FALSE),
    ('UNKNOWN_SUPPLIER', 'VALIDATION_ERROR', 'Supplier ID not recognized', 'Set up new supplier in master', FALSE),
    ('QTY_MISMATCH', 'BUSINESS_RULE', 'Quantity does not match PO', 'Review and accept variance or dispute', FALSE),
    ('DUPLICATE_DOCUMENT', 'BUSINESS_RULE', 'Document already processed', 'Ignore duplicate submission', TRUE),
    ('PARSE_FAILED', 'PARSE_ERROR', 'Unable to parse document content', 'Check format and retry or manual entry', FALSE),
    ('INVALID_DATE', 'VALIDATION_ERROR', 'Date format not recognized', 'Correct date format', TRUE),
    ('MISSING_PO', 'VALIDATION_ERROR', 'Referenced PO number not found', 'Create PO or correct PO number', FALSE),
    ('INVALID_UOM', 'VALIDATION_ERROR', 'Unit of measure not recognized', 'Map to standard UOM', TRUE),
    ('PRICE_VARIANCE', 'BUSINESS_RULE', 'Unit cost differs from PO', 'Accept new price or dispute', FALSE),
    ('EXPIRED_PRODUCT', 'BUSINESS_RULE', 'Product expiration date passed', 'Reject or accept with approval', FALSE);
