-- Create sales by customer view (depends on RAW_DB tables)
USE DATABASE ANALYTICS_DB;
CREATE SCHEMA IF NOT EXISTS PUBLIC;
USE SCHEMA PUBLIC;

CREATE OR REPLACE VIEW V_SALES_BY_CUSTOMER AS
SELECT 
    c.customer_name,
    c.customer_segment,
    c.customer_region,
    COUNT(t.transaction_id) as total_transactions,
    SUM(t.amount) as total_revenue,
    AVG(t.amount) as avg_transaction_value,
    MAX(t.transaction_date) as last_transaction_date
FROM RAW_DB.PUBLIC.CUSTOMERS c
LEFT JOIN RAW_DB.PUBLIC.TRANSACTIONS t ON c.customer_id = t.customer_id
GROUP BY c.customer_name, c.customer_segment, c.customer_region;
