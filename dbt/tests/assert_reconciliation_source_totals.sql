with engine as (
    select psp,
        count(*) as records,
        sum(is_financial_event::integer) as financial_events,
        sum(case when is_financial_event then amount_usd_signed else 0 end) as amount_usd
    from {{ ref('int_payment_engine_events') }}
    where date_trunc('month', scope_timestamp_utc at time zone 'UTC')::date
        = cast('{{ var("report_month") }}' as date)
    group by psp
),
provider as (
    select psp,
        count(*) as records,
        sum(is_financial_event::integer) as financial_events,
        sum(case when is_financial_event then round(amount_usd_normalized, 2) else 0 end)
            as amount_usd
    from {{ ref('int_provider_events') }}
    where date_trunc('month', event_timestamp_utc at time zone 'UTC')::date
        = cast('{{ var("report_month") }}' as date)
    group by psp
),
detail as (
    select psp,
        sum(engine_in_period::integer) as engine_records,
        sum(provider_in_period::integer) as provider_records,
        sum((engine_in_period and engine_is_financial_event)::integer)
            as engine_financial_events,
        sum((provider_in_period and provider_is_financial_event)::integer)
            as provider_financial_events,
        sum(engine_recognized_usd) as engine_amount_usd,
        sum(provider_recognized_usd) as provider_amount_usd
    from {{ ref('mart_reconciliation_detail') }}
    group by psp
)

select coalesce(e.psp, p.psp, d.psp) as psp
from engine as e
full outer join provider as p using (psp)
full outer join detail as d on d.psp = coalesce(e.psp, p.psp)
-- An absent source group contributes zero; NULL values in an existing group do not.
where d.psp is null
    or coalesce(e.records, 0) is distinct from d.engine_records
    or coalesce(p.records, 0) is distinct from d.provider_records
    or (case when e.psp is null then 0 else e.financial_events end)
        is distinct from d.engine_financial_events
    or (case when p.psp is null then 0 else p.financial_events end)
        is distinct from d.provider_financial_events
    or (case when e.psp is null then 0 else e.amount_usd end)
        is distinct from d.engine_amount_usd
    or (case when p.psp is null then 0 else p.amount_usd end)
        is distinct from d.provider_amount_usd
