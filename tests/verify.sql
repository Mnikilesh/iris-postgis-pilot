-- Structural verification. Raises an exception on the first broken contract.
-- Run by scripts/rebuild.py after seeding. Behavioural checks live in
-- tests/test_schema.py.

-- 1. Schemas and tables
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['iris_core', 'iris_staging'] LOOP
        IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = t) THEN
            RAISE EXCEPTION 'Missing schema: %', t;
        END IF;
    END LOOP;

    FOREACH t IN ARRAY ARRAY['parcel','substation','peatland','screening_layer','source_run','evidence'] LOOP
        IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                       WHERE table_schema = 'iris_core' AND table_name = t) THEN
            RAISE EXCEPTION 'Missing table: iris_core.%', t;
        END IF;
    END LOOP;

    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = 'iris_staging' AND table_name = 'feature_raw') THEN
        RAISE EXCEPTION 'Missing table: iris_staging.feature_raw';
    END IF;
END $$;

-- 2. Canonical column names
DO $$
DECLARE t text; c text;
BEGIN
    FOREACH t IN ARRAY ARRAY['parcel','substation','peatland','screening_layer'] LOOP
        FOREACH c IN ARRAY ARRAY['geom','country_code','region_code','source_id','source_date','created_at'] LOOP
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                           WHERE table_schema = 'iris_core' AND table_name = t AND column_name = c) THEN
                RAISE EXCEPTION 'Missing canonical column iris_core.%.%', t, c;
            END IF;
        END LOOP;
    END LOOP;

    FOREACH t IN ARRAY ARRAY['source_run','evidence'] LOOP
        FOREACH c IN ARRAY ARRAY['country_code','source_id','source_date','created_at'] LOOP
            IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                           WHERE table_schema = 'iris_core' AND table_name = t AND column_name = c) THEN
                RAISE EXCEPTION 'Missing canonical column iris_core.%.%', t, c;
            END IF;
        END LOOP;
    END LOOP;

    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema IN ('iris_core','iris_staging') AND column_name = 'geometry') THEN
        RAISE EXCEPTION 'A column named "geometry" exists; the canonical name is "geom"';
    END IF;
END $$;

-- 3. country_code is NOT NULL on every table in both schemas that has it
DO $$
DECLARE bad text;
BEGIN
    SELECT table_schema || '.' || table_name INTO bad
    FROM information_schema.columns
    WHERE table_schema IN ('iris_core','iris_staging')
      AND column_name = 'country_code' AND is_nullable = 'YES'
    LIMIT 1;
    IF bad IS NOT NULL THEN RAISE EXCEPTION 'country_code is nullable on %', bad; END IF;

    IF (SELECT count(*) FROM information_schema.columns
        WHERE table_schema IN ('iris_core','iris_staging') AND column_name = 'country_code') <> 7 THEN
        RAISE EXCEPTION 'Expected country_code on exactly 7 tables';
    END IF;
END $$;

-- 4. Geometry types and SRIDs
DO $$
DECLARE r record;
BEGIN
    FOR r IN SELECT * FROM (VALUES
        ('parcel','POLYGON'), ('substation','POINT'),
        ('peatland','MULTIPOLYGON'), ('screening_layer','MULTIPOLYGON')
    ) AS v(t, ty) LOOP
        IF NOT EXISTS (SELECT 1 FROM public.geometry_columns
                       WHERE f_table_schema = 'iris_core' AND f_table_name = r.t
                         AND f_geometry_column = 'geom' AND type = r.ty AND srid = 4326) THEN
            RAISE EXCEPTION 'Bad geometry contract on iris_core.% (expected % / 4326)', r.t, r.ty;
        END IF;
    END LOOP;
END $$;

-- 5. Every business entity and evidence row has a foreign key to source_run
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['parcel','substation','peatland','screening_layer','evidence'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_constraint
                       WHERE contype = 'f'
                         AND conrelid = ('iris_core.' || t)::regclass
                         AND confrelid = 'iris_core.source_run'::regclass) THEN
            RAISE EXCEPTION 'iris_core.% has no foreign key to source_run', t;
        END IF;
    END LOOP;
END $$;

-- 6. Required indexes exist, and the geometry ones are GiST
DO $$
DECLARE i text;
BEGIN
    FOREACH i IN ARRAY ARRAY['idx_parcel_geom','idx_substation_geom','idx_peatland_geom',
                             'idx_screening_layer_geom','idx_parcel_geog','idx_substation_geog'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_indexes
                       WHERE schemaname = 'iris_core' AND indexname = i
                         AND indexdef ILIKE '%USING gist%') THEN
            RAISE EXCEPTION 'Missing GiST index: %', i;
        END IF;
    END LOOP;

    FOREACH i IN ARRAY ARRAY['idx_parcel_scope','idx_substation_scope','idx_peatland_scope',
                             'idx_screening_layer_scope'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'iris_core' AND indexname = i) THEN
            RAISE EXCEPTION 'Missing index: %', i;
        END IF;
    END LOOP;
END $$;

-- 7. Seed data present, valid, and survives a binary round trip
DO $$
DECLARE t text; n bigint; bad bigint;
BEGIN
    FOREACH t IN ARRAY ARRAY['parcel','substation','peatland','screening_layer'] LOOP
        EXECUTE format('SELECT count(*) FROM iris_core.%I', t) INTO n;
        IF n = 0 THEN RAISE EXCEPTION 'No seed rows in iris_core.%', t; END IF;

        EXECUTE format('SELECT count(*) FROM iris_core.%I
                        WHERE NOT ST_IsValid(geom)
                           OR NOT ST_Equals(geom, ST_GeomFromEWKB(ST_AsEWKB(geom)))', t) INTO bad;
        IF bad > 0 THEN RAISE EXCEPTION 'Invalid or non-round-tripping geometry in iris_core.%', t; END IF;
    END LOOP;
END $$;
