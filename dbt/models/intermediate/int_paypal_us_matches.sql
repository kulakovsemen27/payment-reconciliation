{{ config(materialized='table', schema='intermediate') }}

with engine as (
    select txn_id, psp, psp_reference
    from {{ ref('stg_payment_engine') }}
    where psp = 'paypal_us'
)

select
    coalesce(e.psp, p.psp) as psp,
    e.txn_id as engine_txn_id,
    p.provider_event_id,
    case
        when e.txn_id is null then 'provider_only'
        when p.provider_event_id is null then 'engine_only'
        else 'matched'
    end as match_status
from engine as e
full outer join {{ ref('int_paypal_us_events') }} as p
    on e.psp = p.psp and e.psp_reference = p.psp_reference
