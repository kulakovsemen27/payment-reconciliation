# Payment Reconciliation Pipeline

Reconciles payment-engine records against PayPal, Adyen, dLocal and Google Play exports, explains differences in USD and checks contracted fees.

**Final report is here: [June 2026 findings and actions](outputs/findings.md).**

| Reports | Summary | Discrepancy details |
|---|---|---|
| Payments before fees | [Provider × cause](outputs/reconciliation_summary.csv) | [Transactions](outputs/reconciliation_details.csv) |
| Fees | [Contract comparison](outputs/fee_reconciliation_summary.csv) | [Transactions](outputs/fee_reconciliation_details.csv) |

## How the pipeline works

```text
CSV snapshots
      |
[RAW] load source values as text
      |
[STAGING] parse types, amounts and UTC timestamps
          remove confirmed exact copies
      |
[INTERMEDIATE] map source rows to common engine, event and fee contracts
      |
      +-- provider events --> apply reported/reference FX --> one-to-one matching
      |                                                        |
      |                                                        v
      |   [MARTS / payments] keep all events --> apply month --> measure and classify
      |                                                        |
      |                                                        v
      |                                      provider × cause summary and details
      |
      +-- provider fees + normalized events --> [MARTS / fees] apply effective tariff
                                                               |
                                                               v
                                                fee summary and transaction details
```

Match full extracts before applying the month boundary, preserving late settlements and unmatched events. Amounts are comparison fields, not matching keys. Signed payment impact is **provider − engine**; fees are separate.

| Provider | Matching rule |
|---|---|
| PayPal US / EU, dLocal | PSP reference |
| Adyen | PSP reference for sales; order + operation for refunds and chargebacks |
| Google Play | UTC completion timestamp + operation + product + country + currency; one-to-one candidates only |

Tests check identity, matching cardinality, required data and source-to-report totals. Invalid inputs block report export.

## Where to look

- **Payment calculation:** [mart_reconciliation_detail.sql](dbt/models/marts/payments/mart_reconciliation_detail.sql) — unmatched events, period scope, USD impact and cause.
- **Fee calculation:** [mart_fee_reconciliation_detail.sql](dbt/models/marts/fees/mart_fee_reconciliation_detail.sql) — reported fees versus the effective contract.
- **Provider rules:** [intermediate/providers/](dbt/models/intermediate/providers) — `events`, `matches` and `fees` per provider. Shared models sit directly in `intermediate/`.

## Repository layout

```text
raw/                         input snapshots
outputs/                     generated summaries, details and findings
dbt/
├── models/
│   ├── raw/                 source loading
│   ├── staging/             source parsing and deduplication
│   ├── intermediate/        common contracts, FX and unions
│   │   └── providers/       provider-specific events, fees and matches
│   └── marts/
│       ├── payments/        payment reconciliation
│       └── fees/            fee reconciliation
├── tests/                   data quality checks
└── models/schema.yml        model grains, fields and standard tests
run_pipeline.py              build, test and CSV export
```

## Stack

Python 3.13 · DuckDB · dbt

## Run

Clone the repository and run the pipeline from its root directory:

```bash
git clone https://github.com/kulakovsemen27/payment-reconciliation.git
cd payment-reconciliation

python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt

python run_pipeline.py --report-month 2026-06-01
```

A successful run:

- builds all DuckDB/dbt models and runs the data-quality tests;
- creates `reconciliation.duckdb` (you can access it with any IDE);
- refreshes the four CSV reports in `outputs/`.
