{{ 
  config(
    materialized='table', 
    schema='staging'
    ) 
}}

with deduplicated as (
    select distinct *
    from {{ ref('dlocal_transactions') }}
)

select
    transaction_id,
    invoice_id,
    transaction_type,
    status,
    try_strptime(created_at_utc, '%Y-%m-%d %H:%M:%S')
        at time zone 'UTC' as event_timestamp_utc,
    country,
    currency,
    try_cast(currency_exponent as smallint) as currency_exponent,
    -- Shift minor units into major units exactly, without floating-point division.
    case when try_cast(currency_exponent as smallint) between 0 and 8
        then try_cast(
            try_cast(local_amount as decimal(28, 0))
            * try_cast('1e-' || currency_exponent as decimal(9, 8))
            as decimal(20, 8)
        )
    end as local_amount,
    try_cast(fx_rate as decimal(18, 10)) as fx_rate,
    try_cast(usd_amount as decimal(20, 8)) as usd_amount,
    try_cast(fee_usd as decimal(20, 8)) as fee_usd,
    source_file
from deduplicated
