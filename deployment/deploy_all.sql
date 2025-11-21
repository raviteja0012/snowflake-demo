-- Master deployment script
-- Executes all scripts in dependency order

-- 1. Common Database
EXECUTE IMMEDIATE FROM '@DEMO_DB.GIT_INTEGRATION.DEMO_REPO/branches/main/databases/COMMON_DB/001_database.sql';
EXECUTE IMMEDIATE FROM '@DEMO_DB.GIT_INTEGRATION.DEMO_REPO/branches/main/databases/COMMON_DB/002_schemas.sql';

-- 2. Raw Database and Tables
EXECUTE IMMEDIATE FROM '@DEMO_DB.GIT_INTEGRATION.DEMO_REPO/branches/main/databases/RAW_DB/001_database.sql';
EXECUTE IMMEDIATE FROM '@DEMO_DB.GIT_INTEGRATION.DEMO_REPO/branches/main/databases/RAW_DB/002_schemas.sql';
EXECUTE IMMEDIATE FROM '@DEMO_DB.GIT_INTEGRATION.DEMO_REPO/branches/main/databases/RAW_DB/tables/001_customers.sql';
EXECUTE IMMEDIATE FROM '@DEMO_DB.GIT_INTEGRATION.DEMO_REPO/branches/main/databases/RAW_DB/tables/002_products.sql';
EXECUTE IMMEDIATE FROM '@DEMO_DB.GIT_INTEGRATION.DEMO_REPO/branches/main/databases/RAW_DB/tables/003_transactions.sql';

-- 3. Analytics Database and Views
EXECUTE IMMEDIATE FROM '@DEMO_DB.GIT_INTEGRATION.DEMO_REPO/branches/main/databases/ANALYTICS_DB/001_database.sql';
EXECUTE IMMEDIATE FROM '@DEMO_DB.GIT_INTEGRATION.DEMO_REPO/branches/main/databases/ANALYTICS_DB/views/001_v_sales_by_customer.sql';

SELECT 'Deployment complete!' as status;
