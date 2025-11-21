-- Create products table (no dependencies)
USE DATABASE RAW_DB;
USE SCHEMA PUBLIC;

CREATE TABLE IF NOT EXISTS PRODUCTS (
    product_id NUMBER AUTOINCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    product_category VARCHAR(50),
    unit_price NUMBER(10,2),
    created_date DATE DEFAULT CURRENT_DATE()
);

-- Insert sample data
INSERT INTO PRODUCTS (product_name, product_category, unit_price)
SELECT * FROM VALUES
    ('Software License', 'Software', 500.00),
    ('Cloud Storage', 'Service', 100.00),
    ('Consulting Hours', 'Service', 150.00),
    ('Hardware Device', 'Hardware', 250.00),
    ('Support Plan', 'Service', 200.00);
