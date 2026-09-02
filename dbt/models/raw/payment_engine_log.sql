{{ 
  config(
    materialized='table'
    ) 
}}

select
    *
from read_csv(
    'raw/payment_engine_log.csv',
    header = true,
    delim = ',',
    all_varchar = true,
    normalize_names = false
)
