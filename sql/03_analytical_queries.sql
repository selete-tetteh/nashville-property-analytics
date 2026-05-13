-- sql/03_analytical_queries.sql
-- Nashville Property Analytics
-- Analytical scope definition for Notebook 03 — Modelling and Mis-valuation Detection
--
-- Purpose:
-- This file documents the exact dataset used for all modelling work in Notebook 03.
-- It defines which records qualify as "complete" for modelling purposes and why
-- each filter was applied. Running this query against nashville_housing_clean
-- reproduces the 23,157-row modelling dataset exactly.
--
-- Coverage: 23,157 rows — 41% of the 56,468-row clean table.
-- The remaining 59% were excluded due to structural nulls in assessment-side fields.
-- These nulls reflect properties for which the county assessor did not record
-- detailed characteristic data. They are not random missingness and were not imputed.


-- ── Complete-records selection ────────────────────────────────────────────────
--
-- This is the exact query used in Notebook 03 Section 1 to load the modelling dataset.
-- All model training, evaluation, and residual analysis was performed on this subset.

SELECT
    parcel_id,
    sale_price,
    YEAR(sale_date)     AS sale_year,
    land_use,
    tax_district,
    land_value,
    building_value,
    acreage,            -- Physical land size in acres
    finished_area,      -- Finished building area in square feet
    year_built,
    bedrooms,
    full_bath,
    half_bath,
    sold_as_vacant,
    price_outlier_flag

FROM nashville_housing_clean

WHERE
    -- Assessment-side fields: excluded where null because imputing these values
    -- would mean training the model on synthetic data rather than real property
    -- characteristics. The nulls are structural, not random.
    land_value              IS NOT NULL
    AND building_value      IS NOT NULL
    AND acreage             IS NOT NULL
    AND finished_area       IS NOT NULL
    AND year_built          IS NOT NULL
    AND bedrooms            IS NOT NULL
    AND full_bath           IS NOT NULL
    AND half_bath           IS NOT NULL

    -- Exclude zero-price transactions. These represent transfers, foreclosures,
    -- or administrative recordings that do not reflect arm's-length market sales.
    AND sale_price          > 0

    -- Exclude statistical outliers flagged in Notebook 01.
    -- STATISTICAL_OUTLIER records have sale prices beyond 3x IQR above Q3 (threshold: $912,000).
    -- ZERO_OR_NEAR_ZERO records have sale prices at or below $100.
    -- Both categories would distort model training and inflate error metrics.
    AND price_outlier_flag  = 'CLEAN';


-- ── Row count verification ────────────────────────────────────────────────────
--
-- Run this after the query above to confirm the modelling scope.
-- Expected result: 23,157 rows.

SELECT 
    COUNT(*) AS complete_records,
    ROUND(COUNT(*) / 56468 * 100, 1) AS pct_of_clean_table
FROM
    nashville_housing_clean
WHERE
    land_value IS NOT NULL
        AND building_value IS NOT NULL
        AND acreage IS NOT NULL
        AND finished_area IS NOT NULL
        AND year_built IS NOT NULL
        AND bedrooms IS NOT NULL
        AND full_bath IS NOT NULL
        AND half_bath IS NOT NULL
        AND sale_price > 0
        AND price_outlier_flag = 'CLEAN';


-- ── Null rate by assessment field ─────────────────────────────────────────────
--
-- Documents the structural null rate for each excluded field.
-- Included here so the 59% exclusion rate is auditable directly from SQL
-- without needing to open a notebook.

SELECT
    ROUND(SUM(CASE WHEN land_value     IS NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_null_land_value,
    ROUND(SUM(CASE WHEN building_value IS NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_null_building_value,
    ROUND(SUM(CASE WHEN acreage        IS NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_null_acreage,
    ROUND(SUM(CASE WHEN finished_area  IS NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_null_finished_area,
    ROUND(SUM(CASE WHEN year_built     IS NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_null_year_built,
    ROUND(SUM(CASE WHEN bedrooms       IS NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_null_bedrooms,
    ROUND(SUM(CASE WHEN full_bath      IS NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_null_full_bath,
    ROUND(SUM(CASE WHEN half_bath      IS NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_null_half_bath
FROM nashville_housing_clean;
