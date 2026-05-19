{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['product_id','country_id','transaction_date'],
    merge_update_columns=[
        'whrs_sell_in_quantity',
        'whrs_open_quantity',
        'whrs_end_quantity',
        'whrs_sell_in_amount',
        'whrs_open_amount',
        'whrs_end_amount',
        'unit_price',
        'whrs_update_date',
        'update_ts',
        'updated_by'
    ]
) }}

WITH bronze_inventory AS (

    SELECT
        customer_id,
        product_id,
        CAST(transaction_date AS DATE)          AS transaction_date,
        CAST(update_date AS TIMESTAMP)          AS update_date,
        CAST(unit_price AS DOUBLE)              AS unit_price,
        CAST(whrs_sell_in_quantity AS DOUBLE)   AS whrs_sell_in_quantity,
        CAST(whrs_open_quantity AS DOUBLE)      AS whrs_open_quantity,
        CAST(whrs_end_quantity AS DOUBLE)       AS whrs_end_quantity
    FROM  {{ source('BRONZE', 'INVENTORY_WHOLESALER_HISTORY_DETAILS') }}

    {% if is_incremental() %}
        WHERE CAST(update_date AS TIMESTAMP) > (
            SELECT COALESCE(MAX(CAST(whrs_update_date AS TIMESTAMP)), CAST('1900-01-01' AS TIMESTAMP))
            FROM {{ this }}
        )
    {% endif %}

),

customers AS (

    SELECT
        customer_id,
        country_id
    FROM {{ ref('S_DIM_CUSTOMERS') }}

),

join_wh AS (

    SELECT
        inv.customer_id,
        inv.product_id,
        c.country_id,
        inv.transaction_date,
        inv.update_date AS whrs_update_date,
        inv.unit_price,
        inv.whrs_sell_in_quantity,
        inv.whrs_open_quantity,
        inv.whrs_end_quantity
    FROM bronze_inventory inv
    JOIN customers c
        ON inv.customer_id = c.customer_id

),

select_wh AS (

    SELECT
        product_id,
        country_id,
        whrs_update_date,
        transaction_date,
        unit_price,
        whrs_sell_in_quantity,
        whrs_open_quantity,
        whrs_end_quantity,

        MAX(whrs_update_date) OVER (
            PARTITION BY product_id, country_id, transaction_date
        ) AS max_whrs_update_date
    FROM join_wh

),

wh_with_max_update AS (

    SELECT
        product_id,
        country_id,
        TRUNC(transaction_date, 'MM') AS transaction_date,
        whrs_update_date,
        unit_price,
        whrs_sell_in_quantity,
        whrs_open_quantity,
        whrs_end_quantity,
        max_whrs_update_date
    FROM select_wh

),

aggregated_bronze_wh AS (

    SELECT
        product_id,
        country_id,
        transaction_date,
        whrs_update_date,

        SUM(whrs_sell_in_quantity) AS whrs_sell_in_quantity,
        SUM(whrs_open_quantity)    AS whrs_open_quantity,
        SUM(whrs_end_quantity)     AS whrs_end_quantity,

        ROUND(SUM(whrs_sell_in_quantity * unit_price), 2) AS whrs_sell_in_amount,
        ROUND(SUM(whrs_open_quantity    * unit_price), 2) AS whrs_open_amount,
        ROUND(SUM(whrs_end_quantity     * unit_price), 2) AS whrs_end_amount,

        ROUND(
            SUM(whrs_sell_in_quantity * unit_price) / NULLIF(SUM(whrs_sell_in_quantity), 0),
            2
        ) AS unit_price

    FROM wh_with_max_update
    WHERE whrs_update_date = max_whrs_update_date
    GROUP BY product_id, country_id, transaction_date, whrs_update_date

),

final AS (

    SELECT
        product_id,
        country_id,
        transaction_date,

        whrs_sell_in_quantity,
        whrs_open_quantity,
        whrs_end_quantity,

        whrs_sell_in_amount,
        whrs_open_amount,
        whrs_end_amount,

        unit_price,
        CAST(whrs_update_date AS DATE) AS whrs_update_date,

        -- audit: zawsze
        current_timestamp() AS update_ts,
        current_user()      AS updated_by,

        -- audit: wg Twojej logiki (tak jak wcześniej)
        {% if not is_incremental() %}
            current_timestamp() AS insert_ts,
            current_user()      AS inserted_by
        {% else %}
            NULL AS insert_ts,
            NULL AS inserted_by
        {% endif %}

    FROM aggregated_bronze_wh

)

SELECT * FROM final