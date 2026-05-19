-- 03_keypair_auth.sql
-- Phase 2: register the CI service auth public key on RAVITEJA0012,
-- and GRANT WRITE on the GIT REPOSITORY so DEV_AMI_ADMIN_ROLE can FETCH from CI.
-- Run as ACCOUNTADMIN. Run once. Re-run only on keypair rotation.
--
-- Public key was generated on Windows Git Bash:
--   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
--   openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
--
-- Valid GIT REPOSITORY privileges per Snowflake docs: { READ, WRITE }.
-- OPERATE is NOT valid for this object.

USE ROLE ACCOUNTADMIN;

-- Public key on user. User keeps password auth, just adds keypair on top.
ALTER USER RAVITEJA0012 SET RSA_PUBLIC_KEY = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1Za2MSG+bSCMTh8h61Ty+q1iLALXvtykdvuVleBAPoNSVp5xxnOaJNRn3Oi836JTsLeVEIvdHjlpNz6Ic2H6eR7oE5lDC/p06gL0BnjqTQSdNdsnUfSgrrpgMhmF1PYReDBBOD2SAFlh11K0kbAIDSYfGLDa7bpHZK5OTvzrg7MouaeubMP9XN2/icgQf/GF1tkqnppXVaoE2155sC3o/+DM+JO97T5f7bPTwiByW0wBXbG/P4HffChyE1iL66hY7ZNpXDiQVmmgPhj2GcI03oINTfzD1acJ9m8OK6XkWXnFp4kV+FR8E151DX9iAPEsgmZGDyKT7rLQt+8x8q0sEwIDAQAB';

-- Grant WRITE so DEV_AMI_ADMIN_ROLE can FETCH (i.e. update the local Snowflake clone).
-- The CI runner uses this role, so it needs WRITE to refresh before deploy.
GRANT WRITE ON GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO TO ROLE DEV_AMI_ADMIN_ROLE;

-- Verify fingerprint. SHOW USERS only shows boolean has_rsa_public_key.
-- DESC USER gives the actual RSA_PUBLIC_KEY_FP value.
DESC USER RAVITEJA0012;
SELECT "property", "value"
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
 WHERE "property" IN ('RSA_PUBLIC_KEY_FP', 'RSA_PUBLIC_KEY');

-- Verify grant
SHOW GRANTS ON GIT REPOSITORY AMI_DEMO_DB.GIT_OPS.AMI_GIT_REPO;
