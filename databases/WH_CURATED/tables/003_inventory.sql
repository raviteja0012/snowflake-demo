-- =====================================================
-- CURATED: INVENTORY TABLES
-- Inventory receipts, on-hand, and transactions
-- =====================================================

USE DATABASE WH_CURATED;
USE SCHEMA INVENTORY;

-- =====================================================
-- INVENTORY_RECEIPT - Completed receipts (header)
-- =====================================================
CREATE OR REPLACE TABLE INVENTORY_RECEIPT (
    receipt_id          VARCHAR(100) NOT NULL,
    receipt_number      VARCHAR(50) NOT NULL,    -- Human-readable number
    receipt_date        DATE NOT NULL,

    -- Source document
    source_type         VARCHAR(20),             -- EMAIL, FILE, API, MANUAL
    document_type       VARCHAR(30),             -- ASN, PO_CONFIRM, INVOICE
    document_id         VARCHAR(100),            -- External document reference

    -- Links
    po_id               VARCHAR(100),            -- FK to PURCHASE_ORDER
    po_number           VARCHAR(50),

    -- Supplier
    supplier_id         VARCHAR(50),
    supplier_name       VARCHAR(200),

    -- Warehouse
    warehouse_id        VARCHAR(50) NOT NULL,
    warehouse_name      VARCHAR(200),

    -- Shipping details
    carrier_code        VARCHAR(20),
    carrier_name        VARCHAR(100),
    tracking_number     VARCHAR(100),
    ship_date           DATE,
    delivery_date       DATE,

    -- Totals
    total_lines         NUMBER(5),
    total_qty_expected  NUMBER(10),
    total_qty_received  NUMBER(10),
    total_qty_damaged   NUMBER(10),
    total_value         NUMBER(15, 2),
    currency_code       VARCHAR(3) DEFAULT 'USD',

    -- Variance
    has_variance        BOOLEAN DEFAULT FALSE,
    variance_amount     NUMBER(10),
    variance_value      NUMBER(15, 2),

    -- Status
    receipt_status      VARCHAR(30) DEFAULT 'AWAITING_ARRIVAL',
    -- AWAITING_ARRIVAL, PARTIAL_RECEIVED, FULLY_RECEIVED, CLOSED, DISPUTED

    -- Timestamps
    expected_at         TIMESTAMP_NTZ,
    started_at          TIMESTAMP_NTZ,           -- When receiving started
    completed_at        TIMESTAMP_NTZ,           -- When fully received
    closed_at           TIMESTAMP_NTZ,           -- Finalized

    -- Receiving details
    received_by         VARCHAR(100),
    received_by_name    VARCHAR(200),
    receiving_notes     VARCHAR(2000),

    -- Photos/evidence
    photo_urls          VARIANT,                 -- Array of photo storage paths

    -- Audit
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100),

    CONSTRAINT pk_inventory_receipt PRIMARY KEY (receipt_id),
    CONSTRAINT uq_receipt_number UNIQUE (receipt_number)
)
COMMENT = 'Inventory receipts - completed receiving transactions';

-- Sequence for receipt numbers
CREATE OR REPLACE SEQUENCE SEQ_RECEIPT_NUMBER START = 100000 INCREMENT = 1;


-- =====================================================
-- INVENTORY_RECEIPT_LINE - Receipt line items
-- =====================================================
CREATE OR REPLACE TABLE INVENTORY_RECEIPT_LINE (
    receipt_line_id     VARCHAR(100) NOT NULL,
    receipt_id          VARCHAR(100) NOT NULL,
    line_number         NUMBER(5),

    -- PO reference
    po_line_id          VARCHAR(100),

    -- Product
    product_id          VARCHAR(100),
    sku                 VARCHAR(50),
    upc                 VARCHAR(50),
    product_name        VARCHAR(300),

    -- Quantities
    qty_expected        NUMBER(10),
    qty_received        NUMBER(10) DEFAULT 0,
    qty_damaged         NUMBER(10) DEFAULT 0,
    qty_rejected        NUMBER(10) DEFAULT 0,
    qty_variance        NUMBER(10) GENERATED ALWAYS AS (qty_received - qty_expected),

    -- Unit of measure
    uom                 VARCHAR(20) DEFAULT 'EA',
    pack_size           NUMBER(5),

    -- Pricing
    unit_cost           NUMBER(12, 4),
    extended_cost       NUMBER(15, 2),

    -- Lot tracking
    lot_number          VARCHAR(50),
    serial_numbers      VARIANT,
    expiration_date     DATE,
    manufacture_date    DATE,

    -- Storage location
    storage_location    VARCHAR(50),             -- Bin/slot assigned
    storage_zone        VARCHAR(30),

    -- Condition
    item_condition      VARCHAR(30) DEFAULT 'GOOD',  -- GOOD, DAMAGED, EXPIRED
    condition_notes     VARCHAR(1000),
    damage_photo_urls   VARIANT,

    -- Status
    line_status         VARCHAR(30) DEFAULT 'PENDING',
    -- PENDING, PARTIAL, COMPLETE, VARIANCE

    -- Verification
    verified            BOOLEAN DEFAULT FALSE,
    verified_at         TIMESTAMP_NTZ,
    verified_by         VARCHAR(100),

    -- Audit
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT pk_receipt_line PRIMARY KEY (receipt_line_id),
    CONSTRAINT fk_rl_receipt FOREIGN KEY (receipt_id) REFERENCES INVENTORY_RECEIPT(receipt_id)
)
COMMENT = 'Inventory receipt line items with actual received quantities';


-- =====================================================
-- INVENTORY_ON_HAND - Current stock levels
-- =====================================================
CREATE OR REPLACE TABLE INVENTORY_ON_HAND (
    inventory_id        VARCHAR(100) NOT NULL,

    -- Product
    product_id          VARCHAR(100) NOT NULL,
    sku                 VARCHAR(50),

    -- Location
    warehouse_id        VARCHAR(50) NOT NULL,
    storage_location    VARCHAR(50),             -- Specific bin/slot
    storage_zone        VARCHAR(30),

    -- Quantities
    qty_on_hand         NUMBER(10) DEFAULT 0,    -- Physical inventory
    qty_available       NUMBER(10) DEFAULT 0,    -- Available for sale
    qty_reserved        NUMBER(10) DEFAULT 0,    -- Reserved for orders
    qty_on_order        NUMBER(10) DEFAULT 0,    -- On open POs
    qty_in_transit      NUMBER(10) DEFAULT 0,    -- Shipped but not received

    -- Lot tracking (if applicable)
    lot_number          VARCHAR(50),
    expiration_date     DATE,

    -- Costing
    average_cost        NUMBER(12, 4),
    last_cost           NUMBER(12, 4),
    total_value         NUMBER(15, 2),

    -- Status
    is_active           BOOLEAN DEFAULT TRUE,

    -- Last activity
    last_receipt_date   DATE,
    last_receipt_qty    NUMBER(10),
    last_issue_date     DATE,
    last_issue_qty      NUMBER(10),
    last_count_date     DATE,
    last_count_qty      NUMBER(10),

    -- Audit
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT pk_inventory_on_hand PRIMARY KEY (inventory_id),
    CONSTRAINT uq_product_location UNIQUE (product_id, warehouse_id, storage_location, lot_number)
)
COMMENT = 'Current inventory on hand by product and location';


-- =====================================================
-- INVENTORY_TRANSACTION - All inventory movements (audit)
-- =====================================================
CREATE OR REPLACE TABLE INVENTORY_TRANSACTION (
    transaction_id      VARCHAR(100) NOT NULL,
    transaction_date    DATE NOT NULL,
    transaction_time    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Transaction type
    transaction_type    VARCHAR(30) NOT NULL,
    -- RECEIPT, ISSUE, ADJUSTMENT, TRANSFER, COUNT, RETURN, DAMAGE

    -- Product
    product_id          VARCHAR(100) NOT NULL,
    sku                 VARCHAR(50),
    product_name        VARCHAR(300),

    -- Location
    warehouse_id        VARCHAR(50) NOT NULL,
    from_location       VARCHAR(50),
    to_location         VARCHAR(50),

    -- Quantity
    quantity            NUMBER(10) NOT NULL,     -- Positive = in, Negative = out
    uom                 VARCHAR(20) DEFAULT 'EA',

    -- Running balance
    qty_before          NUMBER(10),
    qty_after           NUMBER(10),

    -- Costing
    unit_cost           NUMBER(12, 4),
    total_value         NUMBER(15, 2),

    -- Reference documents
    reference_type      VARCHAR(30),             -- RECEIPT, ORDER, ADJUSTMENT, etc.
    reference_id        VARCHAR(100),            -- FK to source document
    reference_number    VARCHAR(50),

    -- Lot tracking
    lot_number          VARCHAR(50),
    serial_number       VARCHAR(100),

    -- Reason (for adjustments)
    reason_code         VARCHAR(30),
    reason_description  VARCHAR(200),
    notes               VARCHAR(1000),

    -- User
    created_by          VARCHAR(100),
    created_by_name     VARCHAR(200),

    -- Audit
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT pk_inventory_transaction PRIMARY KEY (transaction_id)
)
COMMENT = 'Complete audit trail of all inventory movements';

-- Sequence for transaction IDs
CREATE OR REPLACE SEQUENCE SEQ_TRANSACTION_ID START = 1 INCREMENT = 1;

-- Clustering for common queries
ALTER TABLE INVENTORY_TRANSACTION CLUSTER BY (transaction_date, product_id, warehouse_id);


-- =====================================================
-- INVENTORY_ALERT - Stock alerts and notifications
-- =====================================================
CREATE OR REPLACE TABLE INVENTORY_ALERT (
    alert_id            VARCHAR(100) NOT NULL,

    -- Alert type
    alert_type          VARCHAR(30) NOT NULL,
    -- LOW_STOCK, OUT_OF_STOCK, EXPIRING, OVERSTOCK, RECEIPT_VARIANCE

    -- Product
    product_id          VARCHAR(100),
    sku                 VARCHAR(50),
    product_name        VARCHAR(300),

    -- Location
    warehouse_id        VARCHAR(50),

    -- Alert details
    alert_message       VARCHAR(500),
    threshold_value     NUMBER(10),
    current_value       NUMBER(10),
    severity            VARCHAR(20),             -- LOW, MEDIUM, HIGH, CRITICAL

    -- Reference
    reference_type      VARCHAR(30),
    reference_id        VARCHAR(100),

    -- Status
    alert_status        VARCHAR(30) DEFAULT 'OPEN',  -- OPEN, ACKNOWLEDGED, RESOLVED
    acknowledged_at     TIMESTAMP_NTZ,
    acknowledged_by     VARCHAR(100),
    resolved_at         TIMESTAMP_NTZ,
    resolved_by         VARCHAR(100),
    resolution_notes    VARCHAR(1000),

    -- Notifications
    notification_sent   BOOLEAN DEFAULT FALSE,
    notification_channels VARIANT,               -- Array: EMAIL, SMS, PUSH

    -- Audit
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT pk_inventory_alert PRIMARY KEY (alert_id)
)
COMMENT = 'Inventory alerts and notifications';
