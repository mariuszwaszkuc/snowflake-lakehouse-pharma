{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['country_id','product_id','shipped_date'],
    merge_update_columns=[
        'quantity',
        'discount',
        'amount',
        'unit_price',
        'order_details_update_date',
        'order_update_date',
        'update_ts',
        'updated_by'
    ]
) }}

WITH orders_trunc AS (

    SELECT
        order_id,
        customer_id,
        TRUNC(CAST(order_date AS DATE), 'MM')      AS order_date,
        TRUNC(CAST(required_date AS DATE), 'MM')   AS required_date,
        TRUNC(CAST(shipped_date AS DATE), 'MM')    AS shipped_date,
        CAST(update_date AS TIMESTAMP)             AS order_update_date
     FROM  {{ source('BRONZE', 'ORDERS') }}

),

order_details_cast AS (

    SELECT
        order_id,
        product_id,
        CAST(unit_price AS DOUBLE)                 AS unit_price,
        CAST(quantity AS DOUBLE)                   AS quantity,
        CAST(discount AS DOUBLE)                   AS discount,
        CAST(update_date AS TIMESTAMP)             AS order_details_update_date
     FROM  {{ source('BRONZE', 'ORDER_DETAILS') }}

),

customers AS (

    SELECT
        customer_id,
        country_id
    FROM {{ ref('S_DIM_CUSTOMERS') }}

),

joined_orders AS (

    SELECT
        o.order_id,
        c.country_id,
        od.product_id,
        o.shipped_date,
        od.unit_price,
        od.quantity,
        od.discount,
        od.order_details_update_date,
        o.order_update_date
    FROM orders_trunc o
    JOIN order_details_cast od
        ON o.order_id = od.order_id
    JOIN customers c
        ON o.customer_id = c.customer_id

    {% if is_incremental() %}
        -- Filtr przyrostowy: bierzemy tylko rekordy, gdzie "coś się zmieniło"
        -- (max z order_details_update_date / order_update_date) względem tego, co już mamy w {{ this }}.
        WHERE greatest(od.order_details_update_date, o.order_update_date) >
        (
            SELECT COALESCE(MAX(change_ts), CAST('1900-01-01' AS TIMESTAMP))
            FROM (
                SELECT greatest(
                    CAST(order_details_update_date AS TIMESTAMP),
                    CAST(order_update_date AS TIMESTAMP)
                ) AS change_ts
                FROM {{ this }}
            ) t
        )
    {% endif %}

),

orders_with_max_update AS (

    SELECT
        order_id,
        country_id,
        product_id,
        shipped_date,
        order_details_update_date,
        order_update_date,
        quantity,
        discount,
        unit_price,

        MAX(order_details_update_date) OVER (
            PARTITION BY order_id, product_id, country_id, shipped_date
        ) AS max_order_details_update_date,

        MAX(order_update_date) OVER (
            PARTITION BY order_id, product_id, country_id, shipped_date
        ) AS max_order_update_date

    FROM joined_orders

),

aggregated_bronze_orders AS (

    SELECT
        country_id,
        product_id,
        shipped_date,

        -- w notebooku trzymasz obie daty update (detale i nagłówek)
        order_details_update_date,
        order_update_date,

        SUM(quantity) AS quantity,
        SUM(discount) AS discount,

        ROUND(SUM(quantity * unit_price), 2) AS amount,
        ROUND(SUM(quantity * unit_price) / NULLIF(SUM(quantity), 0), 2) AS unit_price

    FROM orders_with_max_update
    WHERE order_details_update_date = max_order_details_update_date
      AND order_update_date = max_order_update_date

    GROUP BY
        country_id,
        product_id,
        shipped_date,
        order_details_update_date,
        order_update_date

),

final AS (

    SELECT
        country_id,
        product_id,
        shipped_date,
        quantity,
        discount,
        amount,
        unit_price,
        CAST(order_details_update_date AS DATE) AS order_details_update_date,
        CAST(order_update_date AS DATE)         AS order_update_date,

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

    FROM aggregated_bronze_orders

)

SELECT * FROM final