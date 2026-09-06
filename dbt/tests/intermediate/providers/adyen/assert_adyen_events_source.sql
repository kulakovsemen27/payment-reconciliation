with source_events as (
    select
        *,
        psp_reference || ':' || lower(case record_type
            when 'Settled' then 'SALE' when 'Refused' then 'SALE'
            when 'Refunded' then 'REFUND' when 'Chargeback' then 'CHARGEBACK'
        end) as provider_event_id
    from {{ ref('stg_adyen') }}
    where record_type in ('Settled', 'Refused', 'Refunded', 'Chargeback')
),

event_differences as (
    select coalesce(e.provider_event_id, s.provider_event_id) as provider_event_id
    from source_events as s
    full outer join {{ ref('int_adyen_events') }} as e
        on e.psp = 'adyen' and e.provider_event_id = s.provider_event_id
    where s.provider_event_id is null
        or e.provider_event_id is null
        or e.psp_reference is distinct from s.psp_reference
        or e.order_id is distinct from s.merchant_reference
        or e.provider_account is distinct from s.merchant_account
        or e.currency is distinct from s.gross_currency
        or e.amount_local_signed is distinct from coalesce(s.gross_credit, -s.gross_debit)
        or e.operation_type is distinct from case s.record_type
            when 'Settled' then 'SALE' when 'Refused' then 'SALE'
            when 'Refunded' then 'REFUND' when 'Chargeback' then 'CHARGEBACK' end
        or e.status is distinct from case s.record_type
            when 'Refused' then 'declined' else 'settled' end
        or e.is_financial_event is distinct from (s.record_type <> 'Refused')
),

unresolved_authorisations as (
    select a.psp_reference as provider_event_id
    from {{ ref('stg_adyen') }} as a
    where a.record_type = 'Authorised'
        and not exists (
            select 1
            from {{ ref('stg_adyen') }} as final
            where final.psp_reference = a.psp_reference
                and final.record_type in ('Settled', 'Refused')
        )
)

select * from event_differences
union all
select * from unresolved_authorisations
