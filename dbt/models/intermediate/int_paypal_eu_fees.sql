{{ config(materialized='table', schema='intermediate') }}

select
    transaction_id as provider_event_id,
    'paypal_eu' as psp,
    cast(null as varchar) as provider_account,
    'total' as fee_type,
    currency,
    -fee_amount as fee_amount,
    source_file
from {{ ref('stg_paypal_eu') }}
