-- Nashville Property Analytics
-- Schema: raw ingestion table
-- Purpose: receives CSV data exactly as-is. No type casting at this stage.
-- All columns are VARCHAR to safely absorb dirty values, blanks, and formatting
-- inconsistencies. Type casting and cleaning happen in Notebook 01.

USE nashville_analytics;

CREATE TABLE IF NOT EXISTS nashville_housing_raw (
    parcel_id           VARCHAR(50),
    land_use            VARCHAR(100),
    property_address    VARCHAR(255),
    suite_condo         VARCHAR(50),
    property_city       VARCHAR(100),
    sale_date           VARCHAR(50),
    sale_price          VARCHAR(50),
    legal_reference     VARCHAR(100),
    sold_as_vacant      VARCHAR(10),
    multiple_parcels    VARCHAR(10),
    owner_name          VARCHAR(255),
    owner_address       VARCHAR(255),
    owner_city          VARCHAR(100),
    owner_state         VARCHAR(50),
    acreage             VARCHAR(50),
    tax_district        VARCHAR(100),
    neighborhood        VARCHAR(100),
    image               VARCHAR(255),
    land_value          VARCHAR(50),
    building_value      VARCHAR(50),
    total_value         VARCHAR(50),
    finished_area       VARCHAR(50),
    foundation_type     VARCHAR(100),
    year_built          VARCHAR(10),
    exterior_wall       VARCHAR(100),
    grade               VARCHAR(50),
    bedrooms            VARCHAR(10),
    full_bath           VARCHAR(10),
    half_bath           VARCHAR(10)
);
