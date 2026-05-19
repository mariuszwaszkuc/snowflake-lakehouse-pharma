{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['product_id','country_id','forecast_date','forecast_snapshot'],
    merge_update_columns=[
        'forecast_update_date',
        'quantity',
        'whrs_sell_in_quantity',
        'whrs_open_quantity',
        'whrs_end_quantity',
        'pos_sell_out_quantity',
        'pos_open_quantity',
        'pos_end_quantity',
        'amount',
        'whrs_sell_in_amount',
        'whrs_open_amount',
        'whrs_end_amount',
        'pos_sell_out_amount',
        'pos_open_amount',
        'pos_end_amount',
        'unit_price',
        'update_ts',
        'updated_by'
    ]
) }}

WITH bronze_forecast AS (

    SELECT
        product_id,
        country_id,
        update_date,
        forecast_date,
        forecast_snapshot,
        quantity,
        whrs_sell_in_quantity,
        whrs_open_quantity,
        whrs_end_quantity,
        pos_sell_out_quantity,
        pos_open_quantity,
        pos_end_quantity,
        unit_price
       from {{ source('BRONZE', 'FORECAST_DETAILS') }}

    {% if is_incremental() %}
        WHERE update_date > (
            SELECT COALESCE(MAX(forecast_update_date), CAST('1900-01-01' AS TIMESTAMP))
            FROM {{ this }}
        )
    {% endif %}

),

forecast_with_max_date AS (

    SELECT 
        product_id,
        country_id,
        update_date,
        forecast_date,
        forecast_snapshot,
        quantity,
        whrs_sell_in_quantity,
        whrs_open_quantity,
        whrs_end_quantity,
        pos_sell_out_quantity,
        pos_open_quantity,
        pos_end_quantity,
        unit_price,
        MAX(update_date) OVER (
            PARTITION BY 
                product_id,
                country_id,
                TRUNC(forecast_date, 'MM'),
                TRUNC(forecast_snapshot, 'MM')
        ) AS max_update_date
    FROM bronze_forecast

),

aggregated_forecast AS (

    SELECT 
        product_id,
        country_id,
        MAX(update_date) AS forecast_update_date,
        TRUNC(forecast_date, 'MM') AS forecast_date,
        TRUNC(forecast_snapshot, 'MM') AS forecast_snapshot,
        
        SUM(quantity) AS quantity,
        SUM(whrs_sell_in_quantity) AS whrs_sell_in_quantity,
        SUM(whrs_open_quantity) AS whrs_open_quantity,
        SUM(whrs_end_quantity) AS whrs_end_quantity,
        
        SUM(pos_sell_out_quantity) AS pos_sell_out_quantity,
        SUM(pos_open_quantity) AS pos_open_quantity,
        SUM(pos_end_quantity) AS pos_end_quantity,
        
        ROUND(SUM(quantity * unit_price), 2) AS amount,
        ROUND(SUM(whrs_sell_in_quantity * unit_price), 2) AS whrs_sell_in_amount,
        ROUND(SUM(whrs_open_quantity * unit_price), 2) AS whrs_open_amount,
        ROUND(SUM(whrs_end_quantity * unit_price), 2) AS whrs_end_amount,
        
        ROUND(SUM(pos_sell_out_quantity * unit_price), 2) AS pos_sell_out_amount,
        ROUND(SUM(pos_open_quantity * unit_price), 2) AS pos_open_amount,
        ROUND(SUM(pos_end_quantity * unit_price), 2) AS pos_end_amount,
        
        ROUND(SUM(quantity * unit_price) / NULLIF(SUM(quantity), 0), 2) AS unit_price

    FROM forecast_with_max_date
    WHERE update_date = max_update_date

    GROUP BY 
        product_id,
        country_id,
        TRUNC(forecast_date, 'MM'),
        TRUNC(forecast_snapshot, 'MM')

),

final AS (

    SELECT
        product_id,
        country_id,
        forecast_date,
        forecast_snapshot,
        forecast_update_date,

        quantity,
        whrs_sell_in_quantity,
        whrs_open_quantity,
        whrs_end_quantity,

        pos_sell_out_quantity,
        pos_open_quantity,
        pos_end_quantity,

        amount,
        whrs_sell_in_amount,
        whrs_open_amount,
        whrs_end_amount,

        pos_sell_out_amount,
        pos_open_amount,
        pos_end_amount,

        unit_price,

        -- ✅ audit update (zawsze)
        current_timestamp() AS update_ts,
        current_user() AS updated_by,

        -- ✅ audit insert (zgodnie z Twoją logiką)
        {% if not is_incremental() %}
            current_timestamp() AS insert_ts,
            current_user() AS inserted_by
        {% else %}
            NULL AS insert_ts,
            NULL AS inserted_by
        {% endif %}

    FROM aggregated_forecast

)

SELECT * FROM final