-- Nashville Property Analytics
-- File: sql/01_schema.sql
-- Purpose: Create the raw ingestion table for Nashville housing data.
--
-- Design decision: all columns defined as TEXT.
-- The raw table receives data exactly as it exists in the source CSV,
-- including dirty values, blanks, and formatting inconsistencies.
-- Type casting and cleaning happen in Notebook 01 after the audit,
-- not at load time. Attempting to cast at load time would cause failures
-- on blank or malformed values.
--
-- The table is populated by src/load_raw.py, not by LOAD DATA INFILE.
-- Python is used for the load because the source CSV contains two pandas
-- index columns that must be dropped, and column names require normalisation
-- to snake_case before loading. These are transformation steps that belong
-- in a script, not in a raw SQL load statement.

CREATE DATABASE IF NOT EXISTS nashville_analytics
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE nashville_analytics;

CREATE TABLE IF NOT EXISTS nashville_housing_raw (
    parcel_id                        TEXT COLLATE utf8mb4_unicode_ci,
    land_use                         TEXT COLLATE utf8mb4_unicode_ci,
    property_address                 TEXT COLLATE utf8mb4_unicode_ci,
    suite_condo                      TEXT COLLATE utf8mb4_unicode_ci,
    property_city                    TEXT COLLATE utf8mb4_unicode_ci,
    sale_date                        TEXT COLLATE utf8mb4_unicode_ci,
    sale_price                       TEXT COLLATE utf8mb4_unicode_ci,
    legal_reference                  TEXT COLLATE utf8mb4_unicode_ci,
    sold_as_vacant                   TEXT COLLATE utf8mb4_unicode_ci,
    multiple_parcels_involved_in_sale TEXT COLLATE utf8mb4_unicode_ci,
    owner_name                       TEXT COLLATE utf8mb4_unicode_ci,
    address                          TEXT COLLATE utf8mb4_unicode_ci,
    city                             TEXT COLLATE utf8mb4_unicode_ci,
    state                            TEXT COLLATE utf8mb4_unicode_ci,
    acreage                          TEXT COLLATE utf8mb4_unicode_ci,
    tax_district                     TEXT COLLATE utf8mb4_unicode_ci,
    neighborhood                     TEXT COLLATE utf8mb4_unicode_ci,
    image                            TEXT COLLATE utf8mb4_unicode_ci,
    land_value                       TEXT COLLATE utf8mb4_unicode_ci,
    building_value                   TEXT COLLATE utf8mb4_unicode_ci,
    total_value                      TEXT COLLATE utf8mb4_unicode_ci,
    finished_area                    TEXT COLLATE utf8mb4_unicode_ci,
    foundation_type                  TEXT COLLATE utf8mb4_unicode_ci,
    year_built                       TEXT COLLATE utf8mb4_unicode_ci,
    exterior_wall                    TEXT COLLATE utf8mb4_unicode_ci,
    grade                            TEXT COLLATE utf8mb4_unicode_ci,
    bedrooms                         TEXT COLLATE utf8mb4_unicode_ci,
    full_bath                        TEXT COLLATE utf8mb4_unicode_ci,
    half_bath                        TEXT COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
