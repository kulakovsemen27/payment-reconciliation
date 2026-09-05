{{ config(materialized='table', schema='marts') }}

with engine as (
    select *
    from {{ ref('int_payment_engine_events') }}
    where psp in (select distinct psp from {{ ref('int_provider_events') }})
),

matched as (
    select
        cast('{{ var("report_month") }}' as date) as report_month,
        coalesce(e.psp, p.psp) as psp,
        e.engine_txn_id,
        p.provider_event_id,
        case when e.engine_txn_id is null then 'provider_only'
            when p.provider_event_id is null then 'engine_only'
            else 'matched' end as match_status,
        e.operation_type as engine_operation_type,
        p.operation_type as provider_operation_type,
        e.status as engine_status,
        p.status as provider_status,
        e.currency as engine_currency,
        p.currency as provider_currency,
        e.amount_local_signed as engine_amount_local_signed,
        p.amount_local_signed as provider_amount_local_signed,
        e.amount_usd_signed as engine_amount_usd_signed,
        p.amount_usd_reported as provider_amount_usd_reported,
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
    from engine as e
    full outer join {{ ref('int_provider_events') }} as p
        on e.psp = p.psp and e.psp_reference = p.psp_reference
),

measured as (
    select
        *,
        cast(case when not engine_in_period or not engine_is_financial_event then 0
            else engine_amount_usd_signed end as decimal(38, 18)) as engine_recognized_usd,
        cast(case when not provider_in_period or not provider_is_financial_event then 0
            else provider_amount_usd_reported end as decimal(38, 18)) as provider_recognized_usd,
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
        provider_amount_usd_reported - engine_amount_usd_signed
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
    case
        when engine_recognized_usd is null or provider_recognized_usd is null
            or engine_in_period is null or provider_in_period is null
            or engine_is_financial_event is null
            or provider_is_financial_event is null then 'unexplained'
        when match_status = 'engine_only' then 'engine_only'
        when match_status = 'provider_only' then 'provider_only'
        when operation_type_differs or currency_differs then 'unexplained'
        when status_differs then 'status_lifecycle_difference'
        when engine_is_financial_event and provider_is_financial_event
            and engine_in_period <> provider_in_period then 'cutoff_timing'
        when signed_usd_impact <> 0 or amount_usd_difference <> 0
            or amount_local_difference <> 0 then 'amount_difference'
        else 'matched'
    end as cause
from impacts
