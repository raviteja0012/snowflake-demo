-- 04_dcm_project_bootstrap.sql
-- Phase 3 bootstrap: create the DCM project object that will run PLAN / DEPLOY.
-- Run once per environment, as ACCOUNTADMIN.
--
-- DCM project object is schema-level (we put it in GIT_OPS, same place as the GIT REPOSITORY).
-- One project object per environment. Same definition files, different targets.
--
-- Reference: https://docs.snowflake.com/en/user-guide/dcm-projects/dcm-projects-overview

USE ROLE ACCOUNTADMIN;
USE DATABASE AMI_DEMO_DB;

-- Create the DCM project object pointing at our GitHub repo's dcm/ folder.
-- We re-use the same AMI_GIT_REPO that imperative deploys already use.
CREATE OR ALTER PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT
    FROM @AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO/branches/main/dcm/
    COMMENT = 'AMI DCM Project. Declarative deploys for Phase 3.';

-- Grants. The role doing PLAN/DEPLOY needs OWNERSHIP on the project
-- plus the usual privileges to create/alter/drop the managed objects.
GRANT OWNERSHIP ON PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT
    TO ROLE DEV_AMI_ADMIN_ROLE COPY CURRENT GRANTS;

-- Support role can read deployment history
GRANT USAGE ON PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT TO ROLE NONPROD_AMI_SUPPORT_ROLE;

-- Verify
SHOW PROJECTS IN SCHEMA AMI_DEMO_DB.GIT_OPS;
DESC PROJECT AMI_DEMO_DB.GIT_OPS.AMI_DCM_PROJECT;
