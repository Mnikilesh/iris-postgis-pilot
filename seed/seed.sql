-- Deterministic fixtures. GB / ENG-NW is the pilot region; one NL parcel reuses
-- code 'P001' to show that keys are country-scoped.

INSERT INTO iris_core.source_run (country_code, source_id, source_date, status) VALUES
    ('GB', 'fixture-grid-001',        '2026-01-15', 'completed'),
    ('GB', 'fixture-environment-001', '2026-01-20', 'completed'),
    ('NL', 'fixture-grid-nl-001',     '2026-01-15', 'completed');

INSERT INTO iris_core.evidence (country_code, source_id, source_date, evidence_type, reference) VALUES
    ('GB', 'fixture-grid-001',        '2026-01-15', 'grid_source',        'local-fixture-grid'),
    ('GB', 'fixture-environment-001', '2026-01-20', 'environment_source', 'local-fixture-environment');

INSERT INTO iris_core.parcel (country_code, region_code, parcel_code, source_id, source_date, geom) VALUES
    ('GB', 'ENG-NW', 'P001', 'fixture-grid-001', '2026-01-15',
     ST_GeomFromText('POLYGON((-2.010 53.480,-2.000 53.480,-2.000 53.490,-2.010 53.490,-2.010 53.480))', 4326)),
    ('GB', 'ENG-NW', 'P002', 'fixture-grid-001', '2026-01-15',
     ST_GeomFromText('POLYGON((-2.020 53.480,-2.010 53.480,-2.010 53.490,-2.020 53.490,-2.020 53.480))', 4326)),
    ('GB', 'ENG-NW', 'P003', 'fixture-grid-001', '2026-01-15',
     ST_GeomFromText('POLYGON((-2.010 53.470,-2.000 53.470,-2.000 53.480,-2.010 53.480,-2.010 53.470))', 4326)),
    ('GB', 'ENG-NW', 'P004', 'fixture-grid-001', '2026-01-15',
     ST_GeomFromText('POLYGON((-2.020 53.470,-2.010 53.470,-2.010 53.480,-2.020 53.480,-2.020 53.470))', 4326)),
    ('NL', 'NL-DR',  'P001', 'fixture-grid-nl-001', '2026-01-15',
     ST_GeomFromText('POLYGON((6.560 52.990,6.570 52.990,6.570 53.000,6.560 53.000,6.560 52.990))', 4326));

INSERT INTO iris_core.substation (country_code, region_code, substation_code, source_id, source_date, geom) VALUES
    ('GB', 'ENG-NW', 'SS001', 'fixture-grid-001', '2026-01-15', ST_SetSRID(ST_Point(-2.005, 53.485), 4326)),
    ('GB', 'ENG-NW', 'SS002', 'fixture-grid-001', '2026-01-15', ST_SetSRID(ST_Point(-2.015, 53.475), 4326));

INSERT INTO iris_core.peatland (country_code, region_code, peatland_code, source_id, source_date, geom) VALUES
    ('GB', 'ENG-NW', 'PT001', 'fixture-environment-001', '2026-01-20',
     ST_GeomFromText('MULTIPOLYGON(((-2.018 53.482,-2.014 53.482,-2.014 53.486,-2.018 53.486,-2.018 53.482)))', 4326)),
    ('GB', 'ENG-NW', 'PT002', 'fixture-environment-001', '2026-01-20',
     ST_GeomFromText('MULTIPOLYGON(((-2.008 53.472,-2.004 53.472,-2.004 53.476,-2.008 53.476,-2.008 53.472)))', 4326));

INSERT INTO iris_core.screening_layer (country_code, region_code, layer_code, source_id, source_date, geom) VALUES
    ('GB', 'ENG-NW', 'FLOOD_RISK', 'fixture-environment-001', '2026-01-20',
     ST_GeomFromText('MULTIPOLYGON(((-2.025 53.475,-2.018 53.475,-2.018 53.482,-2.025 53.482,-2.025 53.475)))', 4326)),
    ('GB', 'ENG-NW', 'PROTECTED_AREA', 'fixture-environment-001', '2026-01-20',
     ST_GeomFromText('MULTIPOLYGON(((-2.015 53.485,-2.008 53.485,-2.008 53.492,-2.015 53.492,-2.015 53.485)))', 4326));

-- A raw record with a self-intersecting (bow-tie) polygon. Staging accepts it
-- and marks it rejected; the core constraints would refuse it.
INSERT INTO iris_staging.feature_raw
    (country_code, region_code, entity_type, natural_key, source_id, source_date,
     geom, validation_status, validation_notes) VALUES
    ('GB', 'ENG-NW', 'parcel', 'PX01', 'fixture-grid-001', '2026-01-15',
     ST_GeomFromText('POLYGON((-2.030 53.480,-2.020 53.490,-2.020 53.480,-2.030 53.490,-2.030 53.480))', 4326),
     'rejected', 'self-intersecting polygon');
