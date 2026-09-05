{{ config(materialized='table', schema='intermediate') }}

select
    txn_id as engine_txn_id,
    psp,
    psp_reference,
    order_id,
    operation_type,
    status,
    currency,
    fx_date_applied,
    fx_rate_applied,
    case when operation_type in ('REFUND', 'CHARGEBACK')
        then -amount_local else amount_local end as amount_local_signed,
    cast(case when operation_type in ('REFUND', 'CHARGEBACK')
        then -amount_usd else amount_usd end as decimal(38, 18)) as amount_usd_signed,
    case
        when status = 'settled' then captured_at_utc
        when status = 'declined' then created_at_utc
    end as event_timestamp_utc,
    case when status = 'settled' then captured_at_utc else created_at_utc end
        as scope_timestamp_utc,
    case
        when status = 'settled'
            and operation_type in ('SALE', 'REFUND', 'CHARGEBACK') then true
        when status in ('pending', 'declined') then false
    end as is_financial_event
from {{ ref('stg_payment_engine') }}
