with source as (
    select count(*) as records, -sum(merchant_amount) as fee_amount
    from {{ ref('stg_google_play') }}
    where transaction_type = 'Google fee'
),

fees as (
    select
        count(*) as records,
        sum(fee_amount) as fee_amount,
        count(*) filter (where provider_event_id is null) as unlinked_records
    from {{ ref('int_google_play_fees') }}
),

missing_events as (
    select count(*) as records
    from {{ ref('int_google_play_fees') }} as f
    left join {{ ref('int_google_play_events') }} as e
        on f.psp = e.psp and f.provider_event_id = e.provider_event_id
    where e.provider_event_id is null
)

select 'google_play_fees' as control
from source, fees, missing_events
where source.records is distinct from fees.records
    or source.fee_amount is distinct from fees.fee_amount
    or fees.unlinked_records <> 0
    or missing_events.records <> 0
