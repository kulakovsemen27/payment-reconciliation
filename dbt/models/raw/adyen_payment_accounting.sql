{{ 
  config(
    materialized='table', 
    schema='raw'
    ) 
}}

select
    *,
    filename as source_file
from read_csv(
    'raw/adyen_payment_accounting_20260601_20260703.csv',
    header = true,
    delim = ',',
    all_varchar = true,
    normalize_names = false
)
