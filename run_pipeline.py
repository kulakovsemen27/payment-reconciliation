#!/usr/bin/env python3
"""Build the reconciliation project and export its final reports."""

from __future__ import annotations

import argparse
import csv
import json
import shutil
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path

import duckdb


PROJECT_ROOT = Path(__file__).resolve().parent
DBT_PROJECT_DIR = PROJECT_ROOT / "dbt"
REQUIRED_INPUT_FILES = (
    "adyen_payment_accounting_20260601_20260703.csv",
    "dlocal_transactions_20260601_20260703.csv",
    "fee_schedule.csv",
    "fx_rates.csv",
    "google_play_earnings_202606.csv",
    "google_play_earnings_202607_partial.csv",
    "payment_engine_log.csv",
    "paypal_eu_activity_20260601_20260703.csv",
    "paypal_us_activity_20260601_20260703.csv",
)
PRINCIPAL_QUERY = """
    select
        report_month,
        psp,
        cause,
        engine_record_count,
        provider_record_count,
        record_count_difference,
        cast(engine_amount_usd as decimal(20, 2)) as engine_amount_usd,
        cast(provider_amount_usd as decimal(20, 2)) as provider_amount_usd,
        cast(signed_usd_impact as decimal(20, 2)) as signed_usd_impact,
        cast(absolute_usd_impact as decimal(20, 2)) as absolute_usd_impact,
        absolute_impact_share_pct
    from marts.mart_reconciliation_summary
    order by report_month, psp, cause
"""
FEE_QUERY = """
    select
        report_month,
        psp,
        provider_account,
        fee_currency,
        cause,
        event_count,
        cast(reported_fee_local as decimal(20, 2)) as reported_fee_local,
        cast(expected_fee_local as decimal(20, 2)) as expected_fee_local,
        cast(signed_fee_variance_local as decimal(20, 2)) as signed_fee_variance_local,
        cast(reported_fee_usd as decimal(20, 2)) as reported_fee_usd,
        cast(expected_fee_usd as decimal(20, 2)) as expected_fee_usd,
        cast(signed_fee_variance_usd as decimal(20, 2)) as signed_fee_variance_usd,
        cast(absolute_fee_variance_usd as decimal(20, 2)) as absolute_fee_variance_usd
    from marts.mart_fee_reconciliation_summary
    order by report_month, psp, provider_account, fee_currency, cause
"""
PRINCIPAL_EXCEPTIONS_QUERY = """
    select
        report_month,
        psp,
        engine_txn_id,
        provider_event_id,
        match_status,
        cause,
        engine_operation_type,
        provider_operation_type,
        engine_status,
        provider_status,
        strftime(
            engine_event_timestamp_utc at time zone 'UTC',
            '%Y-%m-%dT%H:%M:%SZ'
        ) as engine_event_timestamp_utc,
        strftime(
            provider_event_timestamp_utc at time zone 'UTC',
            '%Y-%m-%dT%H:%M:%SZ'
        ) as provider_event_timestamp_utc,
        engine_currency,
        provider_currency,
        engine_amount_local_signed as engine_amount_local,
        provider_amount_local_signed as provider_amount_local,
        cast(engine_amount_usd_signed as decimal(20, 2)) as engine_amount_usd,
        cast(provider_amount_usd_normalized as decimal(20, 2)) as provider_amount_usd,
        cast(signed_usd_impact as decimal(20, 2)) as signed_usd_impact
    from marts.mart_reconciliation_detail
    where cause <> 'matched'
    order by report_month, psp, cause, engine_txn_id, provider_event_id
"""
FEE_EXCEPTIONS_QUERY = """
    select
        report_month,
        psp,
        provider_event_id,
        provider_account,
        strftime(
            event_timestamp_utc at time zone 'UTC',
            '%Y-%m-%dT%H:%M:%SZ'
        ) as event_timestamp_utc,
        fee_currency,
        contract_valid_from,
        cast(percent_fee as decimal(12, 4)) as percent_fee,
        cast(fixed_fee as decimal(20, 2)) as fixed_fee,
        fixed_fee_currency,
        cast(reported_fee_local as decimal(20, 2)) as reported_fee_local,
        cast(expected_fee_local as decimal(20, 2)) as expected_fee_local,
        cast(signed_fee_variance_local as decimal(20, 2)) as signed_fee_variance_local,
        cast(signed_fee_variance_usd as decimal(20, 2)) as signed_fee_variance_usd
    from marts.mart_fee_reconciliation_detail
    where cause <> 'matched'
    order by report_month, psp, provider_account, provider_event_id
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-month", required=True, help="First day of month, e.g. 2026-06-01")
    parser.add_argument(
        "--database",
        type=Path,
        default=PROJECT_ROOT / "reconciliation.duckdb",
        help="DuckDB database path (default: reconciliation.duckdb)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=PROJECT_ROOT / "outputs",
        help="Directory for generated reports (default: outputs)",
    )
    return parser.parse_args()


def validate_report_month(value: str) -> date:
    try:
        report_month = date.fromisoformat(value)
    except ValueError as error:
        raise SystemExit("--report-month must use YYYY-MM-DD") from error
    if report_month.day != 1:
        raise SystemExit("--report-month must be the first day of its month")
    return report_month


def validate_inputs(raw_dir: Path) -> None:
    missing = [name for name in REQUIRED_INPUT_FILES if not (raw_dir / name).is_file()]
    if missing:
        raise SystemExit("Missing required input files:\n- " + "\n- ".join(missing))


def write_profile(directory: Path, database: Path) -> None:
    lines = [
        "payment_reconciliation:",
        "  target: dev",
        "  outputs:",
        "    dev:",
        "      type: duckdb",
        f"      path: {json.dumps(str(database.resolve()))}",
        "      schema: main",
        "      threads: 1",
        "      settings:",
        "        TimeZone: UTC",
        "",
    ]
    (directory / "profiles.yml").write_text("\n".join(lines), encoding="utf-8")


def run_dbt(report_month: date, database: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="payment-reconciliation-") as profile_dir:
        profile_path = Path(profile_dir)
        write_profile(profile_path, database)
        dbt_executable = Path(sys.executable).with_name("dbt")
        if not dbt_executable.is_file():
            resolved = shutil.which("dbt")
            if resolved is None:
                raise SystemExit("dbt executable not found; install requirements.txt first")
            dbt_executable = Path(resolved)
        command = [
            str(dbt_executable),
            "build",
            "--project-dir",
            str(DBT_PROJECT_DIR),
            "--profiles-dir",
            str(profile_path),
            "--vars",
            json.dumps({"report_month": report_month.isoformat()}),
        ]
        subprocess.run(command, cwd=PROJECT_ROOT, check=True)


def write_csv(connection: duckdb.DuckDBPyConnection, query: str, destination: Path) -> None:
    result = connection.execute(query)
    headers = [column[0] for column in result.description]
    temporary_path = destination.with_suffix(destination.suffix + ".tmp")
    with temporary_path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file, lineterminator="\n")
        writer.writerow(headers)
        writer.writerows(result.fetchall())
    temporary_path.replace(destination)


def export_reports(database: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    with duckdb.connect(str(database), read_only=True) as connection:
        write_csv(connection, PRINCIPAL_QUERY, output_dir / "reconciliation_summary.csv")
        write_csv(connection, FEE_QUERY, output_dir / "fee_reconciliation_summary.csv")
        write_csv(
            connection,
            PRINCIPAL_EXCEPTIONS_QUERY,
            output_dir / "reconciliation_details.csv",
        )
        write_csv(
            connection,
            FEE_EXCEPTIONS_QUERY,
            output_dir / "fee_reconciliation_details.csv",
        )


def main() -> None:
    args = parse_args()
    report_month = validate_report_month(args.report_month)
    database = args.database.resolve()
    output_dir = args.output_dir.resolve()
    validate_inputs(PROJECT_ROOT / "raw")
    database.parent.mkdir(parents=True, exist_ok=True)
    run_dbt(report_month, database)
    export_reports(database, output_dir)
    print(f"Reports written to {output_dir}")


if __name__ == "__main__":
    main()
