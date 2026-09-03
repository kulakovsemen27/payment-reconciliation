{{ config(materialized='table', schema='raw') }}

select
    *,
    filename as source_file
from read_csv(
    'raw/dlocal_transactions_20260601_20260703.csv',
    header = true,
    delim = ',',
    all_varchar = true,
    normalize_names = false
)
