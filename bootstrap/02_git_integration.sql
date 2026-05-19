-- 02_git_integration.sql
-- One-time: Snowflake-side objects that pull from GitHub.
-- Run as ACCOUNTADMIN.
--
-- PAT hardcoded below. Expires Aug 17, 2026.
-- To rotate: regen PAT in GitHub, then ALTER SECRET ... SET PASSWORD = 'new_pat';
-- PAT page: https://github.com/settings/personal-access-tokens/new

USE ROLE ACCOUNTADMIN;
USE DATABASE AMI_DEMO_DB;

-- Schema for ops objects (separate from data schemas)
CREATE SCHEMA IF NOT EXISTS AMI_DEMO_DB.GIT_OPS
    COMMENT = 'Holds the secret, API integration, and GIT REPOSITORY object';

-- GitHub PAT as Snowflake SECRET. Password is encrypted on create; DESCRIBE never shows it.
CREATE OR REPLACE SECRET AMI_DEMO_DB.GIT_OPS.GITHUB_PAT_SECRET
    TYPE     = PASSWORD
    USERNAME = 'raviteja0012'
    PASSWORD = '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'
    COMMENT  = 'Fine-grained PAT for raviteja0012/snowflake-demo. Expires Aug 17, 2026.';

-- API integration. Tight prefix so blast radius is one user only.
CREATE OR REPLACE API INTEGRATION GITHUB_API_INTEGRATION
    API_PROVIDER = GIT_HTTPS_API
    API_ALLOWED_PREFIXES = ('https://github.com/raviteja0012/')
    ALLOWED_AUTHENTICATION_SECRETS = (AMI_DEMO_DB.GIT_OPS.GITHUB_PAT_SECRET)
    ENABLED = TRUE
    COMMENT = 'Access to raviteja0012 repos for AMI demo.';

-- GIT REPOSITORY object = local Snowflake clone of the GitHub repo
CREATE OR REPLACE GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO
    API_INTEGRATION = GITHUB_API_INTEGRATION
    GIT_CREDENTIALS = AMI_DEMO_DB.GIT_OPS.GITHUB_PAT_SECRET
    ORIGIN          = 'https://github.com/raviteja0012/snowflake-demo.git'
    COMMENT         = 'AMI demo source of truth.';

-- Grants so DEV_AMI_ADMIN_ROLE can drive deploys without ACCOUNTADMIN
GRANT USAGE ON INTEGRATION GITHUB_API_INTEGRATION              TO ROLE DEV_AMI_ADMIN_ROLE;
GRANT USAGE ON SECRET AMI_DEMO_DB.GIT_OPS.GITHUB_PAT_SECRET    TO ROLE DEV_AMI_ADMIN_ROLE;
GRANT USAGE ON SCHEMA AMI_DEMO_DB.GIT_OPS                      TO ROLE DEV_AMI_ADMIN_ROLE;
GRANT READ  ON GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO TO ROLE DEV_AMI_ADMIN_ROLE;

-- Support role can monitor only
GRANT USAGE ON SCHEMA AMI_DEMO_DB.GIT_OPS                      TO ROLE NONPROD_AMI_SUPPORT_ROLE;
GRANT READ  ON GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO TO ROLE NONPROD_AMI_SUPPORT_ROLE;

-- First fetch to validate auth + pull initial commit
ALTER GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO FETCH;

-- Verify
SHOW SECRETS          IN SCHEMA AMI_DEMO_DB.GIT_OPS;
SHOW API INTEGRATIONS LIKE 'GITHUB_API_INTEGRATION';
SHOW GIT REPOSITORIES IN SCHEMA AMI_DEMO_DB.GIT_OPS;
SHOW GIT BRANCHES     IN AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO;
LIST @AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main;
