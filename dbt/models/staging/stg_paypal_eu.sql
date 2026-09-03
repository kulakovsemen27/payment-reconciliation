{{
    config(
        materialized='table',
        schema='staging'
    )
}}

with deduplicated as (
    select distinct
        *
    from {{ ref('paypal_eu_activity') }}
),

parsed_dates as (
    select
        *,
        -- Parse without timezone first to reject invalid calendar dates.
        try_strptime("Date" || ' ' || "Time", '%d/%m/%Y %H:%M:%S') as local_timestamp
    from deduplicated
)

select
    "Transaction ID" as transaction_id,
    "Reference Txn ID" as reference_txn_id,
    "Invoice ID" as invoice_id,
    "Type" as transaction_type,
    "Status" as status,
    "Name" as payer_name,
    "Currency" as currency,
    try_cast(replace("Gross", ',', '.') as decimal(20, 8)) as gross_amount,
    try_cast(replace("Fee", ',', '.') as decimal(20, 8)) as fee_amount,
    try_cast(replace("Net", ',', '.') as decimal(20, 8)) as net_amount,
    "Date" as date_raw,
    "Time" as time_raw,
    "Time Zone" as time_zone,
    try_strptime(
        strftime(local_timestamp, '%Y-%m-%d %H:%M:%S') || ' ' || "Time Zone",
        '%Y-%m-%d %H:%M:%S %Z'
    ) as event_timestamp_utc,
    source_file
from parsed_dates
