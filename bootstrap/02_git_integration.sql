---------------------------------------------------------------------
-- Script   : 02_git_integration.sql
-- Purpose  : Create the Snowflake-side objects that pull from GitHub
-- Run as   : ACCOUNTADMIN
-- Account  : KEGHDAI-GVA52989 (demo)
-- Repo     : https://github.com/raviteja0012/snowflake-demo
-- Created  : 2026-05-19
-- Notes    : PAT is hardcoded below. Expires Aug 17, 2026.
--            Rotate with: ALTER SECRET ... SET PASSWORD = 'github_pat_new';
--            Re-generate at https://github.com/settings/personal-access-tokens/new
---------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;
USE DATABASE AMI_DEMO_DB;

-- ===================================================================
-- 1. Home schema for ops objects (separate from data schemas)
-- ===================================================================
CREATE SCHEMA IF NOT EXISTS AMI_DEMO_DB.GIT_OPS
    COMMENT = 'Holds the secret, API integration handle, and GIT REPOSITORY object';

-- Ownership stays with ACCOUNTADMIN here; the deployer role only needs
-- USAGE on the secret/integration and READ on the repo (granted below).

-- ===================================================================
-- 2. GitHub Personal Access Token, stored as a Snowflake SECRET
--    The password is encrypted on creation; DESCRIBE never shows it.
-- ===================================================================
CREATE OR REPLACE SECRET AMI_DEMO_DB.GIT_OPS.GITHUB_PAT_SECRET
    TYPE     = PASSWORD
    USERNAME = 'raviteja0012'
    PASSWORD = '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'
    COMMENT  = 'Fine-grained PAT for raviteja0012/snowflake-demo. Expires Aug 17, 2026.';

-- ===================================================================
-- 3. API integration. Tight prefix = blast radius is one repo.
-- ===================================================================
CREATE OR REPLACE API INTEGRATION GITHUB_API_INTEGRATION
    API_PROVIDER = GIT_HTTPS_API
    API_ALLOWED_PREFIXES = ('https://github.com/raviteja0012/')
    ALLOWED_AUTHENTICATION_SECRETS = (AMI_DEMO_DB.GIT_OPS.GITHUB_PAT_SECRET)
    ENABLED = TRUE
    COMMENT = 'Read access to the snowflake-demo repo for AMI native git integration demo.';

-- ===================================================================
-- 4. GIT REPOSITORY object (the local Snowflake clone)
-- ===================================================================
CREATE OR REPLACE GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO
    API_INTEGRATION = GITHUB_API_INTEGRATION
    GIT_CREDENTIALS = AMI_DEMO_DB.GIT_OPS.GITHUB_PAT_SECRET
    ORIGIN          = 'https://github.com/raviteja0012/snowflake-demo.git'
    COMMENT         = 'AMI demo source of truth. Read-only clone of github.com/raviteja0012/snowflake-demo.';

-- ===================================================================
-- 5. Grants so DEV_AMI_ADMIN_ROLE can drive deploys
-- ===================================================================
GRANT USAGE ON INTEGRATION GITHUB_API_INTEGRATION                TO ROLE DEV_AMI_ADMIN_ROLE;
GRANT USAGE ON SECRET AMI_DEMO_DB.GIT_OPS.GITHUB_PAT_SECRET      TO ROLE DEV_AMI_ADMIN_ROLE;
GRANT USAGE ON SCHEMA AMI_DEMO_DB.GIT_OPS                        TO ROLE DEV_AMI_ADMIN_ROLE;
GRANT READ  ON GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO   TO ROLE DEV_AMI_ADMIN_ROLE;

-- Support role gets monitor access for ops visibility
GRANT USAGE ON SCHEMA AMI_DEMO_DB.GIT_OPS                        TO ROLE NONPROD_AMI_SUPPORT_ROLE;
GRANT READ  ON GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO   TO ROLE NONPROD_AMI_SUPPORT_ROLE;

-- ===================================================================
-- 6. First fetch to validate auth and pull the initial commit
-- ===================================================================
ALTER GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO FETCH;

-- ===================================================================
-- 7. Verification
-- ===================================================================
SHOW SECRETS         IN SCHEMA AMI_DEMO_DB.GIT_OPS;
SHOW API INTEGRATIONS LIKE 'GITHUB_API_INTEGRATION';
SHOW GIT REPOSITORIES IN SCHEMA AMI_DEMO_DB.GIT_OPS;
SHOW GIT BRANCHES IN AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO;
LIST @AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main;
