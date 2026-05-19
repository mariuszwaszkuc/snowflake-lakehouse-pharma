{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['product_id','country_id','transaction_date'],
    merge_update_columns=[
        'pos_sell_out_quantity',
        'pos_open_quantity',
        'pos_end_quantity',
        'pos_sell_out_amount',
        'pos_open_amount',
        'pos_end_amount',
        'unit_price',
        'pos_update_date',
        'update_ts',
        'updated_by'
    ]
) }}

WITH bronze_pos AS (

    SELECT
        product_id,
        country_id,
        CAST(update_date AS TIMESTAMP)          AS update_date,
        CAST(transaction_date AS DATE)          AS transaction_date,
        CAST(pos_sell_out_quantity AS DOUBLE)   AS pos_sell_out_quantity,
        CAST(pos_open_quantity AS DOUBLE)       AS pos_open_quantity,
        CAST(pos_end_quantity AS DOUBLE)        AS pos_end_quantity,
        CAST(unit_price AS DOUBLE)              AS unit_price
    FROM  {{ source('BRONZE', 'INVENTORY_POS_HISTORY_DETAILS') }}

    {% if is_incremental() %}
        WHERE CAST(update_date AS TIMESTAMP) > (
            SELECT COALESCE(MAX(pos_update_date), CAST('1900-01-01' AS TIMESTAMP))
            FROM {{ this }}
        )
    {% endif %}

),

pos_with_max_date AS (

    SELECT
        product_id,
        country_id,
        update_date,
        transaction_date,
        pos_sell_out_quantity,
        pos_open_quantity,
        pos_end_quantity,
        unit_price,

        MAX(update_date) OVER (
            PARTITION BY product_id, country_id, transaction_date
        ) AS max_update_date
    FROM bronze_pos

),

aggregated_bronze_pos AS (

    SELECT
        product_id,
        country_id,
        MAX(update_date) AS pos_update_date,
        TRUNC(transaction_date, 'MM') AS transaction_date,

        SUM(pos_sell_out_quantity) AS pos_sell_out_quantity,
        SUM(pos_open_quantity)     AS pos_open_quantity,
        SUM(pos_end_quantity)      AS pos_end_quantity,

        ROUND(SUM(pos_sell_out_quantity * unit_price), 2) AS pos_sell_out_amount,
        ROUND(SUM(pos_open_quantity     * unit_price), 2) AS pos_open_amount,
        ROUND(SUM(pos_end_quantity      * unit_price), 2) AS pos_end_amount,

        ROUND(
            SUM(pos_sell_out_quantity * unit_price) / NULLIF(SUM(pos_sell_out_quantity), 0),
            2
        ) AS unit_price
    FROM pos_with_max_date
    WHERE update_date = max_update_date
    GROUP BY
        product_id,
        country_id,
        TRUNC(transaction_date, 'MM')

),

final AS (

    SELECT
        product_id,
        country_id,
        transaction_date,

        pos_sell_out_quantity,
        pos_open_quantity,
        pos_end_quantity,

        pos_sell_out_amount,
        pos_open_amount,
        pos_end_amount,

        unit_price,
        pos_update_date,

        -- audit: zawsze
        current_timestamp() AS update_ts,
        current_user()      AS updated_by,

        -- audit: wg Twojej logiki
        {% if not is_incremental() %}
            current_timestamp() AS insert_ts,
            current_user()      AS inserted_by
        {% else %}
            NULL AS insert_ts,
            NULL AS inserted_by
        {% endif %}

    FROM aggregated_bronze_pos

)

SELECT * FROM final