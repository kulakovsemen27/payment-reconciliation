select m.*
from {{ ref('int_paypal_us_matches') }} as m
left join {{ ref('stg_payment_engine') }} as e
    on m.psp = e.psp and m.engine_txn_id = e.txn_id
left join {{ ref('int_paypal_us_events') }} as p
    on m.psp = p.psp and m.provider_event_id = p.provider_event_id
where (m.engine_txn_id is null and m.provider_event_id is null)
    or m.match_status is distinct from (
        case
            when m.engine_txn_id is null then 'provider_only'
            when m.provider_event_id is null then 'engine_only'
            else 'matched'
        end
    )
    or (
        m.engine_txn_id is not null and m.provider_event_id is not null
        and (e.psp_reference is null or e.psp_reference is distinct from p.psp_reference)
    )
    or (m.match_status = 'engine_only' and exists (
        select 1 from {{ ref('int_paypal_us_events') }} as candidate
        where candidate.psp = e.psp and candidate.psp_reference = e.psp_reference
    ))
    or (m.match_status = 'provider_only' and exists (
        select 1 from {{ ref('stg_payment_engine') }} as candidate
        where candidate.psp = p.psp and candidate.psp_reference = p.psp_reference
    ))
