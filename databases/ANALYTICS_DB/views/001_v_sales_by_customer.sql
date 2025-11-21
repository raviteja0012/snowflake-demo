-- Create sales by customer view (depends on RAW_DB tables)
USE DATABASE ANALYTICS_DB;
CREATE SCHEMA IF NOT EXISTS REPORTS;
USE SCHEMA REPORTS;

CREATE OR REPLACE VIEW V_SALES_BY_CUSTOMER AS
WITH customer_metrics AS (
    SELECT 
        c.customer_name,
        c.customer_segment,
        c.customer_region,
        COUNT(DISTINCT t.transaction_id) as order_count,
        COUNT(DISTINCT t.product_id) as product_variety,
        SUM(t.total_amount) as total_revenue,
        AVG(t.total_amount) as avg_order_size,
        MIN(t.transaction_date) as first_order_date,
        MAX(t.transaction_date) as last_order_date,
        COUNT(DISTINCT DATE_TRUNC('month', t.transaction_date)) as active_months
    FROM RAW_DB.PUBLIC.CUSTOMERS c
    JOIN RAW_DB.PUBLIC.TRANSACTIONS t ON c.customer_id = t.customer_id
    GROUP BY c.customer_name, c.customer_segment, c.customer_region
)
SELECT 
    customer_name,
    customer_segment,
    customer_region,
    order_count,
    product_variety,
    total_revenue,
    avg_order_size,
    ROUND(total_revenue / NULLIF(active_months, 0), 2) as avg_monthly_revenue,
    DATEDIFF(day, first_order_date, last_order_date) as customer_lifetime_days,
    CASE 
        WHEN DATEDIFF(day, last_order_date, CURRENT_DATE()) <= 30 THEN 'Active'
        WHEN DATEDIFF(day, last_order_date, CURRENT_DATE()) <= 90 THEN 'At Risk'
        ELSE 'Churned'
    END as customer_status
FROM customer_metrics
ORDER BY total_revenue DESC;
