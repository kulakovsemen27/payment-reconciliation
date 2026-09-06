{{ config(materialized='table', schema='staging') }}

with deduplicated as (
    -- Same payment reference can have different lifecycle events; keep them.
    select distinct
        *,
        try_strptime("Creation Date", '%Y-%m-%d %H:%M:%S') as local_timestamp
    from {{ ref('adyen_payment_accounting') }}
)

select
    "Company Account" as company_account,
    "Merchant Account" as merchant_account,
    "Psp Reference" as psp_reference,
    "Merchant Reference" as merchant_reference,
    "Record Type" as record_type,
    try_strptime(
        strftime(local_timestamp, '%Y-%m-%d %H:%M:%S') || ' ' || "TimeZone",
        '%Y-%m-%d %H:%M:%S %Z'
    ) as event_timestamp_utc,
    "Gross Currency" as gross_currency,
    try_cast("Gross Debit" as decimal(20, 8)) as gross_debit,
    try_cast("Gross Credit" as decimal(20, 8)) as gross_credit,
    try_cast("Commission" as decimal(20, 8)) as commission,
    try_cast("Markup" as decimal(20, 8)) as markup,
    "Net Currency" as net_currency,
    try_cast("Net Debit" as decimal(20, 8)) as net_debit,
    try_cast("Net Credit" as decimal(20, 8)) as net_credit,
    "Batch Number" as batch_number,
    source_file
from deduplicated
