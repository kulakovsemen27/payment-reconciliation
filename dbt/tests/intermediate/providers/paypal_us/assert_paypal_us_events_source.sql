-- No event is filtered or deduplicated again; principal must retain source values.
select coalesce(e.provider_event_id, s.transaction_id) as provider_event_id
from {{ ref('stg_paypal_us') }} as s
full outer join {{ ref('int_paypal_us_events') }} as e
    on e.psp = 'paypal_us' and e.provider_event_id = s.transaction_id
where s.transaction_id is null
    or e.provider_event_id is null
    or e.psp_reference is distinct from s.transaction_id
    or e.currency is distinct from s.currency
    or e.amount_local_signed is distinct from s.gross_amount
    or e.amount_usd_reported is distinct from (
        case when s.currency = 'USD' then s.gross_amount end
    )
    or e.operation_type is distinct from case s.transaction_type
        when 'Website Payment' then 'SALE' when 'Refund' then 'REFUND' else 'OTHER' end
    or e.status is distinct from case s.status
        when 'Completed' then 'settled' when 'Refunded' then 'settled'
        when 'Denied' then 'declined' else 'unknown' end
    or e.is_financial_event is distinct from case
        when s.transaction_type = 'Website Payment' and s.status = 'Completed' then true
        when s.transaction_type = 'Refund' and s.status = 'Refunded' then true
        when s.transaction_type = 'Website Payment' and s.status = 'Denied' then false end
    or (e.operation_type = 'SALE' and e.amount_local_signed < 0)
    or (e.operation_type = 'REFUND' and e.amount_local_signed > 0)
