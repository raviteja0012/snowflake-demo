-- 04_dcm_project_bootstrap.sql
-- Phase 3 setup. Create the DCM project object. Run once as ACCOUNTADMIN.
-- Files are in the git repo. Project object is just the deploy engine.
-- One project per env. DEV_AMI_ADMIN_ROLE owns it because DEPLOY needs OWNERSHIP.
--
-- Canonical syntax: docs.snowflake.com/sql-reference/sql/create-dcm-project
--                   docs.snowflake.com/sql-reference/sql/execute-dcm-project

-- Step 1. Grant CREATE DCM PROJECT once
USE ROLE ACCOUNTADMIN;

GRANT CREATE DCM PROJECT ON SCHEMA AMI_DEMO_DB.GIT_OPS
    TO ROLE DEV_AMI_ADMIN_ROLE;

-- Step 2. Create project as DEV_AMI_ADMIN_ROLE so that role owns it
USE ROLE      DEV_AMI_ADMIN_ROLE;
USE WAREHOUSE NONPROD_AMI_ADMIN_WH;
USE SCHEMA    AMI_DEMO_DB.GIT_OPS;

CREATE DCM PROJECT IF NOT EXISTS AMI_DCM_PROJECT
    LOG_LEVEL = INFO
    COMMENT   = 'AMI DCM project. Declarative deploys for Phase 3.';

-- Step 3. Read for support role
GRANT READ ON DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT
    TO ROLE NONPROD_AMI_SUPPORT_ROLE;

-- Step 4. Verify
SHOW DCM PROJECTS IN SCHEMA AMI_DEMO_DB.GIT_OPS;
DESC DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT;
SHOW GRANTS ON DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT;

-- Step 5. Fresh fetch + first PLAN
-- FROM points at the folder containing manifest.yml (i.e. dcm/ in the repo)
ALTER GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO FETCH;
SHOW GIT BRANCHES IN AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO;

-- Snowflake recommended before EXECUTE DCM PROJECT. Stops secondary roles
-- from leaking extra privileges into the deploy, so behavior is consistent.
USE SECONDARY ROLES NONE;

-- PLAN returns one row with a JSON changeset (CREATE / ALTER / DROP per object).
EXECUTE DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT PLAN
    USING CONFIGURATION DEV
    FROM '@AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main/dcm/';

-- If PLAN looks right, then DEPLOY:
-- EXECUTE DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT DEPLOY AS 'first_deploy'
--     USING CONFIGURATION DEV
--     FROM '@AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main/dcm/';

-- Deployment history (immutable artifacts per deploy):
-- SHOW DEPLOYMENTS IN DCM PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT;