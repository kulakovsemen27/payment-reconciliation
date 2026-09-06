with expected as (
    select
        psp_reference || ':sale' as provider_event_id,
        merchant_account as provider_account,
        'commission' as fee_type,
        net_currency as currency,
        commission as fee_amount
    from {{ ref('stg_adyen') }}
    where record_type = 'Settled'

    union all

    select
        psp_reference || ':sale',
        merchant_account,
        'markup',
        net_currency,
        markup
    from {{ ref('stg_adyen') }}
    where record_type = 'Settled'
)

select coalesce(e.provider_event_id, a.provider_event_id) as provider_event_id
from expected as e
full outer join {{ ref('int_adyen_fees') }} as a
    on a.psp = 'adyen'
    and e.provider_event_id = a.provider_event_id
    and e.provider_account = a.provider_account
    and e.fee_type = a.fee_type
    and e.currency = a.currency
    and e.fee_amount = a.fee_amount
left join {{ ref('int_adyen_events') }} as event
    on a.psp = event.psp and a.provider_event_id = event.provider_event_id
where e.provider_event_id is null
    or a.provider_event_id is null
    or event.provider_event_id is null
