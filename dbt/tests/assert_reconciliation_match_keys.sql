with duplicates as (
    select 'engine_match' as key_type, psp, engine_txn_id as key
    from {{ ref('int_provider_matches') }}
    group by psp, engine_txn_id
    having count(*) > 1

    union all

    select 'provider_match', psp, provider_event_id
    from {{ ref('int_provider_matches') }}
    group by psp, provider_event_id
    having count(*) > 1

    union all

    select 'provider_event_id', psp, provider_event_id
    from {{ ref('int_provider_events') }}
    group by psp, provider_event_id
    having count(*) > 1
)

select * from duplicates
