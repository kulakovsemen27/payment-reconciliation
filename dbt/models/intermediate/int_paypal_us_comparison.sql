{{ config(materialized='table', schema='intermediate') }}

with paired as (
    select
        m.*,
        e.operation_type as engine_operation_type,
        p.operation_type as provider_operation_type,
        e.status as engine_status,
        p.status as provider_status,
        e.currency as engine_currency,
        p.currency as provider_currency,
        -- Engine stores refund/chargeback magnitudes, not signed cash flows.
        case when e.operation_type in ('REFUND', 'CHARGEBACK')
            then -e.amount_local else e.amount_local
        end as engine_amount_local_signed,
        p.amount_local_signed as provider_amount_local_signed,
        case when e.operation_type in ('REFUND', 'CHARGEBACK')
            then -e.amount_usd else e.amount_usd
        end as engine_amount_usd_signed,
        p.amount_usd_reported as provider_amount_usd_reported,
        case
            when e.status = 'settled' then e.captured_at_utc
            when e.status = 'declined' then e.created_at_utc
        end as engine_event_timestamp_utc,
        p.event_timestamp_utc as provider_event_timestamp_utc
    from {{ ref('int_paypal_us_matches') }} as m
    left join {{ ref('stg_payment_engine') }} as e
        on m.psp = e.psp and m.engine_txn_id = e.txn_id
    left join {{ ref('int_paypal_us_events') }} as p
        on m.psp = p.psp and m.provider_event_id = p.provider_event_id
)

select
    *,
    case when match_status = 'matched'
        then engine_operation_type is distinct from provider_operation_type
    end as operation_type_differs,
    case when match_status = 'matched'
        then engine_status is distinct from provider_status
    end as status_differs,
    case when match_status = 'matched'
        then engine_currency is distinct from provider_currency
    end as currency_differs,
    case when engine_currency = provider_currency
        then provider_amount_local_signed - engine_amount_local_signed
    end as amount_local_difference,
    cast(provider_amount_usd_reported - engine_amount_usd_signed as decimal(38, 18))
        as amount_usd_difference,
    date_diff('second', engine_event_timestamp_utc, provider_event_timestamp_utc)
        as event_time_difference_seconds,
    cast(engine_event_timestamp_utc at time zone 'UTC' as date)
        <> cast(provider_event_timestamp_utc at time zone 'UTC' as date)
        as event_date_differs
from paired
