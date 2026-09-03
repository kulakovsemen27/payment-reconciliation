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
    ['raw/google_play_earnings_202606.csv', 'raw/google_play_earnings_202607_partial.csv'],
    skip = 1,
    strict_mode = false,
    header = true,
    delim = ',',
    all_varchar = true,
    normalize_names = false
)
