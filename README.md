# Payment Reconciliation Pipeline

A dbt pipeline that reconciles payment-engine records with PayPal, Adyen, dLocal and Google Play reports for June 2026.

## What It Produces

- principal differences by provider and cause;
- reported versus contracted fees where a fee schedule is available;
- a short summary of findings, assumptions and recommended actions.

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

The command validates the input files, runs all dbt models and tests, and writes:

- `outputs/reconciliation_summary.csv`
- `outputs/reconciliation_details.csv`
- `outputs/fee_reconciliation_summary.csv`
- `outputs/fee_reconciliation_details.csv`

Written findings are in `outputs/analysis_note.md`.

Disconnect other DuckDB clients before running the pipeline.
