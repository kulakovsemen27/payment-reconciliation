{{ config(materialized='table', schema='marts') }}

with totals as (
    select
        report_month,
        psp,
        cause,
        count(*) as row_count,
        sum(engine_in_period::integer) as engine_record_count,
        sum(provider_in_period::integer) as provider_record_count,
        sum((engine_in_period and engine_is_financial_event)::integer)
            as engine_financial_count,
        sum((provider_in_period and provider_is_financial_event)::integer)
            as provider_financial_count,
        sum(engine_recognized_usd) as engine_amount_usd,
        sum(provider_recognized_usd) as provider_amount_usd,
        sum(signed_usd_impact) as signed_usd_impact,
        sum(absolute_usd_impact) as absolute_usd_impact
    from {{ ref('mart_reconciliation_detail') }}
    group by report_month, psp, cause
)

select
    *,
    provider_record_count - engine_record_count as record_count_difference,
    provider_financial_count - engine_financial_count as financial_count_difference,
    cast(100 * absolute_usd_impact / nullif(
        sum(absolute_usd_impact) over (partition by report_month), 0
    ) as decimal(9, 4)) as absolute_impact_share_pct
from totals
