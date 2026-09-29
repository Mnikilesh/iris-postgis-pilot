-- Spatial (GiST) indexes on the canonical geometry column.
CREATE INDEX IF NOT EXISTS idx_parcel_geom          ON iris_core.parcel          USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_substation_geom      ON iris_core.substation      USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_peatland_geom        ON iris_core.peatland        USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_screening_layer_geom ON iris_core.screening_layer USING GIST (geom);

-- BESS vertical: parcel-to-substation proximity in metres. ST_DWithin on the
-- geography cast can only use an index built on the same expression.
CREATE INDEX IF NOT EXISTS idx_parcel_geog     ON iris_core.parcel     USING GIST ((geom::geography));
CREATE INDEX IF NOT EXISTS idx_substation_geog ON iris_core.substation USING GIST ((geom::geography));

-- Country + region scoping (every pilot query filters on these first).
CREATE INDEX IF NOT EXISTS idx_parcel_scope          ON iris_core.parcel          (country_code, region_code);
CREATE INDEX IF NOT EXISTS idx_substation_scope      ON iris_core.substation      (country_code, region_code);
CREATE INDEX IF NOT EXISTS idx_peatland_scope        ON iris_core.peatland        (country_code, region_code);
CREATE INDEX IF NOT EXISTS idx_screening_layer_scope ON iris_core.screening_layer (country_code, region_code, layer_code);

-- Provenance lookups and foreign-key support.
CREATE INDEX IF NOT EXISTS idx_parcel_source          ON iris_core.parcel          (country_code, source_id, source_date);
CREATE INDEX IF NOT EXISTS idx_substation_source      ON iris_core.substation      (country_code, source_id, source_date);
CREATE INDEX IF NOT EXISTS idx_peatland_source        ON iris_core.peatland        (country_code, source_id, source_date);
CREATE INDEX IF NOT EXISTS idx_screening_layer_source ON iris_core.screening_layer (country_code, source_id, source_date);

CREATE INDEX IF NOT EXISTS idx_feature_raw_scope
    ON iris_staging.feature_raw (country_code, entity_type, validation_status);
