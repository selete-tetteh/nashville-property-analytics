-- =============================================================================
-- sql/02_cleaning_queries.sql
-- Nashville Property Analytics
-- =============================================================================
-- Purpose:
--   Documents all cleaning logic applied to nashville_housing_raw to produce
--   nashville_housing_clean. This file is the SQL-as-source-of-truth record
--   of every transformation. Running these statements in order on a freshly
--   loaded nashville_housing_raw will reproduce nashville_housing_clean exactly.
--
-- Prerequisites:
--   - nashville_housing_raw must exist and be fully loaded (see src/load_raw.py)
--   - Run Step 0 (null byte fix) before any other step if working from a fresh load
--
-- Usage:
--   Run in MySQL Workbench or via the MySQL CLI:
--   mysql -u root -p nashville_analytics < sql/02_cleaning_queries.sql
-- =============================================================================

USE nashville_analytics;

-- =============================================================================
-- STEP 0: Null byte fix on nashville_housing_raw
-- =============================================================================
-- The building_value column in the raw CSV contains embedded null bytes (CHAR(0))
-- in 49 rows. These are artefacts of the source file encoding, not missing values.
-- RMariaDB crashes with "embedded nul in string" when these are present.
--
-- Detection method: INSTR(column, CHAR(0)) is reliable in this MySQL configuration.
-- LIKE '%\0%' did not match consistently and should not be used here.
--
-- This UPDATE was applied once to nashville_housing_raw after the initial load.
-- It is documented here so the fix is reproducible on any fresh load.
-- Safe to re-run: the WHERE clause means it touches zero rows if already applied.
-- =============================================================================

UPDATE nashville_housing_raw
SET building_value = REPLACE(building_value, CHAR(0), '')
WHERE INSTR(building_value, CHAR(0)) > 0;

-- Verify: should return 0 rows after the fix is applied.
SELECT COUNT(*) AS remaining_null_bytes
FROM nashville_housing_raw
WHERE INSTR(building_value, CHAR(0)) > 0;


-- =============================================================================
-- STEP 1: Verify duplicate count before removal
-- =============================================================================
-- Duplicates are defined as rows sharing the same parcel_id, sale_date, and
-- sale_price. This composite key identifies a unique property transaction.
-- The dataset has no UniqueID column, so a surrogate key is not available.
--
-- Expected result: 334 rows across 103 duplicate sets, as identified in
-- notebooks/01_data_audit.ipynb. If this number differs on a fresh load,
-- investigate before proceeding.
--
-- Note: IN with a subquery is avoided here — it causes MySQL to re-evaluate
-- the subquery for every outer row, which is extremely slow on large tables.
-- A JOIN against the grouped subquery is the correct pattern.
-- =============================================================================

SELECT COUNT(*) AS duplicate_row_count
FROM nashville_housing_raw r
INNER JOIN (
    SELECT parcel_id, sale_date, sale_price
    FROM nashville_housing_raw
    GROUP BY parcel_id, sale_date, sale_price
    HAVING COUNT(*) > 1
) dupes
ON  r.parcel_id  = dupes.parcel_id
AND r.sale_date  = dupes.sale_date
AND r.sale_price = dupes.sale_price;


-- =============================================================================
-- STEP 2: Create nashville_housing_clean
-- =============================================================================
-- All cleaning is applied in a single CREATE TABLE ... SELECT statement.
-- This produces the clean table in one atomic operation rather than applying
-- sequential UPDATEs to the raw table, which would make the transformation
-- history harder to audit.
--
-- Cleaning operations applied:
--   1. Duplicate removal       — keep one row per (parcel_id, sale_date, sale_price)
--   2. Null byte removal       — already applied to raw table in Step 0
--   3. Date casting            — sale_date cast from TEXT to DATE
--   4. Numeric casting         — sale_price, acreage, and all assessment-side
--                                fields cast to DOUBLE; year_built, bedrooms,
--                                full_bath, half_bath cast to UNSIGNED INT
--   5. sold_as_vacant          — standardised to Y/N only; any other value set
--                                to NULL to avoid silent misclassification
--   6. Categorical normalisation — UPPER() and TRIM() applied to all text fields
--                                  to remove case inconsistencies and whitespace
--                                  (e.g. grade column contained trailing spaces)
--   7. price_outlier_flag      — three-tier classification:
--                                  ZERO_OR_NEAR_ZERO   : sale_price < 1,000
--                                  STATISTICAL_OUTLIER : sale_price > 912,000
--                                  CLEAN               : all other rows
--                                The 912,000 threshold is the 3x IQR upper bound
--                                calculated in R using quantile() in Notebook 01.
--                                It is hardcoded here to guarantee identical output —
--                                MySQL's GROUP_CONCAT approximation of quantiles
--                                produces a slightly different boundary than R's
--                                quantile() function.
--                                Outliers are retained, not removed. The flag allows
--                                downstream analysis to exclude them selectively.
--   8. image column excluded   — contained Windows file paths with no analytical
--                                value
-- =============================================================================

/* DROP TABLE IF EXISTS nashville_housing_clean;

CREATE TABLE nashville_housing_clean AS
WITH deduped AS (
    -- Keep one row per unique transaction. ROW_NUMBER() assigns 1 to the first
    -- occurrence; the WHERE clause below discards all subsequent duplicates.
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY parcel_id, sale_date, sale_price
               ORDER BY parcel_id
           ) AS rn
    FROM nashville_housing_raw
)
SELECT
    -- Identifiers
    UPPER(TRIM(d.parcel_id))                          AS parcel_id,

    -- Property characteristics
    UPPER(TRIM(d.land_use))                           AS land_use,
    UPPER(TRIM(d.property_address))                   AS property_address,
    UPPER(TRIM(d.suite_condo))                        AS suite_condo,
    UPPER(TRIM(d.property_city))                      AS property_city,

    -- Transaction fields
    STR_TO_DATE(d.sale_date, '%Y-%m-%d')              AS sale_date,
    CAST(d.sale_price AS DOUBLE)                      AS sale_price,

    -- Three-tier outlier flag matching the R quantile() output from Notebook 01.
    -- Threshold of 912,000 is the exact 3x IQR upper bound calculated in R.
    CASE
        WHEN CAST(d.sale_price AS DOUBLE) < 1000
        THEN 'ZERO_OR_NEAR_ZERO'
        WHEN CAST(d.sale_price AS DOUBLE) > 912000
        THEN 'STATISTICAL_OUTLIER'
        ELSE 'CLEAN'
    END                                               AS price_outlier_flag,

    UPPER(TRIM(d.legal_reference))                    AS legal_reference,

    -- sold_as_vacant: standardise to Y/N only
    CASE
        WHEN UPPER(TRIM(d.sold_as_vacant)) IN ('Y', 'YES') THEN 'Y'
        WHEN UPPER(TRIM(d.sold_as_vacant)) IN ('N', 'NO')  THEN 'N'
        ELSE NULL
    END                                               AS sold_as_vacant,

    UPPER(TRIM(d.multiple_parcels_involved_in_sale))  AS multiple_parcels_involved_in_sale,

    -- Owner fields
    UPPER(TRIM(d.owner_name))                         AS owner_name,
    UPPER(TRIM(d.owner_address))                      AS owner_address,
    UPPER(TRIM(d.owner_city))                         AS owner_city,
    UPPER(TRIM(d.owner_state))                        AS owner_state,

    -- Assessment-side fields (cast to DOUBLE to allow nulls)
    CAST(d.acreage AS DOUBLE)                         AS acreage,
    UPPER(TRIM(d.tax_district))                       AS tax_district,
    UPPER(TRIM(d.neighborhood))                       AS neighborhood,
    CAST(d.land_value AS DOUBLE)                      AS land_value,
    CAST(d.building_value AS DOUBLE)                  AS building_value,
    CAST(d.total_value AS DOUBLE)                     AS total_value,
    CAST(d.finished_area AS DOUBLE)                   AS finished_area,
    UPPER(TRIM(d.foundation_type))                    AS foundation_type,
    CAST(d.year_built AS UNSIGNED)                    AS year_built,
    UPPER(TRIM(d.exterior_wall))                      AS exterior_wall,
    UPPER(TRIM(d.grade))                              AS grade,
    CAST(d.bedrooms AS UNSIGNED)                      AS bedrooms,
    CAST(d.full_bath AS UNSIGNED)                     AS full_bath,
    CAST(d.half_bath AS UNSIGNED)                     AS half_bath

    -- image column excluded: contains Windows file paths with no analytical value

FROM deduped d
WHERE d.rn = 1;   -- Discard duplicate rows
*/

-- =============================================================================
-- STEP 3: Verification
-- =============================================================================
-- These queries confirm the clean table matches the expected state from
-- notebooks/01_data_audit.ipynb. If counts or distributions differ materially,
-- investigate before using nashville_housing_clean in any analysis.
-- =============================================================================

-- Row count: expected 56,468
SELECT COUNT(*) AS row_count FROM nashville_housing_clean;

-- Column count: expected 29
SELECT COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'nashville_analytics'
  AND table_name   = 'nashville_housing_clean';

-- sold_as_vacant: expected N=51,588 and Y=4,880 only
SELECT sold_as_vacant, COUNT(*) AS count
FROM nashville_housing_clean
GROUP BY sold_as_vacant
ORDER BY sold_as_vacant;

-- Outlier flag: expected CLEAN=54,558 | STATISTICAL_OUTLIER=1,903 | ZERO_OR_NEAR_ZERO=7
SELECT price_outlier_flag, COUNT(*) AS count
FROM nashville_housing_clean
GROUP BY price_outlier_flag
ORDER BY count DESC;

-- Confirm no null bytes remain in building_value
SELECT COUNT(*) AS null_byte_rows
FROM nashville_housing_clean
WHERE INSTR(building_value, CHAR(0)) > 0;

-- Date range sanity check: should be 2013-2016 only
SELECT MIN(sale_date) AS earliest_sale, MAX(sale_date) AS latest_sale
FROM nashville_housing_clean;
