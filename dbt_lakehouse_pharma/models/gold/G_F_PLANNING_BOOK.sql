{{ config(
    materialized='table'
) }}

WITH snapshots AS (

    SELECT
        MAX(forecast_snapshot) AS current_snapshot,
        add_months(MAX(forecast_snapshot), -1) AS last_snapshot
    FROM {{ ref('S_F_FORECAST') }}

),

/* -----------------------------
   1) Forecast (current + last)
--------------------------------*/
forecast_current AS (

    SELECT
        f.product_id,
        f.country_id,
        f.forecast_date       AS financial_date,
        f.forecast_snapshot,

        f.quantity,
        f.amount,
        f.unit_price,

        f.whrs_sell_in_quantity,
        f.whrs_open_quantity,
        f.whrs_end_quantity,

        f.whrs_sell_in_amount,
        f.whrs_open_amount,
        f.whrs_end_amount,

        f.pos_sell_out_quantity,
        f.pos_open_quantity,
        f.pos_end_quantity,

        f.pos_sell_out_amount,
        f.pos_open_amount,
        f.pos_end_amount,

        CAST(0.0 AS DOUBLE)   AS discount

    FROM {{ ref('S_F_FORECAST') }} f
    CROSS JOIN snapshots s
    WHERE f.forecast_snapshot = s.current_snapshot
      AND f.forecast_date >= s.current_snapshot

),

forecast_last AS (

    SELECT
        f.product_id,
        f.country_id,
        f.forecast_date       AS financial_date,
        f.forecast_snapshot,

        f.quantity,
        f.amount,
        f.unit_price,

        f.whrs_sell_in_quantity,
        f.whrs_open_quantity,
        f.whrs_end_quantity,

        f.whrs_sell_in_amount,
        f.whrs_open_amount,
        f.whrs_end_amount,

        f.pos_sell_out_quantity,
        f.pos_open_quantity,
        f.pos_end_quantity,

        f.pos_sell_out_amount,
        f.pos_open_amount,
        f.pos_end_amount,

        CAST(0.0 AS DOUBLE)   AS discount

    FROM {{ ref('S_F_FORECAST') }} f
    CROSS JOIN snapshots s
    WHERE f.forecast_snapshot = s.last_snapshot
      AND f.forecast_date >= s.last_snapshot

),

/* -----------------------------
   2) Sales (current + last)
--------------------------------*/
sales_current AS (

    SELECT
        s.product_id,
        s.country_id,
        s.shipped_date            AS financial_date,
        snap.current_snapshot     AS forecast_snapshot,

        s.quantity,
        s.amount,
        s.unit_price,

        CAST(0.0 AS DOUBLE) AS whrs_sell_in_quantity,
        CAST(0.0 AS DOUBLE) AS whrs_open_quantity,
        CAST(0.0 AS DOUBLE) AS whrs_end_quantity,

        CAST(0.0 AS DOUBLE) AS whrs_sell_in_amount,
        CAST(0.0 AS DOUBLE) AS whrs_open_amount,
        CAST(0.0 AS DOUBLE) AS whrs_end_amount,

        CAST(0.0 AS DOUBLE) AS pos_sell_out_quantity,
        CAST(0.0 AS DOUBLE) AS pos_open_quantity,
        CAST(0.0 AS DOUBLE) AS pos_end_quantity,

        CAST(0.0 AS DOUBLE) AS pos_sell_out_amount,
        CAST(0.0 AS DOUBLE) AS pos_open_amount,
        CAST(0.0 AS DOUBLE) AS pos_end_amount,

        s.discount

    FROM {{ ref('S_F_SALES') }} s
    CROSS JOIN snapshots snap
    WHERE s.shipped_date < snap.current_snapshot

),

sales_last AS (

    SELECT
        s.product_id,
        s.country_id,
        s.shipped_date         AS financial_date,
        snap.last_snapshot     AS forecast_snapshot,

        s.quantity,
        s.amount,
        s.unit_price,

        CAST(0.0 AS DOUBLE) AS whrs_sell_in_quantity,
        CAST(0.0 AS DOUBLE) AS whrs_open_quantity,
        CAST(0.0 AS DOUBLE) AS whrs_end_quantity,

        CAST(0.0 AS DOUBLE) AS whrs_sell_in_amount,
        CAST(0.0 AS DOUBLE) AS whrs_open_amount,
        CAST(0.0 AS DOUBLE) AS whrs_end_amount,

        CAST(0.0 AS DOUBLE) AS pos_sell_out_quantity,
        CAST(0.0 AS DOUBLE) AS pos_open_quantity,
        CAST(0.0 AS DOUBLE) AS pos_end_quantity,

        CAST(0.0 AS DOUBLE) AS pos_sell_out_amount,
        CAST(0.0 AS DOUBLE) AS pos_open_amount,
        CAST(0.0 AS DOUBLE) AS pos_end_amount,

        s.discount

    FROM {{ ref('S_F_SALES') }} s
    CROSS JOIN snapshots snap
    WHERE s.shipped_date < snap.last_snapshot

),

/* -----------------------------
   3) POS (current + last)
--------------------------------*/
pos_current AS (

    SELECT
        p.product_id,
        p.country_id,
        p.transaction_date       AS financial_date,
        snap.current_snapshot    AS forecast_snapshot,

        CAST(0.0 AS DOUBLE) AS quantity,
        CAST(0.0 AS DOUBLE) AS amount,
        p.unit_price,

        CAST(0.0 AS DOUBLE) AS whrs_sell_in_quantity,
        CAST(0.0 AS DOUBLE) AS whrs_open_quantity,
        CAST(0.0 AS DOUBLE) AS whrs_end_quantity,

        CAST(0.0 AS DOUBLE) AS whrs_sell_in_amount,
        CAST(0.0 AS DOUBLE) AS whrs_open_amount,
        CAST(0.0 AS DOUBLE) AS whrs_end_amount,

        p.pos_sell_out_quantity,
        p.pos_open_quantity,
        p.pos_end_quantity,

        p.pos_sell_out_amount,
        p.pos_open_amount,
        p.pos_end_amount,

        CAST(0.0 AS DOUBLE) AS discount

    FROM {{ ref('S_F_POS') }} p
    CROSS JOIN snapshots snap
    WHERE p.transaction_date < snap.current_snapshot

),

pos_last AS (

    SELECT
        p.product_id,
        p.country_id,
        p.transaction_date      AS financial_date,
        snap.last_snapshot      AS forecast_snapshot,

        CAST(0.0 AS DOUBLE) AS quantity,
        CAST(0.0 AS DOUBLE) AS amount,
        p.unit_price,

        CAST(0.0 AS DOUBLE) AS whrs_sell_in_quantity,
        CAST(0.0 AS DOUBLE) AS whrs_open_quantity,
        CAST(0.0 AS DOUBLE) AS whrs_end_quantity,

        CAST(0.0 AS DOUBLE) AS whrs_sell_in_amount,
        CAST(0.0 AS DOUBLE) AS whrs_open_amount,
        CAST(0.0 AS DOUBLE) AS whrs_end_amount,

        p.pos_sell_out_quantity,
        p.pos_open_quantity,
        p.pos_end_quantity,

        p.pos_sell_out_amount,
        p.pos_open_amount,
        p.pos_end_amount,

        CAST(0.0 AS DOUBLE) AS discount

    FROM {{ ref('S_F_POS') }} p
    CROSS JOIN snapshots snap
    WHERE p.transaction_date < snap.last_snapshot

),

/* -----------------------------
   4) WH (current + last)
--------------------------------*/
wh_current AS (

    SELECT
        w.product_id,
        w.country_id,
        w.transaction_date      AS financial_date,
        snap.current_snapshot   AS forecast_snapshot,

        CAST(0.0 AS DOUBLE) AS quantity,
        CAST(0.0 AS DOUBLE) AS amount,
        w.unit_price,

        w.whrs_sell_in_quantity,
        w.whrs_open_quantity,
        w.whrs_end_quantity,

        w.whrs_sell_in_amount,
        w.whrs_open_amount,
        w.whrs_end_amount,

        CAST(0.0 AS DOUBLE) AS pos_sell_out_quantity,
        CAST(0.0 AS DOUBLE) AS pos_open_quantity,
        CAST(0.0 AS DOUBLE) AS pos_end_quantity,

        CAST(0.0 AS DOUBLE) AS pos_sell_out_amount,
        CAST(0.0 AS DOUBLE) AS pos_open_amount,
        CAST(0.0 AS DOUBLE) AS pos_end_amount,

        CAST(0.0 AS DOUBLE) AS discount

    FROM {{ ref('S_F_WH_DATA') }} w
    CROSS JOIN snapshots snap
    WHERE w.transaction_date < snap.current_snapshot

),

wh_last AS (

    SELECT
        w.product_id,
        w.country_id,
        w.transaction_date    AS financial_date,
        snap.last_snapshot    AS forecast_snapshot,

        CAST(0.0 AS DOUBLE) AS quantity,
        CAST(0.0 AS DOUBLE) AS amount,
        w.unit_price,

        w.whrs_sell_in_quantity,
        w.whrs_open_quantity,
        w.whrs_end_quantity,

        w.whrs_sell_in_amount,
        w.whrs_open_amount,
        w.whrs_end_amount,

        CAST(0.0 AS DOUBLE) AS pos_sell_out_quantity,
        CAST(0.0 AS DOUBLE) AS pos_open_quantity,
        CAST(0.0 AS DOUBLE) AS pos_end_quantity,

        CAST(0.0 AS DOUBLE) AS pos_sell_out_amount,
        CAST(0.0 AS DOUBLE) AS pos_sell_out_amount,
        CAST(0.0 AS DOUBLE) AS pos_end_amount,

        CAST(0.0 AS DOUBLE) AS discount

    FROM {{ ref('S_F_WH_DATA') }} w
    CROSS JOIN snapshots snap
    WHERE w.transaction_date < snap.last_snapshot

),

/* -----------------------------
   5) UNION + agregacja (jak groupBy w PySpark)
--------------------------------*/
unioned AS (

    SELECT * FROM forecast_current
    UNION ALL SELECT * FROM forecast_last
    UNION ALL SELECT * FROM sales_current
    UNION ALL SELECT * FROM sales_last
    UNION ALL SELECT * FROM pos_current
    UNION ALL SELECT * FROM pos_last
    UNION ALL SELECT * FROM wh_current
    UNION ALL SELECT * FROM wh_last

),

aggregated AS (

    SELECT
        product_id,
        country_id,
        financial_date,
        forecast_snapshot,

        SUM(quantity)               AS quantity,
        SUM(amount)                 AS amount,

        SUM(whrs_sell_in_quantity)  AS whrs_sell_in_quantity,
        SUM(whrs_open_quantity)     AS whrs_open_quantity,
        SUM(whrs_end_quantity)      AS whrs_end_quantity,

        SUM(whrs_sell_in_amount)    AS whrs_sell_in_amount,
        SUM(whrs_open_amount)       AS whrs_open_amount,
        SUM(whrs_end_amount)        AS whrs_end_amount,

        SUM(pos_sell_out_quantity)  AS pos_sell_out_quantity,
        SUM(pos_open_quantity)      AS pos_open_quantity,
        SUM(pos_end_quantity)       AS pos_end_quantity,

        SUM(pos_sell_out_amount)    AS pos_sell_out_amount,
        SUM(pos_open_amount)        AS pos_open_amount,
        SUM(pos_end_amount)         AS pos_end_amount

    FROM unioned
    GROUP BY product_id, country_id, financial_date, forecast_snapshot

),



final AS (

    SELECT
        product_id     AS IdProduct,
        country_id     AS IDCountry,
        financial_date AS Date,
        forecast_snapshot,
        'EA'           AS Measure,

        CASE
            WHEN forecast_snapshot = (SELECT current_snapshot FROM snapshots) THEN 'Current'
            ELSE 'Last'
        END AS Version,


        quantity              AS Ex_Factory,
        whrs_sell_in_quantity AS Sales_to_pharmacies,
        whrs_open_quantity    AS Open_Stock,
        whrs_end_quantity     AS Close_Stock,
        pos_sell_out_quantity AS Consumer_Off_Take,
        pos_open_quantity     AS Open_Stock_Pharmacies,
        pos_end_quantity      AS Close_Stock_Pharmacies

    FROM aggregated

    UNION ALL

    SELECT
        product_id     AS IdProduct,
        country_id     AS IDCountry,
        financial_date AS Date,
        forecast_snapshot,
        'GTS'          AS Measure,

        CASE
            WHEN forecast_snapshot = (SELECT current_snapshot FROM snapshots) THEN 'Current'
            ELSE 'Last'
        END AS Version,

        amount              AS Ex_Factory,
        whrs_sell_in_amount AS Sales_to_pharmacies,
        whrs_open_amount    AS Open_Stock,
        whrs_end_amount     AS Close_Stock,
        pos_sell_out_amount AS Consumer_Off_Take,
        pos_open_amount     AS Open_Stock_Pharmacies,
        pos_end_amount      AS Close_Stock_Pharmacies

    FROM aggregated

)

SELECT * FROM final
