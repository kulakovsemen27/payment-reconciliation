{{ 
  config(
    materialized='table',
    schema='staging'
    ) 
}}

select
    txn_id,
    order_id,
    operation_type,
    status,
    psp,
    psp_reference,
    sku,
    country,
    currency,

    cast(amount_local as decimal(20, 8)) as amount_local,
    cast(fx_rate_applied as decimal(18, 10)) as fx_rate_applied,
    cast(fx_date_applied as date) as fx_date_applied,
    cast(amount_usd as decimal(20, 8)) as amount_usd,
    cast(created_at_utc as timestamptz) as created_at_utc,
    cast(captured_at_utc as timestamptz) as captured_at_utc
from {{ ref('payment_engine_log') }}
