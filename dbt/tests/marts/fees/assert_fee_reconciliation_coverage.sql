with expected as (
    select e.psp, e.provider_event_id
    from {{ ref('int_provider_events') }} as e
    where e.operation_type = 'SALE'
        and e.status = 'settled'
        and e.is_financial_event
        and date_trunc('month', e.event_timestamp_utc at time zone 'UTC')::date
            = cast('{{ var("report_month") }}' as date)
        and exists (
            select 1
            from {{ ref('stg_fee_schedule') }} as schedule
            where schedule.psp = e.psp
                and schedule.account = e.provider_account
                and schedule.valid_from
                    <= (e.event_timestamp_utc at time zone 'UTC')::date
        )
)

select coalesce(e.provider_event_id, d.provider_event_id) as provider_event_id
from expected as e
full outer join {{ ref('mart_fee_reconciliation_detail') }} as d
    on e.psp = d.psp and e.provider_event_id = d.provider_event_id
where e.provider_event_id is null or d.provider_event_id is null
