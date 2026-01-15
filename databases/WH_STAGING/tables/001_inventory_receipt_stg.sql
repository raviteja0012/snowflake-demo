-- =====================================================
-- STAGING: INVENTORY_RECEIPT_STG
-- Normalized receipt header from all inbound channels
-- =====================================================

USE DATABASE WH_STAGING;
USE SCHEMA RECEIPTS;

-- Receipt status enum values
-- PENDING_DOCUMENT, PARSED, VALIDATION_ERROR, AWAITING_ARRIVAL,
-- PARTIAL_RECEIVED, FULLY_RECEIVED, CLOSED, DISPUTED

CREATE OR REPLACE TABLE INVENTORY_RECEIPT_STG (
    -- Primary identification
    receipt_stg_id      VARCHAR(100) NOT NULL,

    -- Source tracking
    source_type         VARCHAR(20) NOT NULL,    -- EMAIL, FILE, API, MANUAL
    source_id           VARCHAR(100),            -- Reference to RAW table ID
    source_timestamp    TIMESTAMP_NTZ,           -- When source was received

    -- Document identification
    document_type       VARCHAR(30),             -- ASN, PO_CONFIRM, INVOICE
    document_id         VARCHAR(100),            -- Supplier's document reference
    document_date       DATE,

    -- Supplier information
    supplier_id         VARCHAR(50),
    supplier_name       VARCHAR(200),
    supplier_validated  BOOLEAN DEFAULT FALSE,

    -- Purchase Order link
    po_number           VARCHAR(50),
    po_id               VARCHAR(100),            -- FK to PURCHASE_ORDER if matched
    po_matched          BOOLEAN DEFAULT FALSE,

    -- Shipping information
    carrier_code        VARCHAR(20),
    carrier_name        VARCHAR(100),
    tracking_number     VARCHAR(100),
    ship_date           DATE,
    expected_delivery   DATE,

    -- Totals (from document)
    total_line_items    NUMBER(5),
    total_quantity      NUMBER(10),
    total_value         NUMBER(15, 2),
    currency_code       VARCHAR(3) DEFAULT 'USD',

    -- Receipt status
    receipt_status      VARCHAR(30) DEFAULT 'PENDING_DOCUMENT',

    -- Validation
    validation_status   VARCHAR(20) DEFAULT 'PENDING',  -- PENDING, PASSED, FAILED
    validation_errors   VARIANT,                 -- Array of error objects
    validation_warnings VARIANT,                 -- Array of warning objects
    validated_at        TIMESTAMP_NTZ,

    -- Warehouse assignment
    warehouse_id        VARCHAR(50),
    assigned_to_user    VARCHAR(100),

    -- Audit timestamps
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    promoted_at         TIMESTAMP_NTZ,           -- When moved to CURATED

    CONSTRAINT pk_receipt_stg PRIMARY KEY (receipt_stg_id)
)
COMMENT = 'Staged inventory receipt headers - normalized from all inbound channels';

-- Sequence for staging IDs
CREATE OR REPLACE SEQUENCE SEQ_RECEIPT_STG_ID START = 1 INCREMENT = 1;

-- Clustering for query performance
ALTER TABLE INVENTORY_RECEIPT_STG CLUSTER BY (created_at, receipt_status, supplier_id);


-- =====================================================
-- STAGING: INVENTORY_RECEIPT_LINE_STG
-- Normalized receipt line items
-- =====================================================

CREATE OR REPLACE TABLE INVENTORY_RECEIPT_LINE_STG (
    -- Primary identification
    line_stg_id         VARCHAR(100) NOT NULL,
    receipt_stg_id      VARCHAR(100) NOT NULL,   -- FK to header

    -- Line item position
    line_number         NUMBER(5),

    -- Product identification (as received)
    sku                 VARCHAR(50),
    upc                 VARCHAR(50),
    ean                 VARCHAR(50),
    supplier_part_no    VARCHAR(100),
    product_description VARCHAR(500),

    -- Product matching
    product_id          VARCHAR(100),            -- Matched to PRODUCT_MASTER
    product_matched     BOOLEAN DEFAULT FALSE,
    match_method        VARCHAR(30),             -- UPC, SKU, DESCRIPTION, MANUAL

    -- Quantities
    qty_ordered         NUMBER(10),              -- Original PO quantity
    qty_shipped         NUMBER(10) NOT NULL,     -- Quantity in this shipment
    qty_expected        NUMBER(10),              -- Expected to receive
    qty_received        NUMBER(10) DEFAULT 0,    -- Actually received (from scanning)
    qty_damaged         NUMBER(10) DEFAULT 0,    -- Damaged units
    qty_variance        NUMBER(10) GENERATED ALWAYS AS (qty_received - qty_shipped),

    -- Unit of measure
    uom                 VARCHAR(20) DEFAULT 'EA', -- EA, CS, PK, BX, etc.
    pack_size           NUMBER(5),               -- Units per case/pack

    -- Pricing
    unit_cost           NUMBER(12, 4),
    extended_cost       NUMBER(15, 2),
    currency_code       VARCHAR(3) DEFAULT 'USD',

    -- Lot/serial tracking (optional)
    lot_number          VARCHAR(50),
    serial_numbers      VARIANT,                 -- Array of serial numbers
    expiration_date     DATE,

    -- Line item status
    line_status         VARCHAR(30) DEFAULT 'PENDING',  -- PENDING, PARTIAL, COMPLETE, VARIANCE

    -- Validation
    validation_status   VARCHAR(20) DEFAULT 'PENDING',
    validation_errors   VARIANT,

    -- Timestamps
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT pk_receipt_line_stg PRIMARY KEY (line_stg_id),
    CONSTRAINT fk_receipt_line_header FOREIGN KEY (receipt_stg_id)
        REFERENCES INVENTORY_RECEIPT_STG(receipt_stg_id)
)
COMMENT = 'Staged inventory receipt line items - normalized product details';

-- Sequence for line staging IDs
CREATE OR REPLACE SEQUENCE SEQ_LINE_STG_ID START = 1 INCREMENT = 1;

-- Clustering
ALTER TABLE INVENTORY_RECEIPT_LINE_STG CLUSTER BY (receipt_stg_id, product_matched);
