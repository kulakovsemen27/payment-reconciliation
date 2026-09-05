with expected as (
    select
        report_month, psp, cause, count(*) as row_count,
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
),
actual as (
    select report_month, psp, cause, row_count,
        engine_record_count, provider_record_count,
        engine_financial_count, provider_financial_count,
        engine_amount_usd, provider_amount_usd,
        signed_usd_impact, absolute_usd_impact
    from {{ ref('mart_reconciliation_summary') }}
)

(select * from expected except all select * from actual)
union all
(select * from actual except all select * from expected)
