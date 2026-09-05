# Provider Event and Fee Contract

Target interfaces, implemented and tested provider by provider. Names follow the payment engine; provider values remain independent evidence.

## Events — `int_provider_events`

One resolved operation or lifecycle event after confirmed-copy removal. Provider models return these columns in order and combine through `UNION ALL`.

| Column | Type | Nullable | Meaning |
|---|---|---|---|
| `provider_event_id` | `VARCHAR` | No | Stable event ID within `psp`, without a provider prefix |
| `psp` | `VARCHAR` | No | `paypal_us`, `paypal_eu`, `adyen`, `dlocal`, `google_play` |
| `provider_account` | `VARCHAR` | Yes | Source account, or a documented file-to-account mapping |
| `source_file` | `VARCHAR` | No | Repository-relative input filename |
| `psp_reference` | `VARCHAR` | Yes | Original operation reference; not necessarily unique across events |
| `parent_psp_reference` | `VARCHAR` | Yes | Known original-payment reference |
| `order_id` | `VARCHAR` | Yes | Verified equivalent of engine order ID |
| `operation_type` | `VARCHAR` | No | `SALE`, `REFUND`, `CHARGEBACK`, `REVERSAL`, `OTHER` |
| `source_status` | `VARCHAR` | Yes | Original status or lifecycle label |
| `status` | `VARCHAR` | No | `settled`, `pending`, `declined`, `authorized`, `disputed`, `unknown` |
| `event_timestamp_utc` | `TIMESTAMPTZ` | Yes | This event's timestamp in UTC |
| `country` | `VARCHAR` | Yes | Buyer country, not account country |
| `sku` | `VARCHAR` | Yes | Product identifier comparable to engine SKU |
| `currency` | `VARCHAR` | Yes | Principal currency |
| `amount_local_signed` | `DECIMAL(20,8)` | Yes | Signed principal in major units, before fees |
| `amount_usd_reported` | `DECIMAL(20,8)` | Yes | Signed USD principal reported by the provider |
| `fx_rate_reported` | `DECIMAL(18,10)` | Yes | Reported rate, normalized to USD per principal-currency unit |
| `is_financial_event` | `BOOLEAN` | Yes | Contributes to principal totals; `NULL` means unresolved |
| `fx_rate_selected` | `DECIMAL(18,10)` | Yes | Latest revision for the most recent rate date not after the event; 1 for USD |
| `fx_date_selected` | `DATE` | Yes | Reference-rate date; NULL for USD events |
| `amount_usd_normalized` | `DECIMAL(38,18)` | Yes | Reported USD amount or high-precision conversion using the selected rate |

### Values and Identity

- Sales are positive; refunds/chargebacks negative; reversals follow the reversed operation's direction. Non-financial attempts may retain amounts but do not contribute to financial totals. Diagnose unknown states; never force them into settled/declined.
- Missing values are `NULL`, not invented IDs, zero amounts or non-USD rates of one. Missing data needed to value/scope a financial event blocks a complete result.
- USD-denominated principal can populate `amount_usd_reported` directly. Otherwise use only the supplied USD equivalent, never net-after-fee amounts. When USD is absent, shared FX processing uses the latest revision for the most recent rate date not after the UTC event date and retains the high-precision calculation. Reconciliation rounds calculated USD to cents at event grain; staging remains unrounded.
- The event key is `(psp, provider_event_id)`; uniqueness checks and event joins use both fields. Use the source event ID when unique within `psp`; otherwise derive it from a verified natural key, including account context if needed. Exclude filenames and row positions. Distinct refunds/transitions remain distinct.
- Keep all raw copies; remove confirmed same-event, equal-payload copies in provider staging before casting. Control raw-to-staging row counts and report duplicates as DQ findings without assigning financial impact. Across files, removal still requires verified identity and idempotent ingestion. PayPal US currently removes exact copies within its single export. No `source_row_id`.
- Conflicting payloads or ambiguous identities remain in exception outputs and source controls, not arbitrary first/latest selections. Google Play's identical descriptive values alone do not prove duplication. Cross-system amount/status differences do not invalidate a reliable identity link.
- Preserve original timestamps in raw/staging; derive June scope after buffered matching. Engine stays separate, using `txn_id` without provider IDs or file metadata in raw/staging.

Provider-specific match models return accepted `(psp, engine_txn_id, provider_event_id, match_method)` pairs. PayPal and dLocal use PSP references. Adyen sales use PSP references; refunds and chargebacks use order plus operation type. Matching ambiguity fails validation instead of being resolved arbitrarily.

## Fees — `int_provider_fees`

One reported fee component associated with an event through `(psp, provider_event_id)`; no principal amounts here. PayPal US retains one total-fee record per staged operation, including zero fees.

| Column | Type | Nullable | Meaning |
|---|---|---|---|
| `provider_event_id` | `VARCHAR` | Yes | Event ID, joined together with `psp`; `NULL` if unresolved |
| `psp` | `VARCHAR` | No | Provider, including for unlinked fees |
| `provider_account` | `VARCHAR` | Yes | Account for contract selection |
| `fee_type` | `VARCHAR` | No | Component, e.g. `commission`, `markup`, `total` |
| `currency` | `VARCHAR` | Yes | Fee currency; may differ from principal |
| `fee_amount` | `DECIMAL(20,8)` | Yes | Positive cost, negative fee return |
| `source_file` | `VARCHAR` | No | Relative source filename |

- Sources: PayPal `Fee`; Adyen `Commission`/`Markup`; Google Play fee rows linked to charges; dLocal `fee_usd` in USD.
- Never add a total alongside its components or interpret a missing fee as zero. Equal amounts alone are not duplicates; multiple legitimate entries require explicit aggregation or retained detail, not an assumed unique event/component key.
- Preserve unlinked fees with source evidence; missing currency/amount is an exception. Aggregate components by event in a comparable currency before joining principal; never multiply payments or sum mixed currencies.
- Calculate expected fees and variance downstream using the account/date contract, relevant components and rounding rules.

## Required Controls

Test `(psp, provider_event_id)` uniqueness, field/state/sign validity, raw-to-staging row accounting, fee-link integrity, join cardinality and repeatability. Source rows, canonical events and fee components have different grains; their counts are not interchangeable.
