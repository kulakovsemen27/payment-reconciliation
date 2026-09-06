# Payment Reconciliation Pipeline

A dbt pipeline that reconciles payment-engine records with PayPal, Adyen, dLocal and Google Play reports for June 2026.

## Review Guide

- [Findings and recommended actions](outputs/analysis_note.md)
- Principal: [summary](outputs/reconciliation_summary.csv) and [transaction details](outputs/reconciliation_details.csv)
- Fees: [summary](outputs/fee_reconciliation_summary.csv) and [transaction details](outputs/fee_reconciliation_details.csv)
- Core SQL: [principal reconciliation](dbt/models/marts/principal/mart_reconciliation_detail.sql) and [fee reconciliation](dbt/models/marts/fees/mart_fee_reconciliation_detail.sql)
- [Architecture](docs/architecture.md) and [provider rules](docs/provider_contract.md)

## Stack

- DuckDB
- dbt
- Python 3.13

## Run

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python run_pipeline.py --report-month 2026-06-01
```

The command validates inputs, builds and tests all dbt models, and refreshes the files in `outputs/`.

Disconnect other DuckDB clients before running the pipeline.
