{{ config(materialized='view') }}
select CUSTOMER_ID,
       COUNTRY_ID,
       CITY,
       PHONE,
       ADDRESS,
       CREATE_DATE,
       POSTAL_CODE,
       UPDATE_DATE,
       COMPANY_NAME
from {{ source('BRONZE', 'CUSTOMERS')}}

