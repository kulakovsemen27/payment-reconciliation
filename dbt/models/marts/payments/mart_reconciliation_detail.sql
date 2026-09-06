{{ config(materialized='table', schema='marts') }}

with engine as (
    select *
    from {{ ref('int_payment_engine_events') }}
),

provider as (
    select * from {{ ref('int_provider_events') }}
),

-- Retain unmatched events from either side, including when a provider has no rows.
pairs as (
    select
        psp,
        engine_txn_id,
        provider_event_id,
        match_method,
        'matched' as match_status
    from {{ ref('int_provider_matches') }}

    union all

    select
        e.psp,
        e.engine_txn_id,
        cast(null as varchar) as provider_event_id,
        cast(null as varchar) as match_method,
        'engine_only' as match_status
    from engine as e
    where not exists (
        select 1
        from {{ ref('int_provider_matches') }} as m
        where m.psp = e.psp and m.engine_txn_id = e.engine_txn_id
    )

    union all

    select
        p.psp,
        cast(null as varchar) as engine_txn_id,
        p.provider_event_id,
        cast(null as varchar) as match_method,
        'provider_only' as match_status
    from provider as p
    where not exists (
        select 1
        from {{ ref('int_provider_matches') }} as m
        where m.psp = p.psp and m.provider_event_id = p.provider_event_id
    )
),

-- Matching precedes the month filter so late settlements remain linked across periods.
matched as (
    select
        cast('{{ var("report_month") }}' as date) as report_month,
        pairs.psp,
        e.engine_txn_id,
        p.provider_event_id,
        pairs.match_method,
        pairs.match_status,
        e.operation_type as engine_operation_type,
        p.operation_type as provider_operation_type,
        e.status as engine_status,
        p.status as provider_status,
        e.currency as engine_currency,
        p.currency as provider_currency,
        e.fx_date_applied as engine_fx_date,
        p.fx_date_selected as provider_fx_date,
        e.fx_rate_applied as engine_fx_rate,
        p.fx_rate_reported as provider_fx_rate_reported,
        p.fx_rate_selected as provider_fx_rate,
        e.amount_local_signed as engine_amount_local_signed,
        p.amount_local_signed as provider_amount_local_signed,
        e.amount_usd_signed as engine_amount_usd_signed,
        p.amount_usd_reported as provider_amount_usd_reported,
        p.amount_usd_normalized as provider_amount_usd_normalized,
        e.event_timestamp_utc as engine_event_timestamp_utc,
        p.event_timestamp_utc as provider_event_timestamp_utc,
        case when e.engine_txn_id is null then false else e.is_financial_event end
            as engine_is_financial_event,
        case when p.provider_event_id is null then false else p.is_financial_event end
            as provider_is_financial_event,
        case when e.engine_txn_id is null then false else
            date_trunc('month', e.scope_timestamp_utc at time zone 'UTC')::date
                = cast('{{ var("report_month") }}' as date) end as engine_in_period,
        case when p.provider_event_id is null then false else
            date_trunc('month', p.event_timestamp_utc at time zone 'UTC')::date
                = cast('{{ var("report_month") }}' as date) end as provider_in_period
    from pairs
    left join engine as e
        on pairs.psp = e.psp and pairs.engine_txn_id = e.engine_txn_id
    left join provider as p
        on pairs.psp = p.psp and pairs.provider_event_id = p.provider_event_id
),

measured as (
    select
        *,
        cast(case when not engine_in_period or not engine_is_financial_event then 0
            else engine_amount_usd_signed end as decimal(38, 18)) as engine_recognized_usd,
        cast(case when not provider_in_period or not provider_is_financial_event then 0
            else round(provider_amount_usd_normalized, 2) end as decimal(38, 18))
            as provider_recognized_usd,
        case when match_status = 'matched' then
            engine_operation_type is distinct from provider_operation_type end
            as operation_type_differs,
        case when match_status = 'matched' then
            engine_status is distinct from provider_status end as status_differs,
        case when match_status = 'matched' then
            engine_currency is distinct from provider_currency end as currency_differs,
        case when engine_currency = provider_currency
            then provider_amount_local_signed - engine_amount_local_signed end
            as amount_local_difference,
        provider_amount_usd_normalized - engine_amount_usd_signed
            as amount_usd_difference
    from matched
    where engine_in_period or provider_in_period
        or engine_in_period is null or provider_in_period is null
),

impacts as (
    select
        *,
        provider_recognized_usd - engine_recognized_usd as signed_usd_impact
    from measured
)

select
    *,
    abs(signed_usd_impact) as absolute_usd_impact,
    -- First applicable cause wins: missing/status/timing differences precede valuation.
    case
        when engine_recognized_usd is null or provider_recognized_usd is null
            or engine_in_period is null or provider_in_period is null
            or engine_is_financial_event is null
            or provider_is_financial_event is null then 'unexplained'
        when match_status = 'engine_only' then 'engine_only'
        when match_status = 'provider_only'
            and provider_operation_type = 'REFUND' then 'refund_missing_in_engine'
        when match_status = 'provider_only'
            and provider_operation_type = 'REVERSAL' then 'reversal_missing_in_engine'
        when match_status = 'provider_only'
            and provider_operation_type = 'CHARGEBACK' then 'chargeback_missing_in_engine'
        when match_status = 'provider_only' then 'provider_only'
        when operation_type_differs or currency_differs then 'unexplained'
        when status_differs then 'status_lifecycle_difference'
        when engine_is_financial_event and provider_is_financial_event
            and engine_in_period <> provider_in_period then 'cutoff_timing'
        when signed_usd_impact <> 0 and amount_local_difference = 0
            and engine_fx_rate is distinct from
                coalesce(provider_fx_rate_reported, provider_fx_rate) then 'fx_difference'
        when signed_usd_impact <> 0 and abs(signed_usd_impact) <= 0.01
            and amount_local_difference = 0
            and engine_fx_rate is not distinct from
                coalesce(provider_fx_rate_reported, provider_fx_rate)
            then 'rounding_difference'
        when signed_usd_impact <> 0 then 'amount_difference'
        else 'matched'
    end as cause
from impacts
