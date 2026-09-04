-- Every input operation must appear exactly once, including unmatched operations.
with ids as (
    select 'engine' as source_side, psp, txn_id as source_id, 1 as expected, 0 as actual
    from {{ ref('stg_payment_engine') }}
    where psp = 'paypal_us'
    union all
    select 'provider', psp, provider_event_id, 1, 0
    from {{ ref('int_paypal_us_events') }}
    union all
    select 'engine', psp, engine_txn_id, 0, 1
    from {{ ref('int_paypal_us_matches') }}
    where engine_txn_id is not null
    union all
    select 'provider', psp, provider_event_id, 0, 1
    from {{ ref('int_paypal_us_matches') }}
    where provider_event_id is not null
)

select source_side, psp, source_id, sum(expected) as expected_count, sum(actual) as actual_count
from ids
group by source_side, psp, source_id
having sum(expected) <> 1 or sum(actual) <> 1
