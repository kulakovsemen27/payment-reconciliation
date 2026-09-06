select psp, provider_event_id, currency, event_timestamp_utc,
    fx_date_selected, fx_rate_selected, amount_usd_normalized
from {{ ref('int_provider_events') }}
where is_financial_event
    and (
        amount_local_signed is null
        or amount_usd_normalized is null
        or (currency <> 'USD' and (fx_date_selected is null or fx_rate_selected is null))
        or fx_date_selected > (event_timestamp_utc at time zone 'UTC')::date
    )
