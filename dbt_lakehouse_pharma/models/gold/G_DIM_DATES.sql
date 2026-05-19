{{ config(
    materialized='table'
) }}

WITH seq AS (

    SELECT 
        DATEADD(
            day,
            ROW_NUMBER() OVER (ORDER BY seq4()) - 1,
            TO_DATE('2020-01-01')
        ) AS Date
    FROM TABLE(GENERATOR(ROWCOUNT => 3000))

),

filtered AS (

    SELECT *
    FROM seq
    WHERE Date <= TO_DATE('2026-12-31')

),

final AS (

    SELECT
        YEAR(Date) AS Year,
        CONCAT('Q', QUARTER(Date)) AS Quarter,
        MONTH(Date) AS Month,
        Date,

        CASE 
            WHEN MONTH(Date) < MONTH(CURRENT_TIMESTAMP()) THEN 'YTD'
            ELSE 'BTG'
        END AS YTD_BTG,

        'FY' AS FY,

        CONCAT(YEAR(Date), MONTH(Date)) AS KeyYearMonth,
        CONCAT(YEAR(Date), CONCAT('Q', QUARTER(Date))) AS KeyYearQuarter,
        CONCAT(YEAR(Date),
            CASE 
                WHEN MONTH(Date) < MONTH(CURRENT_TIMESTAMP()) THEN 'YTD'
                ELSE 'BTG'
            END
        ) AS KeyYearYTDBTG,
        CONCAT(YEAR(Date), 'FY') AS KeyYearFY

    FROM filtered

)

SELECT * FROM final
--demo2s