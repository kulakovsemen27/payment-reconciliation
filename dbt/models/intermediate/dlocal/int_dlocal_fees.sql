{{ config(materialized='table', schema='intermediate') }}

select
    transaction_id as provider_event_id,
    'dlocal' as psp,
    cast(null as varchar) as provider_account,
    'total' as fee_type,
    'USD' as currency,
    fee_usd as fee_amount,
    source_file
from {{ ref('stg_dlocal') }}
