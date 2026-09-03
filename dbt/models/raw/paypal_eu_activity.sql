{{
    config(
        materialized='table',
        schema='raw',
        pre_hook=[
            "INSTALL encodings FROM 'https://extensions.duckdb.org'",
            "LOAD encodings"
        ]
    )
}}

select
    *,
    filename as source_file
from read_csv(
    'raw/paypal_eu_activity_20260601_20260703.csv',
    header = true,
    delim = ';',
    encoding = 'CP1252',
    all_varchar = true,
    normalize_names = false
)
