-- =====================================================
-- WHOLESALE HUB - CURATED DATABASE
-- Production-ready data for business operations
-- =====================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS WH_CURATED
    COMMENT = 'Wholesale Hub CURATED layer - production business data';

USE DATABASE WH_CURATED;

-- Core business entities
CREATE SCHEMA IF NOT EXISTS MASTER
    COMMENT = 'Master data - products, suppliers, customers, warehouses';

-- Inventory operations
CREATE SCHEMA IF NOT EXISTS INVENTORY
    COMMENT = 'Inventory management - receipts, on-hand, transactions';

-- Purchasing
CREATE SCHEMA IF NOT EXISTS PURCHASING
    COMMENT = 'Purchase orders and supplier management';

-- Sales & orders
CREATE SCHEMA IF NOT EXISTS SALES
    COMMENT = 'Customer orders and sales transactions';

-- Reporting aggregates
CREATE SCHEMA IF NOT EXISTS REPORTING
    COMMENT = 'Pre-aggregated data for dashboards and reports';

-- Grant usage to roles
GRANT USAGE ON DATABASE WH_CURATED TO ROLE PUBLIC;
GRANT USAGE ON ALL SCHEMAS IN DATABASE WH_CURATED TO ROLE PUBLIC;
