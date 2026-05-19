{{ config(
    materialized='table'
) }}

SELECT DISTINCT
    country_id          AS IDCountry,
    cluster             AS Cluster,
    region_description  AS Region,
    country             AS Country
FROM {{ ref('S_DIM_CUSTOMERS') }}