{{ config(materialized='table', schema='intermediate') }}

with events as (
    select * from {{ ref('int_paypal_us_events') }}
    union all
    select * from {{ ref('int_paypal_eu_events') }}
    union all
    select * from {{ ref('int_dlocal_events') }}
    union all
    select * from {{ ref('int_adyen_events') }}
    union all
    select * from {{ ref('int_google_play_events') }}
),

normalized as (
    select
        e.*,
        case when e.currency = 'USD' then cast(1 as decimal(18, 10))
            else f.usd_rate end as fx_rate_selected,
        f.rate_date as fx_date_selected
    from events as e
    -- Use the most recent rate date not after this event; revisions are resolved upstream.
    left join lateral (
        select rate_date, usd_rate
        from {{ ref('int_fx_rates') }} as rates
        where rates.currency = e.currency
            and rates.rate_date <= (e.event_timestamp_utc at time zone 'UTC')::date
        order by rates.rate_date desc
        limit 1
    ) as f on true
)

select
    *,
    cast(coalesce(
        amount_usd_reported,
        amount_local_signed * fx_rate_selected
    ) as decimal(38, 18)) as amount_usd_normalized
from normalized
