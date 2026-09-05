# Architecture

A local, SQL-first pipeline that reconciles payment-engine records with provider exports. The engine supplies the internal baseline, not an assumption that its values are always correct.

## Stack and Flow

- **DuckDB:** persistent local database; no server required.
- **dbt:** ingestion, SQL transformations, dependencies and tests.
- **Python (planned):** one entry point for input validation, dbt execution and CSV export. No financial rules outside SQL; no scheduler required.

```text
CSV snapshots → raw → staging → intermediate → marts → CSV reports
```

| Layer | Responsibility |
|---|---|
| `raw` | Load immutable CSV snapshots as text. Preserve rows and non-empty values; empty fields become `NULL`. |
| `staging` | Deduplicate and parse types, dates and units without cross-source joins. Engine keeps its original 15 columns; providers retain filenames and original timestamp text. |
| `intermediate` | Normalize events, resolve lifecycle/version semantics, select FX, match engine/provider events and calculate expected fees. |
| `marts` | Produce reconciliation detail, provider-by-cause summaries, fee variances and unexplained exceptions. |

## Shared Interfaces

- `int_payment_engine_events`: shared signed engine events with financial relevance and reporting timestamps.
- `int_provider_events`: one resolved provider event, identified by `(psp, provider_event_id)`. Provider adapters share a column contract and combine through `UNION ALL`.
- `int_provider_matches`: accepted engine/provider event pairs from provider-specific matching models; each pair records its match method.
- `int_provider_fees`: reported fee components linked to events by `(psp, provider_event_id)`. Aggregate components before joining to principal totals to avoid multiplying payment amounts.
- `mart_reconciliation_detail` applies matching, month scope and cause classification once for every implemented provider; `mart_reconciliation_summary` aggregates all rows, including matched coverage and both sides' USD totals.

Fields, types, nullability and identity rules: [provider_contract.md](provider_contract.md).

## Core Rules

- Keep all raw records; deduplication takes place in staging.
- Establish identity before comparing amounts or statuses. Accept only unambiguous one-to-one matches; do not force a match to eliminate a residual.
- Use UTC and fixed-precision decimals. Keep reported amounts separate from independent FX calculations. Use the latest revision for the most recent rate date not after the event, and round calculated USD to cents only at event-level recognition. Match across the full extract before deriving June scope.
- Treat exact source copies as ingestion DQ, not financial discrepancies. Control raw-to-staging row counts and mention relevant findings in the memo; keep them out of CFO monetary totals.
- `report_month` is the required first day of the reporting month, supplied for each run. Engine events use UTC completion time for financial recognition; pending/declined attempts contribute zero and use creation time for audit scope. Keep a matched pair if either side belongs to the month.
- Cause precedence is shared: invalid financial inputs → missing counterpart → incompatible operation/currency → status → month cutoff → FX → amount → matched. Summary percentages use absolute principal impact across providers for the month; fees remain separate.
- Check row accounting, keys, FX coverage, join cardinality and summary-to-detail totals. Expected source anomalies are findings; unexplained data loss or broken financial controls block final outputs.

## Project and Execution

Models live in `dbt/models/{raw,staging,intermediate,marts}` and use `ref()` for dependencies. Each SQL model declares its schema and materialization in `config()`. The custom schema macro preserves exact layer names for a single-user database; a shared warehouse would need environment namespaces. Descriptions and generic tests live in `dbt/models/schema.yml`; SQL tests live in `dbt/tests/`.

Run from the repository root, where relative input paths resolve:

```bash
dbt build --project-dir dbt --profiles-dir dbt \
  --vars '{"report_month": "2026-06-01"}'
```

Use full rebuilds, not incremental appends. A multi-model run is not one transaction. Disconnect DataGrip before dbt writes to the same database file. Local database/profile files and generated artifacts stay outside Git.

`report_month` has no project default, so omitting it fails during compilation instead of silently rebuilding the wrong period. The final Python wrapper will pass it explicitly, build and test the project, and then export deterministic reports; detailed run evidence and reproducibility instructions are part of the final handoff.
