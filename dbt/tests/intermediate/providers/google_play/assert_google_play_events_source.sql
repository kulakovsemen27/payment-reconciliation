with source as (
    select
        count(*) as records,
        sum(buyer_amount) as amount_local,
        sum(merchant_amount) as amount_usd,
        count(*) filter (where merchant_currency <> 'USD') as non_usd_merchant_rows
    from {{ ref('stg_google_play') }}
    where transaction_type in ('Charge', 'Charge refund')
),

events as (
    select
        count(*) as records,
        sum(amount_local_signed) as amount_local,
        sum(amount_usd_reported) as amount_usd,
        count(*) filter (
            where provider_event_id is null
                or country is null
                or sku is null
        ) as incomplete_keys
    from {{ ref('int_google_play_events') }}
)

select 'google_play_events' as control
from source, events
where source.records is distinct from events.records
    or source.amount_local is distinct from events.amount_local
    or source.amount_usd is distinct from events.amount_usd
    or source.non_usd_merchant_rows <> 0
    or events.incomplete_keys <> 0
