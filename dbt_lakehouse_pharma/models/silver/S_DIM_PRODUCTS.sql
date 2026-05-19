{{ config(
    materialized = 'incremental',
    unique_key = 'product_id',
    incremental_strategy = 'merge',

    merge_update_columns = [
        'product_name',
        'brand_name',
        'sub_brand_name',
        'category_name',
        'update_date',
        'update_ts',
        'updated_by'
    ]
) }}

WITH source_data AS (

    SELECT 
        product_id,
        product_name,
        brand_name,
        sub_brand_name,
        category_name,
        update_date,

        -- audit columns (update zawsze)
        current_timestamp() AS update_ts,
        current_user() AS updated_by,

        -- audit columns (insert tylko przy full load)
        {% if not is_incremental() %}
            current_timestamp() AS insert_ts,
            current_user() AS inserted_by
        {% else %}
            NULL AS insert_ts,
            NULL AS inserted_by
        {% endif %}

      from {{ source('BRONZE', 'PRODUCTS') }}

    -- incremental filter (performance + mniejsze MERGE)
    {% if is_incremental() %}
        WHERE update_date > (SELECT MAX(update_date) FROM {{ this }})
    {% endif %}

),

deduped AS (

    SELECT *
    FROM (
        SELECT 
            *,
            ROW_NUMBER() OVER (
                PARTITION BY product_id 
                ORDER BY update_date DESC
            ) AS rn
        FROM source_data
    )
    WHERE rn = 1

)

SELECT
    product_id,
    product_name,
    brand_name,
    sub_brand_name,
    category_name,
    update_date,
    update_ts,
    updated_by,
    insert_ts,
    inserted_by
FROM deduped