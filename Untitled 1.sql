CREATE USER IF NOT EXISTS github_actions_service_user
  TYPE = SERVICE
  WORKLOAD_IDENTITY = (
    TYPE = OIDC
    ISSUER = 'https://token.actions.githubusercontent.com',
    SUBJECT = 'repo:mariuszwaszkuc/snowflake-lakehouse-pharma:environment:prod'
  )
  DEFAULT_ROLE = ACCOUNTADMIN
  COMMENT = 'Service user for GitHub Actions';

  GRANT ROLE ACCOUNTADMIN TO USER github_actions_service_user;

  ALTER USER github_actions_service_user SET DEFAULT_WAREHOUSE = 'COMPUTE_WH';

GRANT USAGE ON DATABASE PHARMA TO ROLE github_actions_service_user;
GRANT USAGE ON SCHEMA PHARMA.SILVER TO ROLE github_actions_service_user;

GRANT SELECT ON ALL TABLES IN SCHEMA PHARMA.SILVER TO ROLE github_actions_service_user;
GRANT SELECT ON FUTURE TABLES IN SCHEMA PHARMA.SILVER TO ROLE github_actions_service_user;

SELECT CURRENT_USER();

SHOW GRANTS TO ROLE GITHUB_ACTIONS_SERVICE_ROLE;

GRANT OWNERSHIP ON ALL TABLES IN SCHEMA DEV_LAKEHOUSE.GOLD
TO ROLE ACCOUNTADMIN
COPY CURRENT GRANTS;