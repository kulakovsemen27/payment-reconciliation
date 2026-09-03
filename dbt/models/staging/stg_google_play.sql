{{ 
  config(
    materialized='table', 
    schema='staging'
    ) 
}}

-- No event ID: identical descriptive rows are not proven duplicates.
with parsed_dates as (
    select
        *,
        try_strptime(
            "Transaction Date" || ' ' || "Transaction Time", '%b %d, %Y %H:%M:%S'
        ) as local_timestamp
    from {{ ref('google_play_earnings') }}
)

select
    "Transaction Date" as date_raw,
    "Transaction Time" as time_raw,
    -- Both source report headers explicitly specify this timezone.
    local_timestamp at time zone 'America/Los_Angeles' as event_timestamp_utc,
    "Transaction Type" as transaction_type,
    "Product ID" as product_id,
    "Buyer Country" as buyer_country,
    "Buyer Currency" as buyer_currency,
    try_cast("Amount (Buyer Currency)" as decimal(20, 8)) as buyer_amount,
    try_cast("Currency Conversion Rate" as decimal(18, 10)) as currency_conversion_rate,
    "Merchant Currency" as merchant_currency,
    try_cast("Amount (Merchant Currency)" as decimal(20, 8)) as merchant_amount,
    source_file
from parsed_dates
