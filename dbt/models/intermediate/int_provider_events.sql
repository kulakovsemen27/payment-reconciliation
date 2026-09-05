{{ config(materialized='table', schema='intermediate') }}

-- Add each provider adapter here after it implements the shared event contract.
select
    provider_event_id,
    psp,
    provider_account,
    source_file,
    psp_reference,
    parent_psp_reference,
    order_id,
    operation_type,
    source_status,
    status,
    event_timestamp_utc,
    country,
    sku,
    currency,
    amount_local_signed,
    amount_usd_reported,
    fx_rate_reported,
    is_financial_event
from {{ ref('int_paypal_us_events') }}
