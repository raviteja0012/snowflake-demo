-- =====================================================
-- MASTER DEPLOYMENT SCRIPT
-- Executes all database objects in dependency order
-- =====================================================

-- Set context
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE DEPLOYMENT_WH;

-- =====================================================
-- PHASE 1: Common Database (existing)
-- =====================================================
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/COMMON_DB/001_database.sql';
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/COMMON_DB/002_schemas.sql';

-- =====================================================
-- PHASE 2: Raw Database Structure (existing)
-- =====================================================
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/RAW_DB/001_database.sql';
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/RAW_DB/002_schemas.sql';

-- Phase 2b: Raw Tables (existing)
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/RAW_DB/tables/001_customers.sql';
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/RAW_DB/tables/002_products.sql';
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/RAW_DB/tables/003_transactions.sql';

-- =====================================================
-- PHASE 3: Analytics Database (existing)
-- =====================================================
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/ANALYTICS_DB/001_database.sql';
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/ANALYTICS_DB/views/001_v_sales_by_customer.sql';

-- =====================================================
-- PHASE 4: WHOLESALE HUB - RAW Database
-- Inbound data from suppliers and barcode scanning
-- =====================================================
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/WH_RAW/001_database.sql';

-- WH_RAW Tables
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/WH_RAW/tables/001_inventory_inbound_email.sql';
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/WH_RAW/tables/002_inventory_inbound_file.sql';
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/WH_RAW/tables/003_inventory_inbound_api.sql';
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/WH_RAW/tables/004_barcode_scan_log.sql';

-- =====================================================
-- PHASE 5: WHOLESALE HUB - STAGING Database
-- Transform and validate inbound data
-- =====================================================
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/WH_STAGING/001_database.sql';

-- WH_STAGING Tables
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/WH_STAGING/tables/001_inventory_receipt_stg.sql';
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/WH_STAGING/tables/002_inventory_receipt_error.sql';

-- =====================================================
-- PHASE 6: WHOLESALE HUB - CURATED Database
-- Production business data
-- =====================================================
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/WH_CURATED/001_database.sql';

-- WH_CURATED Tables (in dependency order)
-- Master data first (no dependencies)
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/WH_CURATED/tables/001_master_data.sql';

-- Purchasing (depends on master data)
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/WH_CURATED/tables/002_purchasing.sql';

-- Inventory (depends on master data and purchasing)
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/WH_CURATED/tables/003_inventory.sql';

-- =====================================================
-- PHASE 7: WHOLESALE HUB - Stored Procedures
-- ETL processing logic
-- =====================================================
EXECUTE IMMEDIATE FROM '@UTIL_DB.GIT_INTEGRATION.SNOWFLAKE_DEMO_REPO/branches/main/databases/WH_CURATED/procedures/001_process_inbound.sql';

-- =====================================================
-- PHASE 8: Log Deployment
-- =====================================================
USE DATABASE UTIL_DB;
USE SCHEMA DEPLOYMENT_LOGS;

INSERT INTO DEPLOYMENT_HISTORY
(BRANCH_NAME, DEPLOYMENT_TYPE, STATUS, ENVIRONMENT, SCRIPTS_DEPLOYED)
VALUES ('main', 'FULL_DEPLOYMENT', 'SUCCESS', 'DEMO',
    ARRAY_CONSTRUCT(
        'COMMON_DB setup',
        'RAW_DB tables',
        'ANALYTICS_DB views',
        'WH_RAW - Inbound channels (email, file, API, barcode)',
        'WH_STAGING - Receipt validation',
        'WH_CURATED - Master data (supplier, product, customer)',
        'WH_CURATED - Purchasing (PO management)',
        'WH_CURATED - Inventory (receipts, on-hand, transactions)',
        'WH_CURATED - ETL Procedures'
    )
);

SELECT 'Deployment completed successfully! Wholesale Hub inventory receiving system deployed.' as STATUS;
