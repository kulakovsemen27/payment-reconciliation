# Payment Reconciliation Pipeline

A SQL-first analytics project for reconciling payment backend records with payment-provider exports.

## Scope

- Transaction-level reconciliation across PayPal, Adyen, dLocal, and Google Play.
- Analysis of differences in amounts, statuses, reporting periods, and foreign exchange rates.
- Validation of reported fees against contracted rates.
- Provider-level summaries of discrepancy counts and USD impact.
- Data-quality checks and traceability from summary figures to source records.

## Technology

- **DuckDB** — local analytical database.
- **dbt** — SQL transformations, dependency management, and data tests.
- **Python** — pipeline execution and CSV export.
