# Architecture

A local SQL-first pipeline. The payment engine is the internal baseline; provider reports remain independent evidence.

```text
CSV snapshots → raw → staging → intermediate → marts → CSV reports
```

| Layer | Responsibility |
|---|---|
| `raw` | Load source files as text without any transformations. |
| `staging` | Parse source-specific types, units and timestamps; remove duplicated rows. |
| `intermediate` | Normalize events and fees across all providers, apply FX rates and match provider events to the engine. |
| `marts` | Calculate, classify and aggregate principal and fee differences. |

## Shared Models

- `int_payment_engine_events`: normalized internal events.
- `int_provider_events`: common provider-event contract.
- `int_provider_matches`: accepted provider-specific matches.
- `int_provider_fees`: provider fee components.
- `mart_reconciliation_*`: principal reconciliation detail and summary.
- `mart_fee_reconciliation_*`: contracted-fee detail and summary.

Provider fields and matching rules are documented in [provider_contract.md](provider_contract.md).

## Core Rules

- Establish event identity before comparing amounts or statuses; accept only one-to-one matches.
- Match across the full extracts, then apply the June UTC reporting scope.
- Use fixed-precision decimals and round calculated USD only at event recognition.
- Treat exact source copies as ingestion data quality, not additional financial events.
- Define signed impact as `provider USD - engine USD`; report fees separately from principal.
- Pass `report_month` explicitly for every run.

## Execution

`run_pipeline.py` validates required files, creates a temporary dbt profile, runs `dbt build` and exports deterministic CSV reports. Financial logic remains in dbt models.
