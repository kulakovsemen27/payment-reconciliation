{{ config(materialized='table', schema='intermediate') }}

select
    psp_reference || ':' || lower(case record_type
        when 'Settled' then 'SALE'
        when 'Refused' then 'SALE'
        when 'Refunded' then 'REFUND'
        when 'Chargeback' then 'CHARGEBACK'
    end) as provider_event_id,
    'adyen' as psp,
    merchant_account as provider_account,
    source_file,
    psp_reference,
    case when record_type in ('Refunded', 'Chargeback')
        then psp_reference end as parent_psp_reference,
    merchant_reference as order_id,
    case record_type
        when 'Settled' then 'SALE'
        when 'Refused' then 'SALE'
        when 'Refunded' then 'REFUND'
        when 'Chargeback' then 'CHARGEBACK'
    end as operation_type,
    record_type as source_status,
    case record_type
        when 'Settled' then 'settled'
        when 'Refused' then 'declined'
        when 'Refunded' then 'settled'
        when 'Chargeback' then 'settled'
    end as status,
    event_timestamp_utc,
    cast(null as varchar) as country,
    cast(null as varchar) as sku,
    gross_currency as currency,
    coalesce(gross_credit, -gross_debit) as amount_local_signed,
    case when gross_currency = 'USD'
        then coalesce(gross_credit, -gross_debit) end as amount_usd_reported,
    cast(null as decimal(18, 10)) as fx_rate_reported,
    record_type <> 'Refused' as is_financial_event
from {{ ref('stg_adyen') }}
where record_type in ('Settled', 'Refused', 'Refunded', 'Chargeback')
