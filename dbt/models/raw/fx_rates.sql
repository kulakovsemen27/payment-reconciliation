{{ config(materialized='table', schema='raw') }}

select *
from read_csv(
    'raw/fx_rates.csv',
    header = true,
    delim = ',',
    all_varchar = true,
    normalize_names = false
)
