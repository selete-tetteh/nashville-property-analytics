-- sql/05_dashboard_extract.sql
-- Nashville Property Analytics — Power BI Dashboard (Phase 2)
-- Extract for the Overview and Market Trends pages.
--
-- Purpose:
-- Pulls the full clean table (all 56,468 rows), not the geocoded subset used
-- in nashville_enriched.csv. Notebook 02's CPI-adjusted price trends and
-- vacancy discount finding were computed on the full clean table, before any
-- geocoding took place. Using the geocoded subset here would silently narrow
-- the scope to 73.4% of records and the dashboard would no longer match what
-- Notebook 02 actually reported.
--
-- CPI adjustment is NOT done here. Following the project's established
-- pattern (CPI-U pulled from the BLS API and applied in Python/R, never
-- written back to MySQL), sale_price_real is computed in Python after this
-- extract, using the same annual-average-from-monthly-readings method as
-- Notebooks 02 and 03.
--
-- Output feeds: reports/powerbi/overview_trends.csv

SELECT
    parcel_id,
    sale_date,
    YEAR(sale_date)     AS sale_year,
    sale_price,
    land_use,
    tax_district,
    sold_as_vacant,
    price_outlier_flag

FROM nashville_housing_clean;


-- ── Row count verification ────────────────────────────────────────────────
-- Expected result: 56,468 rows. This is the full clean table — no filtering
-- applied here. price_outlier_flag is retained so Power BI can filter or
-- flag outliers visually rather than having them silently excluded.

SELECT COUNT(*) AS row_count FROM nashville_housing_clean;
