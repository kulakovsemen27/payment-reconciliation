with implemented as (
    select distinct psp from {{ ref('int_provider_events') }}
),

duplicates as (
    select 'engine_reference' as key_type, e.psp, e.psp_reference as key
    from {{ ref('int_payment_engine_events') }} as e
    join implemented using (psp)
    where e.psp_reference is not null
    group by e.psp, e.psp_reference
    having count(*) > 1

    union all

    select 'provider_reference', psp, psp_reference
    from {{ ref('int_provider_events') }}
    where psp_reference is not null
    group by psp, psp_reference
    having count(*) > 1

    union all

    select 'provider_event_id', psp, provider_event_id
    from {{ ref('int_provider_events') }}
    group by psp, provider_event_id
    having count(*) > 1
)

select * from duplicates
