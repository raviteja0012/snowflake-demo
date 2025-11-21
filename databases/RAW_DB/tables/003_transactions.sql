-- Create transactions table (depends on customers and products)
USE DATABASE RAW_DB;
USE SCHEMA PUBLIC;

CREATE TABLE IF NOT EXISTS TRANSACTIONS (
    transaction_id NUMBER AUTOINCREMENT PRIMARY KEY,
    customer_id NUMBER NOT NULL,
    product_id NUMBER NOT NULL,
    quantity NUMBER DEFAULT 1,
    amount NUMBER(10,2),
    transaction_date DATE DEFAULT CURRENT_DATE(),
    -- Foreign key constraints ensure dependencies
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) 
        REFERENCES CUSTOMERS(customer_id),
    CONSTRAINT fk_product FOREIGN KEY (product_id) 
        REFERENCES PRODUCTS(product_id)
);

-- Insert sample data
INSERT INTO TRANSACTIONS (customer_id, product_id, quantity, amount)
SELECT 
    c.customer_id,
    p.product_id,
    UNIFORM(1, 10, RANDOM()) as quantity,
    p.unit_price * UNIFORM(1, 10, RANDOM()) as amount
FROM CUSTOMERS c
CROSS JOIN PRODUCTS p
SAMPLE (50); -- Random 50% of combinations
