"""
src/load_raw.py
---------------
Loads the Nashville housing CSV into the nashville_housing_raw MySQL table.

This script is the single source of truth for the raw data load. It is run
once to populate the warehouse. If the raw table needs to be rebuilt, run
this script again — it will drop and replace the existing table.

Why Python instead of LOAD DATA INFILE:
- The source CSV contains two pandas index columns (unnamed) that must be
  dropped before loading. SQL has no mechanism to skip arbitrary columns
  during a load without knowing their position in advance.
- Column names in the CSV contain spaces and special characters that must
  be normalised to snake_case. This is a transformation step that belongs
  in a script.

Credentials are loaded from .env in the project root using python-dotenv
with interpolate=False. This is required because the password contains
special characters ($ and @) that dotenv would otherwise interpret as
variable expansion syntax.

Usage:
    conda activate nashville-analytics
    cd '<project root>'
    python src/load_raw.py
"""

import os
import pandas as pd
import sqlalchemy
from dotenv import load_dotenv

# Load credentials — interpolate=False prevents $ from being treated as a
# variable expansion character, which would corrupt passwords containing $.
load_dotenv(".env", override=True, interpolate=False)

engine = sqlalchemy.create_engine(
    "mysql+pymysql://",
    connect_args={
        "host":   os.getenv("DB_HOST"),
        "port":   int(os.getenv("DB_PORT")),
        "user":   os.getenv("DB_USER"),
        "passwd": os.getenv("DB_PASSWORD"),
        "db":     os.getenv("DB_NAME"),
    },
)

RAW_CSV = os.path.join("data", "raw", "Nashville_housing_data_2013_2016.csv")

df = pd.read_csv(RAW_CSV, dtype=str, index_col=False)

# Drop the two pandas-generated index columns present in this CSV export.
# These contain sequential integers and carry no analytical value.
df = df.drop(columns=["Unnamed: 0.1", "Unnamed: 0"])

# Normalise column names to snake_case: lowercase, strip whitespace,
# replace any non-alphanumeric character sequences with underscores.
df.columns = (
    df.columns
    .str.strip()
    .str.lower()
    .str.replace(r"[^a-z0-9]+", "_", regex=True)
    .str.strip("_")
)

print(f"Columns ({len(df.columns)}): {list(df.columns)}")
print(f"Rows: {len(df):,}")

df.to_sql("nashville_housing_raw", engine, if_exists="replace", index=False)
print("Load complete. Table: nashville_housing_raw")
