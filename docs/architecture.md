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
| `marts` | Produce reconciliation detail, provider-by-cause summaries, fee variances, source adjustments and unexplained exceptions. |

## Shared Interfaces

- `int_provider_events`: one resolved provider event, identified by `(psp, provider_event_id)`. Provider models share a column contract and combine through `UNION ALL`.
- `int_provider_fees`: reported fee components linked to events by `(psp, provider_event_id)`. Aggregate components before joining to principal totals to avoid multiplying payment amounts.
- Engine events remain separate and use `txn_id`; matching connects the two sides.

Fields, types, nullability and identity rules: [provider_contract.md](provider_contract.md).

## Core Rules

- Keep all raw records; deduplication takes place in staging.
- Establish identity before comparing amounts or statuses. Accept only unambiguous one-to-one matches; do not force a match to eliminate a residual.
- Use UTC and fixed-precision decimals. Keep reported amounts separate from independent FX calculations; apply rounding only under an explicit rule. Match across the full extract before deriving June scope.
- Report principal discrepancies, source-copy corrections and fee variances separately. A duplicated export record is not proof of duplicated money.
- Check row accounting, keys, FX coverage, join cardinality and summary-to-detail totals. Expected source anomalies are findings; unexplained data loss or broken financial controls block final outputs.

## Project and Execution

Models live in `dbt/models/{raw,staging,intermediate,marts}` and use `ref()` for dependencies. Each SQL model declares its schema and materialization in `config()`. The custom schema macro preserves exact layer names for a single-user database; a shared warehouse would need environment namespaces. Descriptions and generic tests live in `dbt/models/schema.yml`; SQL tests live in `dbt/tests/`.

Run from the repository root, where relative input paths resolve:

```bash
dbt build --project-dir dbt --profiles-dir dbt
```

Use full rebuilds, not incremental appends. A multi-model run is not one transaction. Disconnect DataGrip before dbt writes to the same database file. Local database/profile files and generated artifacts stay outside Git.

The final Python wrapper will build and test the project before exporting deterministic reports; detailed run evidence and reproducibility instructions are part of the final handoff.
