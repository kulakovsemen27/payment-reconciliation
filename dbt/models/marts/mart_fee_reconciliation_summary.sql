{{ config(materialized='table', schema='marts') }}

select
    report_month,
    psp,
    provider_account,
    fee_currency,
    cause,
    count(*) as event_count,
    sum(reported_fee_local) as reported_fee_local,
    sum(expected_fee_local) as expected_fee_local,
    sum(signed_fee_variance_local) as signed_fee_variance_local,
    sum(reported_fee_usd) as reported_fee_usd,
    sum(expected_fee_usd) as expected_fee_usd,
    sum(signed_fee_variance_usd) as signed_fee_variance_usd,
    sum(absolute_fee_variance_usd) as absolute_fee_variance_usd
from {{ ref('mart_fee_reconciliation_detail') }}
group by report_month, psp, provider_account, fee_currency, cause
