SELECT customer_id, COUNT(*) as cnt
FROM {{ ref('S_DIM_CUSTOMERS') }}
GROUP BY customer_id
HAVING COUNT(*) > 1