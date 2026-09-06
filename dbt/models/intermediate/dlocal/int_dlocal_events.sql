{{ config(materialized='table', schema='intermediate') }}

select
    transaction_id as provider_event_id,
    'dlocal' as psp,
    cast(null as varchar) as provider_account,
    source_file,
    transaction_id as psp_reference,
    cast(null as varchar) as parent_psp_reference,
    invoice_id as order_id,
    case transaction_type
        when 'PAYMENT' then 'SALE'
        when 'REFUND' then 'REFUND'
        else 'OTHER'
    end as operation_type,
    status as source_status,
    case status
        when 'PAID' then 'settled'
        when 'REFUNDED' then 'settled'
        when 'REJECTED' then 'declined'
        when 'IN_MEDIATION' then 'disputed'
        else 'unknown'
    end as status,
    event_timestamp_utc,
    country,
    cast(null as varchar) as sku,
    currency,
    case when transaction_type = 'REFUND' then -local_amount else local_amount end
        as amount_local_signed,
    case when transaction_type = 'REFUND' then -usd_amount else usd_amount end
        as amount_usd_reported,
    cast(1 / fx_rate as decimal(18, 10)) as fx_rate_reported,
    case
        when transaction_type = 'PAYMENT' and status = 'PAID' then true
        when transaction_type = 'REFUND' and status = 'REFUNDED' then true
        when transaction_type = 'PAYMENT'
            and status in ('REJECTED', 'IN_MEDIATION') then false
    end as is_financial_event
from {{ ref('stg_dlocal') }}
