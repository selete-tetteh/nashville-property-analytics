"""
src/export_dashboard_data.py

Nashville Property Analytics — Power BI Dashboard (Phase 2)

Produces the three source files the Power BI dashboard imports directly.
A static export was chosen over a live MySQL connection because Power BI
runs inside a Parallels VM on this machine only — anyone reviewing this
project on GitHub has no way to stand up the database, so a live connection
would make the dashboard unreproducible outside this environment.

Why three files instead of one merged table:
Each dashboard page has a different natural grain, and forcing them into a
single table would either narrow every page to the smallest common subset
(the 4,632-row model test set) or require a fan-out join that duplicates
rows. Keeping them separate means each page reflects exactly the scope its
source notebook actually used:

    overview_trends.csv       — all 56,468 clean records (Notebooks 01-02)
    misvaluation.csv          — the 4,632-row model test set (Notebook 03)
    neighbourhood_equity.csv  — the 43,822 geocoded records (Notebook 04)

Run as a module from the project root:
    python -m src.export_dashboard_data
"""

import shutil
from pathlib import Path

import pandas as pd
import requests
from dotenv import load_dotenv
import os
from urllib.parse import quote_plus
from sqlalchemy import create_engine

# ── Path setup ────────────────────────────────────────────────────────────
# Walk up until environment.yml is found, so this works regardless of the
# working directory the module is run from.
PROJECT_ROOT = Path(__file__).resolve().parent
while not (PROJECT_ROOT / "environment.yml").exists():
    PROJECT_ROOT = PROJECT_ROOT.parent

OUTPUT_DIR = PROJECT_ROOT / "reports" / "powerbi"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

load_dotenv(PROJECT_ROOT / ".env")


def get_engine():
    """Return a SQLAlchemy engine with the password percent-encoded.

    quote_plus is required here because the database password contains
    '$' and '@', which SQLAlchemy's URL parser would otherwise misread.
    """
    password = quote_plus(os.environ["DB_PASSWORD"])
    user = os.environ["DB_USER"]
    host = os.environ["DB_HOST"]
    port = os.environ["DB_PORT"]
    name = os.environ["DB_NAME"]
    return create_engine(f"mysql+mysqlconnector://{user}:{password}@{host}:{port}/{name}")


def fetch_annual_cpi(start_year: int, end_year: int) -> dict:
    """Fetch CPI-U (series CUUR0000SA0) and return {year: annual_average}.

    The BLS unauthenticated endpoint does not return the M13 annual-average
    code directly, so the annual figure is computed as the mean of the 12
    monthly readings — this produces the same result as M13 and is the same
    approach used in Notebooks 02, 03, and 04.
    """
    api_key = os.environ.get("BLS_API_KEY")
    url = "https://api.bls.gov/publicAPI/v2/timeseries/data/"
    payload = {
        "startyear": str(start_year),
        "endyear": str(end_year),
        "seriesid": ["CUUR0000SA0"]
    }
    if api_key:
        payload["registrationkey"] = api_key

    response = requests.post(url, json=payload, timeout=30)
    response.raise_for_status()
    data = response.json()["Results"]["series"][0]["data"]

    monthly = {}
    for row in data:
        year = int(row["year"])
        if row["value"] != "-":
            monthly.setdefault(year, []).append(float(row["value"]))

    return {year: sum(values) / len(values) for year, values in monthly.items()}


def export_overview_trends(engine, cpi_by_year: dict) -> None:
    """Extract the full clean table and attach CPI-adjusted real prices.

    Scope: all 56,468 clean records, verified against sql/05_dashboard_extract.sql.
    Base year 2013, matching the base year used throughout Notebooks 02-04.
    """
    query = """
        SELECT
            parcel_id,
            sale_date,
            YEAR(sale_date)     AS sale_year,
            sale_price,
            land_use,
            tax_district,
            sold_as_vacant,
            price_outlier_flag
        FROM nashville_housing_clean
    """
    df = pd.read_sql(query, engine)

    base_year_cpi = cpi_by_year[2013]
    df["sale_price_real"] = df["sale_price"] * (base_year_cpi / df["sale_year"].map(cpi_by_year))

    assert len(df) == 56468, f"Expected 56,468 rows, got {len(df)} — check the SQL extract."

    output_path = OUTPUT_DIR / "overview_trends.csv"
    df.to_csv(output_path, index=False)
    print(f"Saved {len(df):,} rows to {output_path}")


def copy_existing_extract(source_name: str, dest_name: str, expected_rows: int) -> None:
    """Copy an already-verified processed CSV into the dashboard folder.

    These files (residuals_test_set.csv and nashville_enriched.csv) were
    produced and verified in Notebooks 03 and 04 respectively. Copying them
    here rather than pointing Power BI at data/processed/ directly keeps
    every file the dashboard depends on inside reports/powerbi/, so the
    folder is self-contained for anyone reviewing the repository.
    """
    source_path = PROJECT_ROOT / "data" / "processed" / source_name
    dest_path = OUTPUT_DIR / dest_name

    row_count = sum(1 for _ in open(source_path)) - 1  # subtract header
    assert row_count == expected_rows, (
        f"{source_name} has {row_count} rows, expected {expected_rows}. "
        "Do not copy a file whose row count doesn't match what its source "
        "notebook reported — re-verify before proceeding."
    )

    shutil.copy(source_path, dest_path)
    print(f"Copied {row_count:,} rows from {source_name} to {dest_path}")


def main():
    engine = get_engine()
    try:
        cpi_by_year = fetch_annual_cpi(2013, 2016)
        export_overview_trends(engine, cpi_by_year)
    finally:
        engine.dispose()

    copy_existing_extract("residuals_test_set.csv", "misvaluation.csv", expected_rows=4632)
    copy_existing_extract("nashville_enriched.csv", "neighbourhood_equity.csv", expected_rows=43821)

    print("\nAll three dashboard source files exported to reports/powerbi/")


if __name__ == "__main__":
    main()
