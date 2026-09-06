{{ config(materialized='table', schema='intermediate') }}

select
    transaction_id as provider_event_id,
    'paypal_us' as psp,
    cast(null as varchar) as provider_account,
    source_file,
    transaction_id as psp_reference,
    reference_txn_id as parent_psp_reference,
    invoice_id as order_id,
    case transaction_type
        when 'Website Payment' then 'SALE'
        when 'Refund' then 'REFUND'
        else 'OTHER'
    end as operation_type,
    status as source_status,
    case status
        when 'Completed' then 'settled'
        when 'Refunded' then 'settled'
        when 'Denied' then 'declined'
        else 'unknown'
    end as status,
    event_timestamp_utc,
    cast(null as varchar) as country,
    cast(null as varchar) as sku,
    currency,
    -- Gross already has the source sign; Net includes fees and is not principal.
    gross_amount as amount_local_signed,
    case when currency = 'USD' then gross_amount end as amount_usd_reported,
    cast(null as decimal(18, 10)) as fx_rate_reported,
    case
        when transaction_type = 'Website Payment' and status = 'Completed' then true
        when transaction_type = 'Refund' and status = 'Refunded' then true
        when transaction_type = 'Website Payment' and status = 'Denied' then false
        else null
    end as is_financial_event
from {{ ref('stg_paypal_us') }}
