{{ config(materialized='table', schema='intermediate') }}

select
    concat_ws('|',
        strftime(event_timestamp_utc at time zone 'UTC', '%Y-%m-%dT%H:%M:%S'),
        lower(replace(transaction_type, ' ', '_')),
        product_id,
        buyer_country,
        buyer_currency
    ) as provider_event_id,
    'google_play' as psp,
    'LumoPlayMain' as provider_account,
    source_file,
    cast(null as varchar) as psp_reference,
    cast(null as varchar) as parent_psp_reference,
    cast(null as varchar) as order_id,
    case transaction_type
        when 'Charge' then 'SALE'
        when 'Charge refund' then 'REFUND'
    end as operation_type,
    transaction_type as source_status,
    'settled' as status,
    event_timestamp_utc,
    buyer_country as country,
    product_id as sku,
    buyer_currency as currency,
    buyer_amount as amount_local_signed,
    merchant_amount as amount_usd_reported,
    currency_conversion_rate as fx_rate_reported,
    true as is_financial_event
from {{ ref('stg_google_play') }}
where transaction_type in ('Charge', 'Charge refund')
