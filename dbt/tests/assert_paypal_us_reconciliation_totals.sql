-- Independently reproduce the canonical source totals used by reconciliation.
with engine as (
    select
        count(*) as records,
        count(*) filter (where status = 'settled'
            and operation_type in ('SALE', 'REFUND', 'CHARGEBACK')) as financial_events,
        coalesce(sum(case when status = 'settled'
            and operation_type in ('SALE', 'REFUND', 'CHARGEBACK') then
                case when operation_type in ('REFUND', 'CHARGEBACK') then -amount_usd
                    else amount_usd end else 0 end), 0) as principal
    from {{ ref('stg_payment_engine') }}
    where psp = 'paypal_us'
        and date_trunc('month', (case when status = 'settled' then captured_at_utc
            else created_at_utc end) at time zone 'UTC')::date
            = cast('{{ var("report_month") }}' as date)
),
provider as (
    select
        count(*) as records,
        count(*) filter (where (transaction_type = 'Website Payment' and status = 'Completed')
            or (transaction_type = 'Refund' and status = 'Refunded')) as financial_events,
        coalesce(sum(case when (transaction_type = 'Website Payment' and status = 'Completed')
            or (transaction_type = 'Refund' and status = 'Refunded')
            then gross_amount else 0 end), 0) as principal,
        coalesce(sum(-fee_amount), 0) as fees
    from {{ ref('stg_paypal_us') }}
    where date_trunc('month', event_timestamp_utc at time zone 'UTC')::date
        = cast('{{ var("report_month") }}' as date)
),
detail as (
    select
        coalesce(sum(engine_in_period::integer), 0) as engine_records,
        coalesce(sum(provider_in_period::integer), 0) as provider_records,
        coalesce(sum((engine_in_period and engine_is_financial_event)::integer), 0)
            as engine_financial_events,
        coalesce(sum((provider_in_period and provider_is_financial_event)::integer), 0)
            as provider_financial_events,
        coalesce(sum(engine_recognized_usd), 0) as engine_principal,
        coalesce(sum(provider_recognized_usd), 0) as provider_principal
    from {{ ref('mart_reconciliation_detail') }}
    where psp = 'paypal_us'
),
fees as (
    select coalesce(sum(f.fee_amount), 0) as amount
    from {{ ref('int_paypal_us_fees') }} as f
    join {{ ref('int_paypal_us_events') }} as p using (psp, provider_event_id)
    where date_trunc('month', p.event_timestamp_utc at time zone 'UTC')::date
        = cast('{{ var("report_month") }}' as date)
)

select *
from engine as e cross join provider as p cross join detail as d cross join fees as f
where e.records <> d.engine_records
    or e.financial_events <> d.engine_financial_events
    or e.principal <> d.engine_principal
    or p.records <> d.provider_records
    or p.financial_events <> d.provider_financial_events
    or p.principal <> d.provider_principal
    or p.fees <> f.amount
