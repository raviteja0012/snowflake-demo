-- =====================================================
-- CURATED: MASTER DATA TABLES
-- Core reference entities for the Wholesale Hub
-- =====================================================

USE DATABASE WH_CURATED;
USE SCHEMA MASTER;

-- =====================================================
-- SUPPLIER_MASTER - Vendor/supplier information
-- =====================================================
CREATE OR REPLACE TABLE SUPPLIER_MASTER (
    supplier_id         VARCHAR(50) NOT NULL,
    supplier_code       VARCHAR(20),             -- Short code for quick reference
    supplier_name       VARCHAR(200) NOT NULL,
    legal_name          VARCHAR(300),

    -- Contact information
    primary_contact     VARCHAR(200),
    contact_email       VARCHAR(255),
    contact_phone       VARCHAR(30),
    website_url         VARCHAR(500),

    -- Address
    address_line1       VARCHAR(200),
    address_line2       VARCHAR(200),
    city                VARCHAR(100),
    state_province      VARCHAR(100),
    postal_code         VARCHAR(20),
    country_code        VARCHAR(3),

    -- Integration settings
    integration_type    VARCHAR(30),             -- EMAIL, FILE_DROP, API, MANUAL
    api_endpoint        VARCHAR(500),
    file_drop_path      VARCHAR(500),
    email_domain        VARCHAR(100),

    -- Business terms
    payment_terms       VARCHAR(50),             -- NET30, NET60, etc.
    currency_code       VARCHAR(3) DEFAULT 'USD',
    minimum_order       NUMBER(12, 2),
    lead_time_days      NUMBER(3),

    -- Classification
    supplier_type       VARCHAR(50),             -- MANUFACTURER, DISTRIBUTOR, WHOLESALER
    product_categories  VARIANT,                 -- Array of categories supplied
    is_preferred        BOOLEAN DEFAULT FALSE,
    is_active           BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100),

    CONSTRAINT pk_supplier PRIMARY KEY (supplier_id)
)
COMMENT = 'Master list of suppliers and vendors';


-- =====================================================
-- PRODUCT_MASTER - Product catalog
-- =====================================================
CREATE OR REPLACE TABLE PRODUCT_MASTER (
    product_id          VARCHAR(100) NOT NULL,
    sku                 VARCHAR(50) NOT NULL,    -- Internal SKU
    upc                 VARCHAR(50),             -- Universal Product Code
    ean                 VARCHAR(50),             -- European Article Number
    gtin                VARCHAR(50),             -- Global Trade Item Number

    -- Product details
    product_name        VARCHAR(300) NOT NULL,
    short_name          VARCHAR(100),            -- For mobile/compact displays
    description         VARCHAR(2000),

    -- Classification
    category_id         VARCHAR(50),
    category_name       VARCHAR(100),
    subcategory_id      VARCHAR(50),
    subcategory_name    VARCHAR(100),
    brand               VARCHAR(100),
    manufacturer        VARCHAR(200),

    -- Packaging
    unit_of_measure     VARCHAR(20) DEFAULT 'EA', -- EA, CS, PK, BX
    pack_size           NUMBER(5),               -- Units per pack
    case_pack           NUMBER(5),               -- Packs per case
    weight_lbs          NUMBER(10, 3),
    length_in           NUMBER(8, 2),
    width_in            NUMBER(8, 2),
    height_in           NUMBER(8, 2),

    -- Pricing
    standard_cost       NUMBER(12, 4),           -- Average cost
    list_price          NUMBER(12, 2),           -- MSRP
    wholesale_price     NUMBER(12, 2),           -- Default wholesale price
    minimum_price       NUMBER(12, 2),           -- Floor price

    -- Inventory settings
    reorder_point       NUMBER(10),              -- When to reorder
    reorder_quantity    NUMBER(10),              -- How much to reorder
    safety_stock        NUMBER(10),              -- Minimum stock level
    max_stock           NUMBER(10),              -- Maximum inventory

    -- Product attributes (flexible)
    attributes          VARIANT,                 -- JSON for custom attributes
    images              VARIANT,                 -- Array of image URLs
    tags                VARIANT,                 -- Array of searchable tags

    -- Status
    is_active           BOOLEAN DEFAULT TRUE,
    is_sellable         BOOLEAN DEFAULT TRUE,
    is_purchasable      BOOLEAN DEFAULT TRUE,
    is_taxable          BOOLEAN DEFAULT TRUE,
    requires_lot        BOOLEAN DEFAULT FALSE,
    requires_serial     BOOLEAN DEFAULT FALSE,
    is_perishable       BOOLEAN DEFAULT FALSE,
    shelf_life_days     NUMBER(5),

    -- Audit
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100),

    CONSTRAINT pk_product PRIMARY KEY (product_id),
    CONSTRAINT uq_product_sku UNIQUE (sku)
)
COMMENT = 'Master product catalog for Wholesale Hub';

-- Index for barcode lookups
CREATE OR REPLACE INDEX idx_product_upc ON PRODUCT_MASTER (upc);
CREATE OR REPLACE INDEX idx_product_ean ON PRODUCT_MASTER (ean);


-- =====================================================
-- PRODUCT_SUPPLIER - Product-supplier relationships
-- =====================================================
CREATE OR REPLACE TABLE PRODUCT_SUPPLIER (
    product_supplier_id VARCHAR(100) NOT NULL,
    product_id          VARCHAR(100) NOT NULL,
    supplier_id         VARCHAR(50) NOT NULL,

    -- Supplier's identifiers
    supplier_sku        VARCHAR(100),
    supplier_upc        VARCHAR(50),
    supplier_part_no    VARCHAR(100),

    -- Pricing from supplier
    supplier_cost       NUMBER(12, 4),
    currency_code       VARCHAR(3) DEFAULT 'USD',
    effective_date      DATE,
    expiration_date     DATE,

    -- Ordering
    minimum_order_qty   NUMBER(10),
    pack_quantity       NUMBER(10),
    lead_time_days      NUMBER(3),

    -- Preference
    is_primary          BOOLEAN DEFAULT FALSE,   -- Primary supplier for this product
    is_active           BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT pk_product_supplier PRIMARY KEY (product_supplier_id),
    CONSTRAINT fk_ps_product FOREIGN KEY (product_id) REFERENCES PRODUCT_MASTER(product_id),
    CONSTRAINT fk_ps_supplier FOREIGN KEY (supplier_id) REFERENCES SUPPLIER_MASTER(supplier_id)
)
COMMENT = 'Product-supplier relationships and pricing';


-- =====================================================
-- WAREHOUSE_MASTER - Warehouse locations
-- =====================================================
CREATE OR REPLACE TABLE WAREHOUSE_MASTER (
    warehouse_id        VARCHAR(50) NOT NULL,
    warehouse_code      VARCHAR(10),
    warehouse_name      VARCHAR(200) NOT NULL,

    -- Address
    address_line1       VARCHAR(200),
    address_line2       VARCHAR(200),
    city                VARCHAR(100),
    state_province      VARCHAR(100),
    postal_code         VARCHAR(20),
    country_code        VARCHAR(3),

    -- Contact
    manager_name        VARCHAR(200),
    manager_email       VARCHAR(255),
    manager_phone       VARCHAR(30),

    -- Capacity
    total_sqft          NUMBER(10),
    storage_zones       VARIANT,                 -- Array of zone definitions
    receiving_docks     NUMBER(3),
    shipping_docks      NUMBER(3),

    -- Operating hours
    operating_hours     VARIANT,                 -- JSON with daily hours
    timezone            VARCHAR(50),

    -- Status
    is_active           BOOLEAN DEFAULT TRUE,
    can_receive         BOOLEAN DEFAULT TRUE,
    can_ship            BOOLEAN DEFAULT TRUE,

    -- Audit
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT pk_warehouse PRIMARY KEY (warehouse_id)
)
COMMENT = 'Warehouse location master data';


-- =====================================================
-- CUSTOMER_MASTER - Wholesale customers (stores)
-- =====================================================
CREATE OR REPLACE TABLE CUSTOMER_MASTER (
    customer_id         VARCHAR(100) NOT NULL,
    customer_code       VARCHAR(20),
    customer_name       VARCHAR(200) NOT NULL,
    legal_name          VARCHAR(300),

    -- Business type (target market)
    business_type       VARCHAR(50),             -- GAS_STATION, SMOKE_SHOP, CONVENIENCE, etc.

    -- Primary contact
    primary_contact     VARCHAR(200),
    contact_email       VARCHAR(255),
    contact_phone       VARCHAR(30),

    -- Billing address
    billing_address1    VARCHAR(200),
    billing_address2    VARCHAR(200),
    billing_city        VARCHAR(100),
    billing_state       VARCHAR(100),
    billing_postal      VARCHAR(20),
    billing_country     VARCHAR(3),

    -- Shipping address (default)
    shipping_address1   VARCHAR(200),
    shipping_address2   VARCHAR(200),
    shipping_city       VARCHAR(100),
    shipping_state      VARCHAR(100),
    shipping_postal     VARCHAR(20),
    shipping_country    VARCHAR(3),

    -- Business terms
    payment_terms       VARCHAR(50),
    credit_limit        NUMBER(12, 2),
    tax_exempt          BOOLEAN DEFAULT FALSE,
    tax_id              VARCHAR(50),

    -- Pricing tier
    price_tier          VARCHAR(30),             -- STANDARD, PREFERRED, VIP
    discount_pct        NUMBER(5, 2),

    -- Status
    is_active           BOOLEAN DEFAULT TRUE,
    is_approved         BOOLEAN DEFAULT FALSE,
    approved_at         TIMESTAMP_NTZ,
    approved_by         VARCHAR(100),

    -- Audit
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by          VARCHAR(100),
    updated_by          VARCHAR(100),

    CONSTRAINT pk_customer PRIMARY KEY (customer_id)
)
COMMENT = 'Wholesale customer master - gas stations, smoke shops, convenience stores';


-- =====================================================
-- APP_USER - Mobile app and web users
-- =====================================================
CREATE OR REPLACE TABLE APP_USER (
    user_id             VARCHAR(100) NOT NULL,
    username            VARCHAR(100) NOT NULL,
    email               VARCHAR(255),
    phone               VARCHAR(30),

    -- User type
    user_type           VARCHAR(30),             -- WAREHOUSE, SALES, ADMIN, CUSTOMER
    customer_id         VARCHAR(100),            -- If CUSTOMER type
    warehouse_id        VARCHAR(50),             -- If WAREHOUSE type

    -- Profile
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    display_name        VARCHAR(200),
    profile_image_url   VARCHAR(500),
    preferred_language  VARCHAR(10) DEFAULT 'en',

    -- Authentication (external)
    auth_provider       VARCHAR(30),             -- COGNITO, AUTH0, FIREBASE
    auth_id             VARCHAR(255),

    -- Permissions
    roles               VARIANT,                 -- Array of role names
    permissions         VARIANT,                 -- Array of specific permissions

    -- Device info (last known)
    last_device_id      VARCHAR(100),
    last_device_type    VARCHAR(30),
    last_app_version    VARCHAR(20),

    -- Activity
    last_login_at       TIMESTAMP_NTZ,
    login_count         NUMBER(10) DEFAULT 0,

    -- Status
    is_active           BOOLEAN DEFAULT TRUE,
    is_verified         BOOLEAN DEFAULT FALSE,
    verified_at         TIMESTAMP_NTZ,

    -- Audit
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT pk_app_user PRIMARY KEY (user_id),
    CONSTRAINT uq_app_user_username UNIQUE (username)
)
COMMENT = 'Application users - warehouse staff, sales team, customers';
