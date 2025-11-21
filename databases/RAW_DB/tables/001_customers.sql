-- Create customers table (no dependencies)
USE DATABASE RAW_DB;
USE SCHEMA PUBLIC;

CREATE TABLE IF NOT EXISTS CUSTOMERS (
    customer_id NUMBER AUTOINCREMENT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    customer_email VARCHAR(100),
    customer_segment VARCHAR(50),
    customer_region VARCHAR(50),
    created_date DATE DEFAULT CURRENT_DATE()
);

-- Insert sample data
INSERT INTO CUSTOMERS (customer_name, customer_email, customer_segment, customer_region) 
SELECT * FROM VALUES
    ('Acme Corp', 'contact@acme.com', 'Enterprise', 'North America'),
    ('TechStart Inc', 'info@techstart.com', 'SMB', 'Europe'),
    ('Global Retail', 'sales@globalretail.com', 'Enterprise', 'Asia'),
    ('Local Shop', 'owner@localshop.com', 'SMB', 'North America'),
    ('Digital Services', 'hello@digital.com', 'Mid-Market', 'Europe');
