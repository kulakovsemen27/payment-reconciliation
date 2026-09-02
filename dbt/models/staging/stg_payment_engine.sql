{{ 
  config(
    materialized='table'
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

    amount_local as amount_local_raw,
    cast(amount_local as decimal(20, 8)) as amount_local,
    fx_rate_applied as fx_rate_applied_raw,
    cast(fx_rate_applied as decimal(18, 10)) as fx_rate_applied,
    fx_date_applied as fx_date_applied_raw,
    cast(fx_date_applied as date) as fx_date_applied,
    amount_usd as amount_usd_raw,
    cast(amount_usd as decimal(20, 8)) as amount_usd,
    created_at_utc as created_at_utc_raw,
    cast(created_at_utc as timestamptz) as created_at_utc,
    captured_at_utc as captured_at_utc_raw,
    cast(captured_at_utc as timestamptz) as captured_at_utc
from {{ ref('payment_engine_log') }}
