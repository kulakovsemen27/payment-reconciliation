with rows_by_source as (
    select psp, engine_txn_id, provider_event_id, match_status, 1 as balance
    from {{ ref('int_paypal_us_matches') }}
    union all
    select psp, engine_txn_id, provider_event_id, match_status, -1 as balance
    from {{ ref('int_paypal_us_comparison') }}
)

select psp, engine_txn_id, provider_event_id, match_status
from rows_by_source
group by psp, engine_txn_id, provider_event_id, match_status
having sum(balance) <> 0
