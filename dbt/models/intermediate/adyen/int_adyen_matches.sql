{{ config(materialized='table', schema='intermediate') }}

select
    e.psp,
    e.engine_txn_id,
    p.provider_event_id,
    'psp_reference' as match_method
from {{ ref('int_payment_engine_events') }} as e
join {{ ref('int_adyen_events') }} as p
    on e.psp = p.psp and e.psp_reference = p.psp_reference
where e.psp = 'adyen' and p.operation_type = 'SALE'

union all

select
    e.psp,
    e.engine_txn_id,
    p.provider_event_id,
    'order_and_operation' as match_method
from {{ ref('int_payment_engine_events') }} as e
join {{ ref('int_adyen_events') }} as p
    on e.psp = p.psp
    and e.order_id = p.order_id
    and e.operation_type = p.operation_type
where e.psp = 'adyen'
    and p.operation_type in ('REFUND', 'CHARGEBACK')
