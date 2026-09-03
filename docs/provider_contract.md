# Provider Event and Fee Contract

Target interfaces, implemented and tested provider by provider. Names follow the payment engine; provider values remain independent evidence.

## Events — `int_provider_events`

One resolved operation or lifecycle event after confirmed-copy removal. Provider models return these columns in order and combine through `UNION ALL`.

| Column | Type | Nullable | Meaning |
|---|---|---|---|
| `provider_event_id` | `VARCHAR` | No | Stable event identity including provider/account context |
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

### Values and Identity

- Sales are positive; refunds/chargebacks negative; reversals follow the reversed operation's direction. Non-financial attempts may retain amounts but do not contribute to financial totals. Diagnose unknown states; never force them into settled/declined.
- Missing values are `NULL`, not invented IDs, zero amounts or non-USD rates of one. Missing data needed to value/scope a financial event blocks a complete result.
- USD-denominated principal can populate `amount_usd_reported` directly. Otherwise use only the supplied USD equivalent, never net-after-fee amounts or our FX calculation. Shared FX processing adds `fx_rate_selected` and `amount_usd_normalized` (`DECIMAL(38,18)`); no premature cent rounding.
- Derive `provider_event_id` from a verified, possibly composite natural key plus provider/account context. If hashing, serialize unambiguously. Exclude filenames, row positions and run-dependent values. Distinct refunds/transitions must remain distinct.
- Keep all raw copies; remove confirmed same-event, equal-payload copies in provider staging before casting. Retain key, copy counts and monetary corrections. Across files, removal still requires verified identity and a deterministic filename representative with per-file counts. PayPal US currently removes exact copies within its single export. No `source_row_id`.
- Conflicting payloads or ambiguous identities remain in exception outputs and source controls, not arbitrary first/latest selections. Google Play's identical descriptive values alone do not prove duplication. Cross-system amount/status differences do not invalidate a reliable identity link.
- Preserve original timestamps in raw/staging; derive June scope after buffered matching. Engine stays separate, using `txn_id` without provider IDs or file metadata in raw/staging.

## Fees — `int_provider_fees`

One reported fee component associated with an event; no principal amounts here.

| Column | Type | Nullable | Meaning |
|---|---|---|---|
| `provider_event_id` | `VARCHAR` | Yes | Event link; `NULL` if unresolved |
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

Test resolved event-ID uniqueness, field/state/sign validity, row and amount accounting, fee-link integrity, join cardinality and repeatability. Include exceptions and copy corrections in controls. Source rows, events and fee components have different grains; their counts are not interchangeable.
