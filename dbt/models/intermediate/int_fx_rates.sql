{{ config(materialized='table', schema='intermediate') }}

select
    rate_date,
    currency,
    usd_rate,
    published_at
from {{ ref('stg_fx_rates') }}
qualify row_number() over (
    partition by rate_date, currency
    order by published_at desc
) = 1
