{{ config(materialized='table', schema='intermediate') }}

select
    psp_reference || ':sale' as provider_event_id,
    'adyen' as psp,
    merchant_account as provider_account,
    'commission' as fee_type,
    net_currency as currency,
    commission as fee_amount,
    source_file
from {{ ref('stg_adyen') }}
where record_type = 'Settled'

union all

select
    psp_reference || ':sale' as provider_event_id,
    'adyen' as psp,
    merchant_account as provider_account,
    'markup' as fee_type,
    net_currency as currency,
    markup as fee_amount,
    source_file
from {{ ref('stg_adyen') }}
where record_type = 'Settled'
