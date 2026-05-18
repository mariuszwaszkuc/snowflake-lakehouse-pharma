SELECT table_catalog, table_schema, table_name
FROM DEV_LAKEHOUSE.INFORMATION_SCHEMA.VIEWS
WHERE table_name = 'MY_SECOND_DBT_MODEL';