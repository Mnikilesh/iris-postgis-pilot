-- Geometry contract for stored data: WGS84 (EPSG:4326), non-empty, valid,
-- inside the lon/lat range. Used by a CHECK on every core geom column.
CREATE OR REPLACE FUNCTION iris_core.is_valid_wgs84(g geometry)
RETURNS boolean
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
    SELECT g IS NOT NULL
       AND ST_SRID(g) = 4326
       AND NOT ST_IsEmpty(g)
       AND ST_IsValid(g)
       AND ST_XMin(g) >= -180 AND ST_XMax(g) <= 180
       AND ST_YMin(g) >= -90  AND ST_YMax(g) <= 90
$$;

CREATE TABLE IF NOT EXISTS iris_core.parcel (
    parcel_id         BIGSERIAL PRIMARY KEY,
    country_code      TEXT        NOT NULL,
    region_code       TEXT        NOT NULL,
    parcel_code       TEXT        NOT NULL,
    source_id         TEXT        NOT NULL,
    source_date       DATE        NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    geom              geometry(Polygon, 4326) NOT NULL,
    data_completeness NUMERIC(5,2),
    uncertainty_m     NUMERIC(10,2),

    CONSTRAINT ck_parcel_country_code  CHECK (country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT ck_parcel_region_code   CHECK (btrim(region_code) <> ''),
    CONSTRAINT ck_parcel_code          CHECK (btrim(parcel_code) <> ''),
    CONSTRAINT ck_parcel_geom          CHECK (iris_core.is_valid_wgs84(geom)),
    CONSTRAINT ck_parcel_completeness  CHECK (data_completeness IS NULL OR data_completeness BETWEEN 0 AND 100),
    CONSTRAINT ck_parcel_uncertainty   CHECK (uncertainty_m IS NULL OR uncertainty_m >= 0),
    CONSTRAINT uq_parcel_country_code  UNIQUE (country_code, parcel_code),
    CONSTRAINT fk_parcel_source_run
        FOREIGN KEY (country_code, source_id, source_date)
        REFERENCES iris_core.source_run (country_code, source_id, source_date)
);

CREATE TABLE IF NOT EXISTS iris_core.substation (
    substation_id     BIGSERIAL PRIMARY KEY,
    country_code      TEXT        NOT NULL,
    region_code       TEXT        NOT NULL,
    substation_code   TEXT        NOT NULL,
    source_id         TEXT        NOT NULL,
    source_date       DATE        NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    geom              geometry(Point, 4326) NOT NULL,
    data_completeness NUMERIC(5,2),
    uncertainty_m     NUMERIC(10,2),

    CONSTRAINT ck_substation_country_code CHECK (country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT ck_substation_region_code  CHECK (btrim(region_code) <> ''),
    CONSTRAINT ck_substation_code         CHECK (btrim(substation_code) <> ''),
    CONSTRAINT ck_substation_geom         CHECK (iris_core.is_valid_wgs84(geom)),
    CONSTRAINT ck_substation_completeness CHECK (data_completeness IS NULL OR data_completeness BETWEEN 0 AND 100),
    CONSTRAINT ck_substation_uncertainty  CHECK (uncertainty_m IS NULL OR uncertainty_m >= 0),
    CONSTRAINT uq_substation_country_code UNIQUE (country_code, substation_code),
    CONSTRAINT fk_substation_source_run
        FOREIGN KEY (country_code, source_id, source_date)
        REFERENCES iris_core.source_run (country_code, source_id, source_date)
);

-- peatland_code is a source-supplied feature identifier (needed so a feature
-- can be identified and re-loaded). It is not an invented geospatial attribute.
CREATE TABLE IF NOT EXISTS iris_core.peatland (
    peatland_id       BIGSERIAL PRIMARY KEY,
    country_code      TEXT        NOT NULL,
    region_code       TEXT        NOT NULL,
    peatland_code     TEXT        NOT NULL,
    source_id         TEXT        NOT NULL,
    source_date       DATE        NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    geom              geometry(MultiPolygon, 4326) NOT NULL,
    data_completeness NUMERIC(5,2),
    uncertainty_m     NUMERIC(10,2),

    CONSTRAINT ck_peatland_country_code CHECK (country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT ck_peatland_region_code  CHECK (btrim(region_code) <> ''),
    CONSTRAINT ck_peatland_code         CHECK (btrim(peatland_code) <> ''),
    CONSTRAINT ck_peatland_geom         CHECK (iris_core.is_valid_wgs84(geom)),
    CONSTRAINT ck_peatland_completeness CHECK (data_completeness IS NULL OR data_completeness BETWEEN 0 AND 100),
    CONSTRAINT ck_peatland_uncertainty  CHECK (uncertainty_m IS NULL OR uncertainty_m >= 0),
    CONSTRAINT uq_peatland_country_code UNIQUE (country_code, peatland_code),
    CONSTRAINT fk_peatland_source_run
        FOREIGN KEY (country_code, source_id, source_date)
        REFERENCES iris_core.source_run (country_code, source_id, source_date)
);

-- One row per layer, per region, per source date, so layers can be versioned
-- and can differ between regions.
CREATE TABLE IF NOT EXISTS iris_core.screening_layer (
    screening_layer_id BIGSERIAL PRIMARY KEY,
    country_code       TEXT        NOT NULL,
    region_code        TEXT        NOT NULL,
    layer_code         TEXT        NOT NULL,
    source_id          TEXT        NOT NULL,
    source_date        DATE        NOT NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    geom               geometry(MultiPolygon, 4326) NOT NULL,
    data_completeness  NUMERIC(5,2),
    uncertainty_m      NUMERIC(10,2),

    CONSTRAINT ck_screening_country_code CHECK (country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT ck_screening_region_code  CHECK (btrim(region_code) <> ''),
    CONSTRAINT ck_screening_layer_code   CHECK (btrim(layer_code) <> ''),
    CONSTRAINT ck_screening_geom         CHECK (iris_core.is_valid_wgs84(geom)),
    CONSTRAINT ck_screening_completeness CHECK (data_completeness IS NULL OR data_completeness BETWEEN 0 AND 100),
    CONSTRAINT ck_screening_uncertainty  CHECK (uncertainty_m IS NULL OR uncertainty_m >= 0),
    CONSTRAINT uq_screening_layer_key UNIQUE (country_code, region_code, layer_code, source_date),
    CONSTRAINT fk_screening_source_run
        FOREIGN KEY (country_code, source_id, source_date)
        REFERENCES iris_core.source_run (country_code, source_id, source_date)
);
