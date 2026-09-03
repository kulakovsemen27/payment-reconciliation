{{ config(materialized='table', schema='raw') }}

select *
from read_csv(
    'raw/fee_schedule.csv',
    header = true,
    delim = ',',
    all_varchar = true,
    normalize_names = false
)
