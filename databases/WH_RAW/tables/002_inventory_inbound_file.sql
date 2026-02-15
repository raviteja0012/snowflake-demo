-- =====================================================
-- RAW: INVENTORY_INBOUND_FILE
-- Stores raw file content from SFTP/Cloud storage drops
-- Sources: Azure Blob, AWS S3, SFTP servers
-- Formats: CSV, XLSX, EDI 856 (ASN), XML
-- =====================================================

USE DATABASE WH_RAW;
USE SCHEMA INBOUND;

CREATE OR REPLACE TABLE INVENTORY_INBOUND_FILE (
    -- Primary identification
    file_id             VARCHAR(100) NOT NULL,

    -- File metadata
    file_name           VARCHAR(500) NOT NULL,
    file_path           VARCHAR(1000),           -- Original location (S3/Blob/SFTP path)
    file_type           VARCHAR(20),             -- CSV, XLSX, EDI, XML
    file_size_bytes     NUMBER(20),
    file_checksum       VARCHAR(64),             -- SHA-256 hash

    -- Source information
    source_location     VARCHAR(50),             -- AZURE_BLOB, AWS_S3, SFTP
    source_container    VARCHAR(255),            -- Bucket or container name
    supplier_id         VARCHAR(50),             -- Extracted from filename convention

    -- Raw content (VARIANT stores parsed content)
    raw_content         VARIANT,                 -- Full file content as VARIANT
    row_count           NUMBER(10),              -- Number of data rows
    column_headers      VARIANT,                 -- Array of column names

    -- Document classification
    document_type       VARCHAR(50),             -- ASN, PO_CONFIRM, INVOICE
    po_number           VARCHAR(50),             -- Extracted PO number if available

    -- Processing status
    processing_status   VARCHAR(50) DEFAULT 'PENDING',  -- PENDING, PROCESSED, FAILED, ARCHIVED
    validation_errors   VARIANT,                 -- Array of validation issues

    -- Timestamps
    file_created_at     TIMESTAMP_NTZ,           -- File creation timestamp
    file_modified_at    TIMESTAMP_NTZ,           -- Last modified timestamp
    detected_at         TIMESTAMP_NTZ,           -- When file was detected
    ingested_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    processed_at        TIMESTAMP_NTZ,
    archived_at         TIMESTAMP_NTZ,
    archive_path        VARCHAR(1000),           -- Path after archiving

    -- Audit
    error_message       VARCHAR(5000),

    CONSTRAINT pk_inbound_file PRIMARY KEY (file_id)
)
COMMENT = 'Raw file content from supplier file drops (CSV, Excel, EDI, XML)';

-- Sequence for file IDs
CREATE OR REPLACE SEQUENCE SEQ_FILE_ID START = 1 INCREMENT = 1;

-- Clustering for performance
ALTER TABLE INVENTORY_INBOUND_FILE CLUSTER BY (ingested_at, processing_status, supplier_id);

-- External stage for Azure Blob (example)
CREATE OR REPLACE STAGE STG_AZURE_INBOUND
    URL = 'azure://wholesalehub.blob.core.windows.net/inbound/'
    COMMENT = 'Azure Blob container for supplier file drops';

-- External stage for AWS S3 (example)
CREATE OR REPLACE STAGE STG_S3_INBOUND
    URL = 's3://wholesalehub-inbound/'
    COMMENT = 'AWS S3 bucket for supplier file drops';

-- File format for CSV files
CREATE OR REPLACE FILE FORMAT FF_CSV_GENERIC
    TYPE = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('NULL', 'null', '')
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- File format for parsing any file as raw
CREATE OR REPLACE FILE FORMAT FF_RAW_TEXT
    TYPE = CSV
    FIELD_DELIMITER = NONE
    RECORD_DELIMITER = NONE;
