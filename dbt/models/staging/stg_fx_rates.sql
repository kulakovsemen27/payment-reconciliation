{{ config(materialized='table', schema='staging') }}

select distinct
    cast(rate_date as date) as rate_date,
    currency,
    cast(usd_rate as decimal(18, 10)) as usd_rate,
    cast(published_at as timestamptz) as published_at
from {{ ref('fx_rates') }}
