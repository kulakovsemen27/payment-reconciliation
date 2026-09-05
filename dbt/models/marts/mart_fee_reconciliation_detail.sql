{{ config(materialized='table', schema='marts') }}

with reported as (
    select
        psp,
        provider_event_id,
        provider_account,
        currency,
        sum(fee_amount) as reported_fee_local
    from {{ ref('int_provider_fees') }}
    group by psp, provider_event_id, provider_account, currency
),

contracted as (
    select
        cast('{{ var("report_month") }}' as date) as report_month,
        e.psp,
        e.provider_event_id,
        e.provider_account,
        e.event_timestamp_utc,
        e.currency as fee_currency,
        e.amount_local_signed as principal_amount_local,
        e.fx_rate_selected,
        schedule.valid_from as contract_valid_from,
        schedule.percent_fee,
        schedule.fixed_fee,
        schedule.fixed_fee_currency
    from {{ ref('int_provider_events') }} as e
    join lateral (
        select valid_from, percent_fee, fixed_fee, fixed_fee_currency
        from {{ ref('stg_fee_schedule') }} as schedule
        where schedule.psp = e.psp
            and schedule.account = e.provider_account
            and schedule.valid_from
                <= (e.event_timestamp_utc at time zone 'UTC')::date
        order by schedule.valid_from desc
        limit 1
    ) as schedule on true
    where e.operation_type = 'SALE'
        and e.status = 'settled'
        and e.is_financial_event
        and date_trunc('month', e.event_timestamp_utc at time zone 'UTC')::date
            = cast('{{ var("report_month") }}' as date)
),

valued as (
    select
        c.*,
        r.reported_fee_local,
        cast(case
            when c.fixed_fee = 0
                or c.fixed_fee_currency = c.fee_currency
            then round(
                abs(c.principal_amount_local) * c.percent_fee / 100 + c.fixed_fee,
                2
            )
        end as decimal(20, 8)) as expected_fee_local
    from contracted as c
    left join reported as r
        on c.psp = r.psp
        and c.provider_event_id = r.provider_event_id
        and c.provider_account = r.provider_account
        and c.fee_currency = r.currency
),

measured as (
    select
        *,
        reported_fee_local - expected_fee_local as signed_fee_variance_local,
        cast(round(reported_fee_local * fx_rate_selected, 2)
            as decimal(38, 18)) as reported_fee_usd,
        cast(round(expected_fee_local * fx_rate_selected, 2)
            as decimal(38, 18)) as expected_fee_usd
    from valued
)

select
    *,
    reported_fee_usd - expected_fee_usd as signed_fee_variance_usd,
    abs(reported_fee_usd - expected_fee_usd) as absolute_fee_variance_usd,
    case when reported_fee_local = expected_fee_local
        then 'matched' else 'fee_difference' end as cause
from measured
