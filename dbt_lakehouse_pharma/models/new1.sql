select *
  from {{ ref('my_first_dbt_model1') }}
  where id = 1



  