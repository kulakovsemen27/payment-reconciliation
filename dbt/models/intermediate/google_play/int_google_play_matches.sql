{{ config(materialized='table', schema='intermediate') }}

select
    e.psp,
    e.engine_txn_id,
    p.provider_event_id,
    'timestamp_and_attributes' as match_method
from {{ ref('int_payment_engine_events') }} as e
join {{ ref('int_google_play_events') }} as p
    on e.psp = p.psp
    and e.event_timestamp_utc = p.event_timestamp_utc
    and e.operation_type = p.operation_type
    and e.sku = p.sku
    and e.country = p.country
    and e.currency = p.currency
where e.psp = 'google_play'
qualify count(*) over (partition by e.engine_txn_id) = 1
    and count(*) over (partition by p.provider_event_id) = 1
