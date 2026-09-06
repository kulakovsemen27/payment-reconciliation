with expected as (
    select e.psp, e.engine_txn_id, p.provider_event_id, 'psp_reference' as match_method
    from {{ ref('int_payment_engine_events') }} as e
    join {{ ref('int_adyen_events') }} as p
        on e.psp = p.psp and e.psp_reference = p.psp_reference
    where e.psp = 'adyen' and p.operation_type = 'SALE'

    union all

    select e.psp, e.engine_txn_id, p.provider_event_id, 'order_and_operation'
    from {{ ref('int_payment_engine_events') }} as e
    join {{ ref('int_adyen_events') }} as p
        on e.psp = p.psp
        and e.order_id = p.order_id
        and e.operation_type = p.operation_type
    where e.psp = 'adyen'
        and p.operation_type in ('REFUND', 'CHARGEBACK')
)

select
    coalesce(e.engine_txn_id, a.engine_txn_id) as engine_txn_id,
    coalesce(e.provider_event_id, a.provider_event_id) as provider_event_id
from expected as e
full outer join {{ ref('int_adyen_matches') }} as a
    on e.psp = a.psp
    and e.engine_txn_id = a.engine_txn_id
    and e.provider_event_id = a.provider_event_id
    and e.match_method = a.match_method
where e.engine_txn_id is null or a.engine_txn_id is null
