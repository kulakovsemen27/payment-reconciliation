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
    'raw/paypal_us_activity_20260601_20260703.csv',
    header = true,
    delim = ',',
    all_varchar = true,
    normalize_names = false
)
