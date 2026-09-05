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

date_candidates as (
    select
        *,
        try_strptime("Date" || ' ' || "Time", '%d/%m/%Y %H:%M:%S') as dmy_timestamp,
        try_strptime("Date" || ' ' || "Time", '%m/%d/%Y %H:%M:%S') as mdy_timestamp,
        try_strptime(
            regexp_extract(source_file, '_([0-9]{8})_([0-9]{8})[.]csv$', 1),
            '%Y%m%d'
        )::date as extract_start,
        try_strptime(
            regexp_extract(source_file, '_([0-9]{8})_([0-9]{8})[.]csv$', 2),
            '%Y%m%d'
        )::date as extract_end
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
        strftime(case
            when dmy_timestamp::date between extract_start and extract_end then dmy_timestamp
            when mdy_timestamp::date between extract_start and extract_end then mdy_timestamp
        end, '%Y-%m-%d %H:%M:%S') || ' ' || "Time Zone",
        '%Y-%m-%d %H:%M:%S %Z'
    ) as event_timestamp_utc,
    source_file
from date_candidates
