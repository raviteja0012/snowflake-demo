-- =====================================================
-- RAW: INVENTORY_INBOUND_EMAIL
-- Stores raw email content from supplier notifications
-- Source: Azure Logic App / AWS SES webhook
-- =====================================================

USE DATABASE WH_RAW;
USE SCHEMA INBOUND;

CREATE OR REPLACE TABLE INVENTORY_INBOUND_EMAIL (
    -- Primary identification
    email_id            VARCHAR(100) NOT NULL,
    message_id          VARCHAR(255),

    -- Email metadata
    from_address        VARCHAR(255),
    to_address          VARCHAR(255),
    subject             VARCHAR(1000),
    received_timestamp  TIMESTAMP_NTZ NOT NULL,

    -- Content (VARIANT for flexibility)
    body_text           VARCHAR(16777216),       -- Plain text body
    body_html           VARCHAR(16777216),       -- HTML body
    attachments         VARIANT,                  -- Array of attachment metadata
    raw_headers         VARIANT,                  -- Full email headers

    -- Attachment storage references
    attachment_paths    VARIANT,                  -- Array of storage paths (Azure Blob/S3)

    -- Processing status
    processing_status   VARCHAR(50) DEFAULT 'PENDING',  -- PENDING, PROCESSED, FAILED
    parsed_document_type VARCHAR(50),            -- PO, ASN, INVOICE, UNKNOWN
    supplier_id         VARCHAR(50),             -- Matched supplier (if identified)

    -- Audit fields
    ingested_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    processed_at        TIMESTAMP_NTZ,
    error_message       VARCHAR(5000),

    -- Constraints
    CONSTRAINT pk_inbound_email PRIMARY KEY (email_id)
)
COMMENT = 'Raw email data from supplier PO confirmations, ASN, and invoices';

-- Create sequence for generating unique IDs
CREATE OR REPLACE SEQUENCE SEQ_EMAIL_ID START = 1 INCREMENT = 1;

-- Index for faster lookups
ALTER TABLE INVENTORY_INBOUND_EMAIL CLUSTER BY (received_timestamp, processing_status);
