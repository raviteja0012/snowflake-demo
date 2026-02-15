-- =====================================================
-- RAW: INVENTORY_INBOUND_API
-- Stores raw API webhook payloads from suppliers
-- Endpoint: POST /api/v1/inventory/receive/webhook
-- =====================================================

USE DATABASE WH_RAW;
USE SCHEMA INBOUND;

CREATE OR REPLACE TABLE INVENTORY_INBOUND_API (
    -- Primary identification
    api_request_id      VARCHAR(100) NOT NULL,

    -- Request metadata
    supplier_id         VARCHAR(50),             -- From API key mapping
    document_type       VARCHAR(50),             -- ASN, PO_CONFIRM, SHIPMENT_UPDATE
    document_id         VARCHAR(100),            -- Supplier's document ID

    -- Idempotency
    idempotency_key     VARCHAR(255),            -- supplier_id + document_id hash
    is_duplicate        BOOLEAN DEFAULT FALSE,

    -- Authentication
    api_key_id          VARCHAR(100),            -- Which API key was used
    hmac_valid          BOOLEAN,                 -- HMAC signature validated

    -- HTTP request details
    http_method         VARCHAR(10),
    request_path        VARCHAR(500),
    request_headers     VARIANT,                 -- Full HTTP headers
    query_params        VARIANT,                 -- URL query parameters
    source_ip           VARCHAR(45),             -- IPv4 or IPv6

    -- Payload
    raw_payload         VARIANT NOT NULL,        -- Complete JSON payload
    payload_size_bytes  NUMBER(10),

    -- Response
    response_status     NUMBER(3),               -- HTTP status returned
    response_body       VARIANT,                 -- Response we sent

    -- Processing status
    processing_status   VARCHAR(50) DEFAULT 'RECEIVED',  -- RECEIVED, VALIDATED, PROCESSED, REJECTED
    validation_errors   VARIANT,                 -- Array of validation issues

    -- Timestamps
    received_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    validated_at        TIMESTAMP_NTZ,
    processed_at        TIMESTAMP_NTZ,

    -- Error tracking
    error_message       VARCHAR(5000),
    retry_count         NUMBER(3) DEFAULT 0,

    CONSTRAINT pk_inbound_api PRIMARY KEY (api_request_id)
)
COMMENT = 'Raw API webhook payloads from supplier integrations';

-- Sequence for API request IDs
CREATE OR REPLACE SEQUENCE SEQ_API_REQUEST_ID START = 1 INCREMENT = 1;

-- Unique constraint for idempotency
CREATE OR REPLACE UNIQUE INDEX idx_api_idempotency ON INVENTORY_INBOUND_API (idempotency_key);

-- Clustering for performance
ALTER TABLE INVENTORY_INBOUND_API CLUSTER BY (received_at, supplier_id, processing_status);
