{{ config(materialized='table', schema='intermediate') }}

with charges as (
    select
        event_timestamp_utc,
        sku,
        country,
        currency,
        fx_rate_reported,
        source_file,
        min(provider_event_id) as provider_event_id,
        count(*) as charge_count
    from {{ ref('int_google_play_events') }}
    where operation_type = 'SALE'
    group by event_timestamp_utc, sku, country, currency,
        fx_rate_reported, source_file
),

fees as (
    select
        *,
        count(*) over (
            partition by event_timestamp_utc, product_id, buyer_country,
                buyer_currency, currency_conversion_rate, source_file
        ) as fee_count
    from {{ ref('stg_google_play') }}
    where transaction_type = 'Google fee'
)

select
    case when f.fee_count = 1 and c.charge_count = 1
        then c.provider_event_id end as provider_event_id,
    'google_play' as psp,
    'LumoPlayMain' as provider_account,
    'total' as fee_type,
    f.merchant_currency as currency,
    -f.merchant_amount as fee_amount,
    f.source_file
from fees as f
left join charges as c
    on f.event_timestamp_utc = c.event_timestamp_utc
    and f.product_id = c.sku
    and f.buyer_country = c.country
    and f.buyer_currency = c.currency
    and f.currency_conversion_rate = c.fx_rate_reported
    and f.source_file = c.source_file
