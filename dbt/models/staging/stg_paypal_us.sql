{{
    config(
        materialized='table',
        schema='staging'
    )
}}

with deduplicated as (
    select distinct
        *
    from {{ ref('paypal_us_activity') }}
),

parsed as (
    select
        "Date" as date_raw,
        "Time" as time_raw,
        "Time Zone" as time_zone,
        "Name" as payer_name,
        "Transaction ID" as transaction_id,
        "Reference Txn ID" as reference_txn_id,
        "Type" as transaction_type,
        "Status" as status,
        "Currency" as currency,
        try_cast("Gross" as decimal(20, 8)) as gross_amount,
        try_cast("Fee" as decimal(20, 8)) as fee_amount,
        try_cast("Net" as decimal(20, 8)) as net_amount,
        "Invoice ID" as invoice_id,
        source_file,
        -- Validate the calendar date first: timezone parsing can normalize invalid days.
        case
            when try_strptime("Date" || ' ' || "Time", '%m/%d/%Y %H:%M:%S') is not null
            then try_strptime(
                "Date" || ' ' || "Time" || ' ' || "Time Zone",
                '%m/%d/%Y %H:%M:%S %Z'
            )
        end as event_timestamp_utc
    from deduplicated
)

select
    transaction_id,
    reference_txn_id,
    invoice_id,
    transaction_type,
    status,
    payer_name,
    currency,
    gross_amount,
    fee_amount,
    net_amount,
    event_timestamp_utc,
    source_file
from parsed
