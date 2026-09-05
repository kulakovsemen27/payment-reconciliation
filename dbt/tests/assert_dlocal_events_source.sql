select coalesce(e.provider_event_id, s.transaction_id) as provider_event_id
from {{ ref('stg_dlocal') }} as s
full outer join {{ ref('int_dlocal_events') }} as e
    on e.psp = 'dlocal' and e.provider_event_id = s.transaction_id
where s.transaction_id is null
    or e.provider_event_id is null
    or e.psp_reference is distinct from s.transaction_id
    or e.order_id is distinct from s.invoice_id
    or e.country is distinct from s.country
    or e.currency is distinct from s.currency
    or e.amount_local_signed is distinct from
        case when s.transaction_type = 'REFUND' then -s.local_amount else s.local_amount end
    or e.amount_usd_reported is distinct from
        case when s.transaction_type = 'REFUND' then -s.usd_amount else s.usd_amount end
    or e.fx_rate_reported is distinct from cast(1 / s.fx_rate as decimal(18, 10))
    or e.operation_type is distinct from case s.transaction_type
        when 'PAYMENT' then 'SALE' when 'REFUND' then 'REFUND' else 'OTHER' end
    or e.status is distinct from case s.status
        when 'PAID' then 'settled' when 'REFUNDED' then 'settled'
        when 'REJECTED' then 'declined' when 'IN_MEDIATION' then 'disputed'
        else 'unknown' end
    or e.is_financial_event is distinct from case
        when s.transaction_type = 'PAYMENT' and s.status = 'PAID' then true
        when s.transaction_type = 'REFUND' and s.status = 'REFUNDED' then true
        when s.transaction_type = 'PAYMENT'
            and s.status in ('REJECTED', 'IN_MEDIATION') then false end
