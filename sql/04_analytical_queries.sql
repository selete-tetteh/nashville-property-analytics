-- Nashville Property Analytics
-- Analytical Queries: Notebook 04 — Census Demographic Enrichment
--
-- This file documents the database query used to support Notebook 04.
-- All demographic enrichment, geocoding, and analysis is performed in Python.
-- SQL is used only for the initial property record extraction.

-- ------------------------------------------------------------
-- Query 1: Property record extraction for Census enrichment
-- ------------------------------------------------------------
-- Loads the columns needed for geocoding and demographic analysis.
-- Rows with null property_address or property_city are excluded
-- because the Census Geocoder requires both fields to attempt a match.
-- Assessment value columns (land_value, building_value, etc.) are
-- excluded — they are not needed for this notebook and add no value
-- to the geocoding or demographic join steps.

SELECT
    parcel_id,
    property_address,
    property_city,
    sale_date,
    sale_price,
    land_use,
    tax_district,
    sold_as_vacant,
    price_outlier_flag,
    YEAR(sale_date) AS sale_year
FROM nashville_housing_clean
WHERE property_address IS NOT NULL
  AND property_city IS NOT NULL;

-- Expected row count: ~56,309
-- (Records excluded: those with null address or city fields)

-- ------------------------------------------------------------
-- Note on derived data
-- ------------------------------------------------------------
-- The following outputs are produced in Python and saved to
-- data/processed/. They are not loaded back into MySQL because
-- they are analytical outputs derived from external data sources,
-- not source data.
--
--   geocoded_addresses.csv     — parcel_id, lat/lon, Census tract FIPS
--   census_tract_demographics.csv — ACS 2016 tract-level demographics
--   nashville_enriched.csv     — joined dataset used for all analysis
