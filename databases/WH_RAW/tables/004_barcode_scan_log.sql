-- =====================================================
-- RAW: BARCODE_SCAN_LOG
-- Captures all barcode scan events from mobile app
-- Used for inventory receiving verification
-- =====================================================

USE DATABASE WH_RAW;
USE SCHEMA SCANNING;

CREATE OR REPLACE TABLE BARCODE_SCAN_LOG (
    -- Primary identification
    scan_id             VARCHAR(100) NOT NULL,

    -- Device & user info
    device_id           VARCHAR(100),            -- Mobile device identifier
    user_id             VARCHAR(100),            -- Warehouse staff user ID
    user_name           VARCHAR(200),
    warehouse_id        VARCHAR(50),             -- Which warehouse location

    -- Scan context
    receipt_id          VARCHAR(100),            -- Which receipt being processed
    po_number           VARCHAR(50),             -- Purchase order number
    session_id          VARCHAR(100),            -- Receiving session ID

    -- Barcode data
    barcode_type        VARCHAR(20),             -- UPC, EAN, CODE128, QR, etc.
    barcode_value       VARCHAR(500) NOT NULL,   -- The scanned barcode
    barcode_raw         VARCHAR(1000),           -- Raw scan data if different

    -- Product matching
    matched_product_id  VARCHAR(100),            -- Matched product in master
    matched_sku         VARCHAR(50),
    matched_upc         VARCHAR(50),
    match_confidence    NUMBER(5,2),             -- Match confidence score 0-100
    match_status        VARCHAR(30),             -- EXACT, PARTIAL, NOT_FOUND

    -- Quantity entry
    expected_qty        NUMBER(10),              -- Expected from receipt
    scanned_qty         NUMBER(10),              -- Quantity entered by user
    cumulative_qty      NUMBER(10),              -- Running total for this item

    -- Condition tracking
    item_condition      VARCHAR(30) DEFAULT 'GOOD',  -- GOOD, DAMAGED, WRONG_ITEM, EXPIRED
    condition_notes     VARCHAR(1000),
    photo_paths         VARIANT,                 -- Array of photo evidence paths

    -- Scan metadata
    scan_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    scan_duration_ms    NUMBER(10),              -- Time to complete scan
    scan_attempts       NUMBER(3),               -- Number of scan attempts

    -- GPS/location (optional)
    latitude            NUMBER(10, 7),
    longitude           NUMBER(10, 7),
    location_accuracy   NUMBER(5, 2),

    -- App version
    app_version         VARCHAR(20),
    os_type             VARCHAR(20),             -- iOS, Android
    os_version          VARCHAR(20),

    -- Processing
    sync_status         VARCHAR(30) DEFAULT 'SYNCED',  -- PENDING, SYNCED, FAILED
    server_received_at  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT pk_barcode_scan PRIMARY KEY (scan_id)
)
COMMENT = 'Raw barcode scan events from warehouse mobile receiving app';

-- Sequence for scan IDs (app generates UUID, this is backup)
CREATE OR REPLACE SEQUENCE SEQ_SCAN_ID START = 1 INCREMENT = 1;

-- Clustering for common query patterns
ALTER TABLE BARCODE_SCAN_LOG CLUSTER BY (scan_timestamp, receipt_id, user_id);

-- Create view for quick receipt scan summary
CREATE OR REPLACE VIEW V_SCAN_SUMMARY AS
SELECT
    receipt_id,
    po_number,
    user_id,
    user_name,
    COUNT(DISTINCT scan_id) as total_scans,
    COUNT(DISTINCT matched_sku) as unique_items_scanned,
    SUM(scanned_qty) as total_units_scanned,
    MIN(scan_timestamp) as first_scan,
    MAX(scan_timestamp) as last_scan,
    TIMEDIFF(MINUTE, MIN(scan_timestamp), MAX(scan_timestamp)) as session_duration_min,
    SUM(CASE WHEN item_condition = 'DAMAGED' THEN scanned_qty ELSE 0 END) as damaged_units,
    SUM(CASE WHEN match_status = 'NOT_FOUND' THEN 1 ELSE 0 END) as unmatched_scans
FROM BARCODE_SCAN_LOG
GROUP BY receipt_id, po_number, user_id, user_name;
