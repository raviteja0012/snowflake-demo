---------------------------------------------------------------------
-- Script   : 01_account_setup.sql
-- Purpose  : One-time bootstrap of database, warehouse, schemas, roles, grants
-- Run as   : ACCOUNTADMIN
-- Account  : KEGHDAI-GVA52989 (demo)
-- Created  : 2026-05-19
-- Notes    : Mirrors ami_env_dev.cfg naming so deployment scripts run
--            unchanged against the demo. AMI_DEMO_DB is the only deviation
--            (used instead of DEV_AMI_DEV_DB to make demo isolation obvious).
---------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

-- ===================================================================
-- 1. Database
-- ===================================================================
CREATE DATABASE IF NOT EXISTS AMI_DEMO_DB
    COMMENT = 'AMI native Git integration demo. Mirrors DEV env from ami_env_dev.cfg.';

-- ===================================================================
-- 2. Warehouse (mirrors NONPROD_AMI_ADMIN_WH from prod)
-- ===================================================================
CREATE WAREHOUSE IF NOT EXISTS NONPROD_AMI_ADMIN_WH
    WITH WAREHOUSE_SIZE = 'XSMALL'
         AUTO_SUSPEND = 60
         AUTO_RESUME = TRUE
         INITIALLY_SUSPENDED = TRUE
         COMMENT = 'Demo warehouse. Mirrors NONPROD_AMI_ADMIN_WH from ami_env_dev.cfg.';

-- ===================================================================
-- 3. Schemas (the 8 common AMI schemas relevant for the demo)
-- ===================================================================
USE DATABASE AMI_DEMO_DB;

CREATE SCHEMA IF NOT EXISTS AMICORP    COMMENT = 'Conformed master data (CORP_SCH)';
CREATE SCHEMA IF NOT EXISTS AMICOMM    COMMENT = 'Common reference data (COMM_SCH)';
CREATE SCHEMA IF NOT EXISTS FRAMEWORK  COMMENT = 'Framework, logging, config (FRMWK_SCH)';
CREATE SCHEMA IF NOT EXISTS AMIRPTS    COMMENT = 'Reporting (RPTS_SCH)';
CREATE SCHEMA IF NOT EXISTS AMISTAGE   COMMENT = 'Staging and raw ingest (STAGE_SCH)';
CREATE SCHEMA IF NOT EXISTS XREF       COMMENT = 'Cross-reference (XREF_SCH)';
CREATE SCHEMA IF NOT EXISTS AMICIAP    COMMENT = 'CIAP (CIAP_SCH)';
CREATE SCHEMA IF NOT EXISTS AMIINT     COMMENT = 'Integration (INT_SCH)';

-- Drop the default PUBLIC schema; we use named schemas only
DROP SCHEMA IF EXISTS AMI_DEMO_DB.PUBLIC;

-- ===================================================================
-- 4. Roles (mirrors ami_env_dev.cfg)
-- ===================================================================
CREATE ROLE IF NOT EXISTS DEV_AMI_ADMIN_ROLE
    COMMENT = 'AMI admin role. Owns objects (= RL_NAME in ami_env_dev.cfg).';
CREATE ROLE IF NOT EXISTS DEV_AMI_LOAD_ROLE
    COMMENT = 'AMI loader/materializer (= AMI_MAT_ROLE in ami_env_dev.cfg).';
CREATE ROLE IF NOT EXISTS DEV_AMI_SELECT_ROLE
    COMMENT = 'AMI read-only (= AMI_SEL_ROLE in ami_env_dev.cfg).';
CREATE ROLE IF NOT EXISTS DEV_AMI_MLS_ROLE
    COMMENT = 'AMI masking/MLS consumer (= AMI_MLS_ROLE in ami_env_dev.cfg).';
CREATE ROLE IF NOT EXISTS DEV_AMI_PBI_ROLE
    COMMENT = 'AMI Power BI consumer (= AMI_PBI_ROLE in ami_env_dev.cfg).';
CREATE ROLE IF NOT EXISTS NONPROD_AMI_SUPPORT_ROLE
    COMMENT = 'AMI ops/support monitoring role (= AMI_SUPPORT_ROLE in ami_env_dev.cfg).';

-- Role hierarchy: ADMIN role rolls up to SYSADMIN, functional roles roll up to ADMIN
GRANT ROLE DEV_AMI_ADMIN_ROLE       TO ROLE SYSADMIN;
GRANT ROLE DEV_AMI_LOAD_ROLE        TO ROLE DEV_AMI_ADMIN_ROLE;
GRANT ROLE DEV_AMI_SELECT_ROLE      TO ROLE DEV_AMI_ADMIN_ROLE;
GRANT ROLE DEV_AMI_MLS_ROLE         TO ROLE DEV_AMI_ADMIN_ROLE;
GRANT ROLE DEV_AMI_PBI_ROLE         TO ROLE DEV_AMI_ADMIN_ROLE;
GRANT ROLE NONPROD_AMI_SUPPORT_ROLE TO ROLE SYSADMIN;

-- Grant roles to current user so USE ROLE works without re-login
GRANT ROLE DEV_AMI_ADMIN_ROLE       TO USER RAVITEJA0012;
GRANT ROLE NONPROD_AMI_SUPPORT_ROLE TO USER RAVITEJA0012;

-- ===================================================================
-- 5. Object grants
-- ===================================================================

-- Warehouse usage
GRANT USAGE   ON WAREHOUSE NONPROD_AMI_ADMIN_WH TO ROLE DEV_AMI_ADMIN_ROLE;
GRANT USAGE   ON WAREHOUSE NONPROD_AMI_ADMIN_WH TO ROLE DEV_AMI_LOAD_ROLE;
GRANT USAGE   ON WAREHOUSE NONPROD_AMI_ADMIN_WH TO ROLE DEV_AMI_SELECT_ROLE;
GRANT MONITOR ON WAREHOUSE NONPROD_AMI_ADMIN_WH TO ROLE NONPROD_AMI_SUPPORT_ROLE;

-- Database and schemas are owned by DEV_AMI_ADMIN_ROLE so deploys create objects under it
GRANT OWNERSHIP ON DATABASE AMI_DEMO_DB           TO ROLE DEV_AMI_ADMIN_ROLE COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALL SCHEMAS IN DATABASE AMI_DEMO_DB
    TO ROLE DEV_AMI_ADMIN_ROLE COPY CURRENT GRANTS;

-- Read access for downstream consumer roles
GRANT USAGE ON DATABASE AMI_DEMO_DB TO ROLE DEV_AMI_LOAD_ROLE;
GRANT USAGE ON DATABASE AMI_DEMO_DB TO ROLE DEV_AMI_SELECT_ROLE;
GRANT USAGE ON DATABASE AMI_DEMO_DB TO ROLE DEV_AMI_MLS_ROLE;
GRANT USAGE ON DATABASE AMI_DEMO_DB TO ROLE DEV_AMI_PBI_ROLE;
GRANT USAGE ON DATABASE AMI_DEMO_DB TO ROLE NONPROD_AMI_SUPPORT_ROLE;

GRANT USAGE ON ALL SCHEMAS IN DATABASE AMI_DEMO_DB    TO ROLE DEV_AMI_LOAD_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE AMI_DEMO_DB    TO ROLE DEV_AMI_SELECT_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE AMI_DEMO_DB    TO ROLE NONPROD_AMI_SUPPORT_ROLE;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE AMI_DEMO_DB TO ROLE DEV_AMI_LOAD_ROLE;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE AMI_DEMO_DB TO ROLE DEV_AMI_SELECT_ROLE;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE AMI_DEMO_DB TO ROLE NONPROD_AMI_SUPPORT_ROLE;

-- ===================================================================
-- 6. Verification
-- ===================================================================
SHOW WAREHOUSES LIKE 'NONPROD_AMI_ADMIN_WH';
SHOW DATABASES LIKE 'AMI_DEMO_DB';
SHOW SCHEMAS IN DATABASE AMI_DEMO_DB;
