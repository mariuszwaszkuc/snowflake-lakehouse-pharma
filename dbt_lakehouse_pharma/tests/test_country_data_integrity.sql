SELECT *
FROM {{ ref('S_DIM_CUSTOMERS') }}
WHERE country_id IS NOT NULL
  AND (
        country IS NULL
     OR region_description IS NULL
     OR cluster IS NULL
  )