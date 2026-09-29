-- Staging is deliberately permissive about geometry (raw source data can be
-- invalid) but not about country scope. Promotion into iris_core is where the
-- core constraints apply.
CREATE TABLE IF NOT EXISTS iris_staging.feature_raw (
    staging_id        BIGSERIAL PRIMARY KEY,
    country_code      TEXT        NOT NULL,
    region_code       TEXT,
    entity_type       TEXT        NOT NULL,
    natural_key       TEXT,
    source_id         TEXT        NOT NULL,
    source_date       DATE        NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    attributes        JSONB       NOT NULL DEFAULT '{}'::jsonb,
    geom              geometry(Geometry, 4326),
    validation_status TEXT        NOT NULL DEFAULT 'pending',
    validation_notes  TEXT,

    CONSTRAINT ck_feature_raw_country_code CHECK (country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT ck_feature_raw_entity_type
        CHECK (entity_type IN ('parcel', 'substation', 'peatland', 'screening_layer')),
    CONSTRAINT ck_feature_raw_status
        CHECK (validation_status IN ('pending', 'valid', 'rejected'))
);
