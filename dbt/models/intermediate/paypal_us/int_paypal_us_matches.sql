{{ config(materialized='table', schema='intermediate') }}

select
    e.psp,
    e.engine_txn_id,
    p.provider_event_id,
    'psp_reference' as match_method
from {{ ref('int_payment_engine_events') }} as e
join {{ ref('int_paypal_us_events') }} as p
    on e.psp = p.psp and e.psp_reference = p.psp_reference
where e.psp = 'paypal_us'
