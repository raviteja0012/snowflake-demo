-- =====================================================
-- STORED PROCEDURES: Inbound Processing
-- ETL procedures for inventory receiving workflow
-- =====================================================

USE DATABASE WH_CURATED;

-- =====================================================
-- SP_PROCESS_INBOUND_FILE
-- Process raw file drops into staging
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_PROCESS_INBOUND_FILE(
    P_FILE_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_result VARIANT;
    v_receipt_stg_id VARCHAR;
    v_supplier_id VARCHAR;
    v_po_number VARCHAR;
    v_row_count INTEGER;
    v_error_count INTEGER DEFAULT 0;
BEGIN
    -- Generate staging receipt ID
    v_receipt_stg_id := 'RCP-STG-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISSFF3');

    -- Get file details
    SELECT supplier_id, po_number
    INTO v_supplier_id, v_po_number
    FROM WH_RAW.INBOUND.INVENTORY_INBOUND_FILE
    WHERE file_id = :P_FILE_ID;

    -- Validate supplier exists
    IF NOT EXISTS (
        SELECT 1 FROM WH_CURATED.MASTER.SUPPLIER_MASTER
        WHERE supplier_id = :v_supplier_id AND is_active = TRUE
    ) THEN
        -- Log error and return
        INSERT INTO WH_STAGING.ERRORS.INVENTORY_RECEIPT_ERROR (
            error_id, source_type, source_id, error_category, error_code,
            error_message, field_name, field_value
        )
        VALUES (
            'ERR-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISSFF3'),
            'FILE', :P_FILE_ID, 'VALIDATION_ERROR', 'UNKNOWN_SUPPLIER',
            'Supplier ID not found in master', 'supplier_id', :v_supplier_id
        );

        UPDATE WH_RAW.INBOUND.INVENTORY_INBOUND_FILE
        SET processing_status = 'FAILED',
            error_message = 'Unknown supplier: ' || :v_supplier_id,
            processed_at = CURRENT_TIMESTAMP()
        WHERE file_id = :P_FILE_ID;

        RETURN OBJECT_CONSTRUCT('status', 'FAILED', 'error', 'UNKNOWN_SUPPLIER');
    END IF;

    -- Create staging receipt header
    INSERT INTO WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_STG (
        receipt_stg_id, source_type, source_id, source_timestamp,
        document_type, supplier_id, supplier_validated, po_number
    )
    SELECT
        :v_receipt_stg_id,
        'FILE',
        :P_FILE_ID,
        ingested_at,
        document_type,
        supplier_id,
        TRUE,
        :v_po_number
    FROM WH_RAW.INBOUND.INVENTORY_INBOUND_FILE
    WHERE file_id = :P_FILE_ID;

    -- Parse file content and create staging lines
    -- This uses the VARIANT raw_content column
    INSERT INTO WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_LINE_STG (
        line_stg_id, receipt_stg_id, line_number,
        sku, upc, product_description, qty_shipped, unit_cost
    )
    SELECT
        'LN-' || :v_receipt_stg_id || '-' || ROW_NUMBER() OVER (ORDER BY seq),
        :v_receipt_stg_id,
        ROW_NUMBER() OVER (ORDER BY seq),
        item.value:SKU::VARCHAR,
        item.value:UPC::VARCHAR,
        item.value:PRODUCT_NAME::VARCHAR,
        item.value:QTY_SHIPPED::NUMBER,
        item.value:UNIT_COST::NUMBER
    FROM WH_RAW.INBOUND.INVENTORY_INBOUND_FILE f,
         LATERAL FLATTEN(input => f.raw_content) item
    WHERE f.file_id = :P_FILE_ID;

    GET_DML_ROW_COUNT INTO v_row_count;

    -- Match products by UPC or SKU
    UPDATE WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_LINE_STG stg
    SET product_id = pm.product_id,
        product_matched = TRUE,
        match_method = CASE WHEN stg.upc = pm.upc THEN 'UPC' ELSE 'SKU' END
    FROM WH_CURATED.MASTER.PRODUCT_MASTER pm
    WHERE stg.receipt_stg_id = :v_receipt_stg_id
      AND (stg.upc = pm.upc OR stg.sku = pm.sku);

    -- Log unmatched products as errors
    INSERT INTO WH_STAGING.ERRORS.INVENTORY_RECEIPT_ERROR (
        error_id, source_type, source_id, receipt_stg_id, line_stg_id,
        error_category, error_code, error_severity, error_message,
        field_name, field_value
    )
    SELECT
        'ERR-' || line_stg_id,
        'FILE', :P_FILE_ID, :v_receipt_stg_id, line_stg_id,
        'VALIDATION_ERROR', 'UNKNOWN_SKU', 'WARNING',
        'Product not found in master - SKU: ' || COALESCE(sku, 'N/A') || ', UPC: ' || COALESCE(upc, 'N/A'),
        'sku', sku
    FROM WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_LINE_STG
    WHERE receipt_stg_id = :v_receipt_stg_id
      AND product_matched = FALSE;

    GET_DML_ROW_COUNT INTO v_error_count;

    -- Update staging header with totals and status
    UPDATE WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_STG
    SET total_line_items = (
            SELECT COUNT(*) FROM WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_LINE_STG
            WHERE receipt_stg_id = :v_receipt_stg_id
        ),
        total_quantity = (
            SELECT SUM(qty_shipped) FROM WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_LINE_STG
            WHERE receipt_stg_id = :v_receipt_stg_id
        ),
        validation_status = CASE WHEN :v_error_count > 0 THEN 'FAILED' ELSE 'PASSED' END,
        receipt_status = CASE WHEN :v_error_count > 0 THEN 'VALIDATION_ERROR' ELSE 'AWAITING_ARRIVAL' END,
        validated_at = CURRENT_TIMESTAMP(),
        updated_at = CURRENT_TIMESTAMP()
    WHERE receipt_stg_id = :v_receipt_stg_id;

    -- Update RAW record
    UPDATE WH_RAW.INBOUND.INVENTORY_INBOUND_FILE
    SET processing_status = 'PROCESSED',
        processed_at = CURRENT_TIMESTAMP()
    WHERE file_id = :P_FILE_ID;

    RETURN OBJECT_CONSTRUCT(
        'status', 'SUCCESS',
        'receipt_stg_id', :v_receipt_stg_id,
        'lines_processed', :v_row_count,
        'errors', :v_error_count
    );
END;
$$;


-- =====================================================
-- SP_PROCESS_INBOUND_API
-- Process API webhook payloads into staging
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_PROCESS_INBOUND_API(
    P_REQUEST_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_result VARIANT;
    v_receipt_stg_id VARCHAR;
    v_payload VARIANT;
    v_supplier_id VARCHAR;
    v_document_id VARCHAR;
    v_po_number VARCHAR;
BEGIN
    -- Generate staging receipt ID
    v_receipt_stg_id := 'RCP-STG-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISSFF3');

    -- Get API payload
    SELECT raw_payload, supplier_id, document_id
    INTO v_payload, v_supplier_id, v_document_id
    FROM WH_RAW.INBOUND.INVENTORY_INBOUND_API
    WHERE api_request_id = :P_REQUEST_ID;

    -- Check for duplicate
    IF EXISTS (
        SELECT 1 FROM WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_STG
        WHERE document_id = :v_document_id AND supplier_id = :v_supplier_id
    ) THEN
        UPDATE WH_RAW.INBOUND.INVENTORY_INBOUND_API
        SET is_duplicate = TRUE,
            processing_status = 'REJECTED',
            processed_at = CURRENT_TIMESTAMP()
        WHERE api_request_id = :P_REQUEST_ID;

        RETURN OBJECT_CONSTRUCT('status', 'DUPLICATE', 'document_id', :v_document_id);
    END IF;

    -- Extract PO number from payload
    v_po_number := v_payload:po_number::VARCHAR;

    -- Create staging receipt header from JSON payload
    INSERT INTO WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_STG (
        receipt_stg_id, source_type, source_id, source_timestamp,
        document_type, document_id, supplier_id, po_number,
        carrier_name, tracking_number, ship_date, expected_delivery
    )
    SELECT
        :v_receipt_stg_id,
        'API',
        :P_REQUEST_ID,
        received_at,
        raw_payload:document_type::VARCHAR,
        raw_payload:document_id::VARCHAR,
        :v_supplier_id,
        :v_po_number,
        raw_payload:carrier::VARCHAR,
        raw_payload:tracking_number::VARCHAR,
        TRY_TO_DATE(raw_payload:ship_date::VARCHAR),
        TRY_TO_DATE(raw_payload:expected_delivery::VARCHAR)
    FROM WH_RAW.INBOUND.INVENTORY_INBOUND_API
    WHERE api_request_id = :P_REQUEST_ID;

    -- Parse line items from JSON array
    INSERT INTO WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_LINE_STG (
        line_stg_id, receipt_stg_id, line_number,
        sku, upc, product_description, qty_shipped, unit_cost
    )
    SELECT
        'LN-' || :v_receipt_stg_id || '-' || item.value:line_number::VARCHAR,
        :v_receipt_stg_id,
        item.value:line_number::NUMBER,
        item.value:sku::VARCHAR,
        item.value:upc::VARCHAR,
        item.value:description::VARCHAR,
        item.value:qty_shipped::NUMBER,
        item.value:unit_cost::NUMBER
    FROM WH_RAW.INBOUND.INVENTORY_INBOUND_API api,
         LATERAL FLATTEN(input => api.raw_payload:line_items) item
    WHERE api.api_request_id = :P_REQUEST_ID;

    -- Match products
    UPDATE WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_LINE_STG stg
    SET product_id = pm.product_id,
        product_matched = TRUE,
        match_method = CASE WHEN stg.upc = pm.upc THEN 'UPC' ELSE 'SKU' END
    FROM WH_CURATED.MASTER.PRODUCT_MASTER pm
    WHERE stg.receipt_stg_id = :v_receipt_stg_id
      AND (stg.upc = pm.upc OR stg.sku = pm.sku);

    -- Update RAW record
    UPDATE WH_RAW.INBOUND.INVENTORY_INBOUND_API
    SET processing_status = 'PROCESSED',
        processed_at = CURRENT_TIMESTAMP()
    WHERE api_request_id = :P_REQUEST_ID;

    RETURN OBJECT_CONSTRUCT(
        'status', 'SUCCESS',
        'receipt_stg_id', :v_receipt_stg_id
    );
END;
$$;


-- =====================================================
-- SP_PROMOTE_RECEIPT_TO_CURATED
-- Move validated staging receipt to curated layer
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_PROMOTE_RECEIPT_TO_CURATED(
    P_RECEIPT_STG_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_receipt_id VARCHAR;
    v_receipt_number VARCHAR;
    v_warehouse_id VARCHAR DEFAULT 'WH-001';  -- Default warehouse
BEGIN
    -- Generate curated receipt ID and number
    v_receipt_id := 'RCP-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISSFF3');
    v_receipt_number := 'REC-' || TO_VARCHAR(WH_CURATED.INVENTORY.SEQ_RECEIPT_NUMBER.NEXTVAL);

    -- Insert into curated receipt
    INSERT INTO WH_CURATED.INVENTORY.INVENTORY_RECEIPT (
        receipt_id, receipt_number, receipt_date,
        source_type, document_type, document_id,
        po_number, supplier_id, warehouse_id,
        carrier_name, tracking_number, ship_date, expected_at,
        total_lines, total_qty_expected, receipt_status,
        created_by
    )
    SELECT
        :v_receipt_id,
        :v_receipt_number,
        CURRENT_DATE(),
        source_type,
        document_type,
        document_id,
        po_number,
        supplier_id,
        :v_warehouse_id,
        carrier_name,
        tracking_number,
        ship_date,
        expected_delivery,
        total_line_items,
        total_quantity,
        'AWAITING_ARRIVAL',
        'SYSTEM'
    FROM WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_STG
    WHERE receipt_stg_id = :P_RECEIPT_STG_ID;

    -- Insert line items into curated
    INSERT INTO WH_CURATED.INVENTORY.INVENTORY_RECEIPT_LINE (
        receipt_line_id, receipt_id, line_number,
        product_id, sku, upc, product_name,
        qty_expected, uom, unit_cost
    )
    SELECT
        'LN-' || :v_receipt_id || '-' || line_number,
        :v_receipt_id,
        line_number,
        product_id,
        sku,
        upc,
        product_description,
        qty_shipped,
        COALESCE(uom, 'EA'),
        unit_cost
    FROM WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_LINE_STG
    WHERE receipt_stg_id = :P_RECEIPT_STG_ID;

    -- Update staging record
    UPDATE WH_STAGING.RECEIPTS.INVENTORY_RECEIPT_STG
    SET receipt_status = 'PROMOTED',
        promoted_at = CURRENT_TIMESTAMP(),
        updated_at = CURRENT_TIMESTAMP()
    WHERE receipt_stg_id = :P_RECEIPT_STG_ID;

    RETURN OBJECT_CONSTRUCT(
        'status', 'SUCCESS',
        'receipt_id', :v_receipt_id,
        'receipt_number', :v_receipt_number
    );
END;
$$;


-- =====================================================
-- SP_RECORD_BARCODE_SCAN
-- Process barcode scan from mobile app
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_RECORD_BARCODE_SCAN(
    P_RECEIPT_ID VARCHAR,
    P_BARCODE VARCHAR,
    P_QUANTITY NUMBER,
    P_CONDITION VARCHAR,
    P_USER_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_product_id VARCHAR;
    v_sku VARCHAR;
    v_match_status VARCHAR DEFAULT 'NOT_FOUND';
    v_line_id VARCHAR;
BEGIN
    -- Try to match barcode to product
    SELECT product_id, sku
    INTO v_product_id, v_sku
    FROM WH_CURATED.MASTER.PRODUCT_MASTER
    WHERE upc = :P_BARCODE OR ean = :P_BARCODE OR sku = :P_BARCODE
    LIMIT 1;

    IF v_product_id IS NOT NULL THEN
        v_match_status := 'EXACT';
    END IF;

    -- Log the scan in RAW
    INSERT INTO WH_RAW.SCANNING.BARCODE_SCAN_LOG (
        scan_id, receipt_id, user_id, barcode_type, barcode_value,
        matched_product_id, matched_sku, match_status,
        scanned_qty, item_condition
    )
    VALUES (
        'SCN-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISSFF3'),
        :P_RECEIPT_ID,
        :P_USER_ID,
        'UPC',
        :P_BARCODE,
        :v_product_id,
        :v_sku,
        :v_match_status,
        :P_QUANTITY,
        :P_CONDITION
    );

    -- Find matching receipt line
    SELECT receipt_line_id INTO v_line_id
    FROM WH_CURATED.INVENTORY.INVENTORY_RECEIPT_LINE
    WHERE receipt_id = :P_RECEIPT_ID
      AND (upc = :P_BARCODE OR sku = :v_sku)
    LIMIT 1;

    -- Update receipt line if found
    IF v_line_id IS NOT NULL THEN
        UPDATE WH_CURATED.INVENTORY.INVENTORY_RECEIPT_LINE
        SET qty_received = qty_received + :P_QUANTITY,
            qty_damaged = CASE WHEN :P_CONDITION = 'DAMAGED' THEN qty_damaged + :P_QUANTITY ELSE qty_damaged END,
            item_condition = CASE WHEN :P_CONDITION = 'DAMAGED' THEN 'DAMAGED' ELSE item_condition END,
            verified = TRUE,
            verified_at = CURRENT_TIMESTAMP(),
            verified_by = :P_USER_ID,
            updated_at = CURRENT_TIMESTAMP()
        WHERE receipt_line_id = :v_line_id;

        -- Update receipt header totals
        UPDATE WH_CURATED.INVENTORY.INVENTORY_RECEIPT
        SET total_qty_received = (
                SELECT SUM(qty_received) FROM WH_CURATED.INVENTORY.INVENTORY_RECEIPT_LINE
                WHERE receipt_id = :P_RECEIPT_ID
            ),
            total_qty_damaged = (
                SELECT SUM(qty_damaged) FROM WH_CURATED.INVENTORY.INVENTORY_RECEIPT_LINE
                WHERE receipt_id = :P_RECEIPT_ID
            ),
            receipt_status = CASE
                WHEN (SELECT SUM(qty_received) FROM WH_CURATED.INVENTORY.INVENTORY_RECEIPT_LINE WHERE receipt_id = :P_RECEIPT_ID) >=
                     (SELECT SUM(qty_expected) FROM WH_CURATED.INVENTORY.INVENTORY_RECEIPT_LINE WHERE receipt_id = :P_RECEIPT_ID)
                THEN 'FULLY_RECEIVED'
                ELSE 'PARTIAL_RECEIVED'
            END,
            received_by = :P_USER_ID,
            updated_at = CURRENT_TIMESTAMP()
        WHERE receipt_id = :P_RECEIPT_ID;

        RETURN OBJECT_CONSTRUCT(
            'status', 'SUCCESS',
            'product_id', :v_product_id,
            'sku', :v_sku,
            'quantity_recorded', :P_QUANTITY
        );
    ELSE
        RETURN OBJECT_CONSTRUCT(
            'status', 'WARNING',
            'message', 'Barcode not found on this receipt',
            'barcode', :P_BARCODE,
            'match_status', :v_match_status
        );
    END IF;
END;
$$;


-- =====================================================
-- SP_COMPLETE_RECEIPT
-- Finalize receipt and update inventory
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_COMPLETE_RECEIPT(
    P_RECEIPT_ID VARCHAR,
    P_USER_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_warehouse_id VARCHAR;
    v_has_variance BOOLEAN DEFAULT FALSE;
BEGIN
    -- Get warehouse
    SELECT warehouse_id INTO v_warehouse_id
    FROM WH_CURATED.INVENTORY.INVENTORY_RECEIPT
    WHERE receipt_id = :P_RECEIPT_ID;

    -- Check for variances
    SELECT TRUE INTO v_has_variance
    FROM WH_CURATED.INVENTORY.INVENTORY_RECEIPT_LINE
    WHERE receipt_id = :P_RECEIPT_ID
      AND qty_variance <> 0
    LIMIT 1;

    -- Update inventory on hand for each line
    MERGE INTO WH_CURATED.INVENTORY.INVENTORY_ON_HAND tgt
    USING (
        SELECT
            product_id,
            sku,
            :v_warehouse_id AS warehouse_id,
            qty_received,
            unit_cost
        FROM WH_CURATED.INVENTORY.INVENTORY_RECEIPT_LINE
        WHERE receipt_id = :P_RECEIPT_ID
          AND qty_received > 0
    ) src
    ON tgt.product_id = src.product_id
       AND tgt.warehouse_id = src.warehouse_id
       AND tgt.lot_number IS NULL
    WHEN MATCHED THEN UPDATE SET
        qty_on_hand = tgt.qty_on_hand + src.qty_received,
        qty_available = tgt.qty_available + src.qty_received,
        last_receipt_date = CURRENT_DATE(),
        last_receipt_qty = src.qty_received,
        last_cost = src.unit_cost,
        updated_at = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        inventory_id, product_id, sku, warehouse_id,
        qty_on_hand, qty_available, last_cost, last_receipt_date, last_receipt_qty
    )
    VALUES (
        'INV-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISSFF3') || '-' || src.product_id,
        src.product_id, src.sku, src.warehouse_id,
        src.qty_received, src.qty_received, src.unit_cost, CURRENT_DATE(), src.qty_received
    );

    -- Create inventory transactions for audit
    INSERT INTO WH_CURATED.INVENTORY.INVENTORY_TRANSACTION (
        transaction_id, transaction_date, transaction_type,
        product_id, sku, warehouse_id, quantity,
        unit_cost, reference_type, reference_id, created_by
    )
    SELECT
        'TXN-' || :P_RECEIPT_ID || '-' || line_number,
        CURRENT_DATE(),
        'RECEIPT',
        product_id,
        sku,
        :v_warehouse_id,
        qty_received,
        unit_cost,
        'RECEIPT',
        :P_RECEIPT_ID,
        :P_USER_ID
    FROM WH_CURATED.INVENTORY.INVENTORY_RECEIPT_LINE
    WHERE receipt_id = :P_RECEIPT_ID
      AND qty_received > 0;

    -- Update receipt status to CLOSED
    UPDATE WH_CURATED.INVENTORY.INVENTORY_RECEIPT
    SET receipt_status = 'CLOSED',
        has_variance = :v_has_variance,
        completed_at = CURRENT_TIMESTAMP(),
        closed_at = CURRENT_TIMESTAMP(),
        updated_at = CURRENT_TIMESTAMP()
    WHERE receipt_id = :P_RECEIPT_ID;

    -- Create alerts for variances
    IF v_has_variance THEN
        INSERT INTO WH_CURATED.INVENTORY.INVENTORY_ALERT (
            alert_id, alert_type, product_id, sku,
            warehouse_id, alert_message, current_value, threshold_value,
            severity, reference_type, reference_id
        )
        SELECT
            'ALT-' || :P_RECEIPT_ID || '-' || line_number,
            'RECEIPT_VARIANCE',
            product_id,
            sku,
            :v_warehouse_id,
            'Receipt variance: Expected ' || qty_expected || ', Received ' || qty_received,
            qty_received,
            qty_expected,
            CASE WHEN ABS(qty_variance) > qty_expected * 0.1 THEN 'HIGH' ELSE 'MEDIUM' END,
            'RECEIPT',
            :P_RECEIPT_ID
        FROM WH_CURATED.INVENTORY.INVENTORY_RECEIPT_LINE
        WHERE receipt_id = :P_RECEIPT_ID
          AND qty_variance <> 0;
    END IF;

    RETURN OBJECT_CONSTRUCT(
        'status', 'SUCCESS',
        'receipt_id', :P_RECEIPT_ID,
        'has_variance', :v_has_variance
    );
END;
$$;
