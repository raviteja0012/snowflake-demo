-- =====================================================
-- CURATED: PURCHASING TABLES
-- Purchase orders and supplier transactions
-- =====================================================

USE DATABASE WH_CURATED;
USE SCHEMA PURCHASING;

-- =====================================================
-- PURCHASE_ORDER - POs sent to suppliers
-- =====================================================
CREATE OR REPLACE TABLE PURCHASE_ORDER (
    po_id               VARCHAR(100) NOT NULL,
    po_number           VARCHAR(50) NOT NULL,    -- Human-readable PO number
    po_date             DATE NOT NULL,

    -- Supplier
    supplier_id         VARCHAR(50) NOT NULL,
    supplier_name       VARCHAR(200),

    -- Warehouse receiving
    warehouse_id        VARCHAR(50),
    warehouse_name      VARCHAR(200),

    -- Ship-to address (if different from warehouse)
    ship_to_name        VARCHAR(200),
    ship_to_address1    VARCHAR(200),
    ship_to_address2    VARCHAR(200),
    ship_to_city        VARCHAR(100),
    ship_to_state       VARCHAR(100),
    ship_to_postal      VARCHAR(20),
    ship_to_country     VARCHAR(3),

    -- Dates
    required_date       DATE,                    -- When we need it
    expected_ship_date  DATE,                    -- When supplier will ship
    expected_arrival    DATE,                    -- When we expect to receive

    -- Totals
    total_lines         NUMBER(5),
    total_quantity      NUMBER(10),
    subtotal            NUMBER(15, 2),
    tax_amount          NUMBER(12, 2),
    shipping_amount     NUMBER(12, 2),
    total_amount        NUMBER(15, 2),
    currency_code       VARCHAR(3) DEFAULT 'USD',

    -- Terms
    payment_terms       VARCHAR(50),
    shipping_method     VARCHAR(100),
    shipping_terms      VARCHAR(50),             -- FOB, CIF, etc.

    -- Status workflow
    po_status           VARCHAR(30) DEFAULT 'DRAFT',
    -- DRAFT, SUBMITTED, CONFIRMED, PARTIAL_SHIP, SHIPPED, PARTIAL_RECV, RECEIVED, CLOSED, CANCELLED

    -- Timestamps
    submitted_at        TIMESTAMP_NTZ,
    confirmed_at        TIMESTAMP_NTZ,
    shipped_at          TIMESTAMP_NTZ,
    received_at         TIMESTAMP_NTZ,
    closed_at           TIMESTAMP_NTZ,
    cancelled_at        TIMESTAMP_NTZ,

    -- Notes
    internal_notes      VARCHAR(2000),
    supplier_notes      VARCHAR(2000),

    -- Audit
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100),

    CONSTRAINT pk_purchase_order PRIMARY KEY (po_id),
    CONSTRAINT uq_po_number UNIQUE (po_number)
)
COMMENT = 'Purchase orders sent to suppliers';

-- Sequence for PO numbers
CREATE OR REPLACE SEQUENCE SEQ_PO_NUMBER START = 10000 INCREMENT = 1;


-- =====================================================
-- PURCHASE_ORDER_LINE - PO line items
-- =====================================================
CREATE OR REPLACE TABLE PURCHASE_ORDER_LINE (
    po_line_id          VARCHAR(100) NOT NULL,
    po_id               VARCHAR(100) NOT NULL,
    line_number         NUMBER(5) NOT NULL,

    -- Product
    product_id          VARCHAR(100),
    sku                 VARCHAR(50),
    supplier_sku        VARCHAR(100),
    product_name        VARCHAR(300),
    description         VARCHAR(500),

    -- Quantities
    qty_ordered         NUMBER(10) NOT NULL,
    qty_confirmed       NUMBER(10),              -- Supplier confirmed qty
    qty_shipped         NUMBER(10) DEFAULT 0,
    qty_received        NUMBER(10) DEFAULT 0,
    qty_cancelled       NUMBER(10) DEFAULT 0,
    qty_open            NUMBER(10) GENERATED ALWAYS AS (qty_ordered - qty_received - qty_cancelled),

    -- Unit of measure
    uom                 VARCHAR(20) DEFAULT 'EA',
    pack_size           NUMBER(5),

    -- Pricing
    unit_cost           NUMBER(12, 4),
    extended_cost       NUMBER(15, 2),
    tax_amount          NUMBER(12, 2),
    line_total          NUMBER(15, 2),
    currency_code       VARCHAR(3) DEFAULT 'USD',

    -- Status
    line_status         VARCHAR(30) DEFAULT 'OPEN',
    -- OPEN, PARTIAL, COMPLETE, CANCELLED

    -- Audit
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT pk_po_line PRIMARY KEY (po_line_id),
    CONSTRAINT fk_pol_po FOREIGN KEY (po_id) REFERENCES PURCHASE_ORDER(po_id)
)
COMMENT = 'Purchase order line items';
