
{{ config(
    materialized='table'
) }}

SELECT 
    product_id      AS IdProduct,
    product_name    AS Name,
    brand_name      AS Brand,
    sub_brand_name  AS SubBrand,
    category_name   AS Category
FROM {{ ref('S_DIM_PRODUCTS') }}
