with detail as (
    select
        report_month,
        psp,
        provider_account,
        fee_currency,
        cause,
        count(*) as event_count,
        sum(reported_fee_local) as reported_fee_local,
        sum(expected_fee_local) as expected_fee_local,
        sum(signed_fee_variance_usd) as signed_fee_variance_usd
    from {{ ref('mart_fee_reconciliation_detail') }}
    group by report_month, psp, provider_account, fee_currency, cause
)

select coalesce(d.psp, s.psp) as psp
from detail as d
full outer join {{ ref('mart_fee_reconciliation_summary') }} as s
    on d.report_month = s.report_month
    and d.psp = s.psp
    and d.provider_account = s.provider_account
    and d.fee_currency = s.fee_currency
    and d.cause = s.cause
where d.psp is null
    or s.psp is null
    or d.event_count is distinct from s.event_count
    or d.reported_fee_local is distinct from s.reported_fee_local
    or d.expected_fee_local is distinct from s.expected_fee_local
    or d.signed_fee_variance_usd is distinct from s.signed_fee_variance_usd
