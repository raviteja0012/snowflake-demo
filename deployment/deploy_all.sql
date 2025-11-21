-- =====================================================
-- MASTER DEPLOYMENT SCRIPT
-- Executes all database objects in dependency order
-- =====================================================

-- Set context
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE DEPLOYMENT_WH;
USE DATABASE UTIL_DB;
USE SCHEMA GIT_INTEGRATION;

-- Phase 1: Common Database
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_DEMO_REPO/branches/main/databases/COMMON_DB/001_database.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_DEMO_REPO/branches/main/databases/COMMON_DB/002_schemas.sql';

-- Phase 2: Raw Database Structure
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_DEMO_REPO/branches/main/databases/RAW_DB/001_database.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_DEMO_REPO/branches/main/databases/RAW_DB/002_schemas.sql';

-- Phase 3: Raw Tables (in dependency order)
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_DEMO_REPO/branches/main/databases/RAW_DB/tables/001_customers.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_DEMO_REPO/branches/main/databases/RAW_DB/tables/002_products.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_DEMO_REPO/branches/main/databases/RAW_DB/tables/003_transactions.sql';

-- Phase 4: Analytics Database
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_DEMO_REPO/branches/main/databases/ANALYTICS_DB/001_database.sql';

-- Phase 5: Analytics Views (depends on RAW_DB)
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_DEMO_REPO/branches/main/databases/ANALYTICS_DB/views/001_v_sales_by_customer.sql';

-- Log completion
INSERT INTO UTIL_DB.DEPLOYMENT_LOGS.DEPLOYMENT_HISTORY 
(BRANCH_NAME, DEPLOYMENT_TYPE, STATUS, ENVIRONMENT, SCRIPTS_DEPLOYED)
VALUES ('main', 'FULL_DEPLOYMENT', 'SUCCESS', 'DEMO', 
    ARRAY_CONSTRUCT(
        'COMMON_DB setup',
        'RAW_DB tables',
        'ANALYTICS_DB views'
    )
);

SELECT 'Deployment completed successfully!' as STATUS;
