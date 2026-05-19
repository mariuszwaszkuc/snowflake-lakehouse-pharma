{{
  config(
    materialized='incremental',
    unique_key='customer_id',
    incremental_strategy='merge',

    merge_update_columns = [
      'country_id',
      'company_name',
      'address',
      'city',
      'region_description',
      'country',
      'cluster',
      'customer_update_date',
      'country_update_date',
      'last_update',      
      'update_ts',
      'updated_by'

    ]
  )
}}

with b_customers as (
    select * 
    from {{ source('BRONZE', 'CUSTOMERS') }}
),

b_countries as (
    select * 
    from {{ source('BRONZE', 'COUNTRIES') }}
),

S_DIM_CUSTOMERS as (
    SELECT 
        c.customer_id,
        c.country_id,
        c.company_name,
        c.address,
        c.city,
        co.region_description,
        co.country,
        co.cluster,

        c.update_date AS customer_update_date,
        co.update_date AS country_update_date,

        GREATEST(c.update_date, co.update_date) as last_update,

        current_timestamp() as update_ts,
        current_user() as updated_by,

        {% if not is_incremental() %}
            current_timestamp() as insert_ts,
            current_user() as inserted_by
        {% else %}
            null as insert_ts,
            null as inserted_by
        {% endif %}

    FROM b_customers c
    JOIN b_countries co
      ON c.country_id = co.country_id
)

SELECT * 
FROM S_DIM_CUSTOMERS

{% if is_incremental() %}
WHERE 
    customer_update_date > COALESCE(
        (SELECT MAX(customer_update_date) FROM {{ this }}), 
        '1900-01-01'
    )
    OR 
    country_update_date > COALESCE(
        (SELECT MAX(country_update_date) FROM {{ this }}), 
        '1900-01-01'
    )
{% endif %}