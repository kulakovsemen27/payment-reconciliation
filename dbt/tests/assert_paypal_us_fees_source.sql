-- One reported total fee per staged operation, including zero fees.
with fees as (
    select psp, provider_event_id, fee_type, currency,
        count(*) as fee_count, sum(fee_amount) as fee_amount
    from {{ ref('int_paypal_us_fees') }}
    group by psp, provider_event_id, fee_type, currency
)

select coalesce(f.provider_event_id, s.transaction_id) as provider_event_id
from {{ ref('stg_paypal_us') }} as s
full outer join fees as f
    on f.psp = 'paypal_us' and f.provider_event_id = s.transaction_id
left join {{ ref('int_paypal_us_events') }} as e
    on f.psp = e.psp and f.provider_event_id = e.provider_event_id
where s.transaction_id is null
    or f.provider_event_id is null
    or e.provider_event_id is null
    or f.fee_count <> 1
    or f.fee_type is distinct from 'total'
    or f.currency is distinct from s.currency
    or f.fee_amount is distinct from -s.fee_amount
