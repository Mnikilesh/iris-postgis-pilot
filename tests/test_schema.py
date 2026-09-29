"""Behavioural tests: every constraint the schema claims to have is exercised
against a live database, not just asserted by inspecting DDL.

Run with the database already rebuilt:
    python scripts/rebuild.py
    pytest tests/test_schema.py -v
"""
from __future__ import annotations

import os

import psycopg
import pytest

DSN = os.environ.get("IRIS_DATABASE_URL", "postgresql://iris_user:iris_password@localhost:5433/iris")

VALID_POLY = "POLYGON((-1.000 51.000,-0.990 51.000,-0.990 51.010,-1.000 51.010,-1.000 51.000))"
BOWTIE_POLY = "POLYGON((-1.000 51.000,-0.990 51.010,-0.990 51.000,-1.000 51.010,-1.000 51.000))"


@pytest.fixture()
def conn():
    with psycopg.connect(DSN, autocommit=True) as c:
        yield c


@pytest.fixture()
def rollback_conn():
    """A connection whose changes are always rolled back, so tests don't
    depend on execution order or leave fixtures dirty."""
    with psycopg.connect(DSN) as c:
        yield c
        c.rollback()


def insert_parcel(conn, **overrides):
    values = dict(
        country_code="GB", region_code="ENG-NW", parcel_code="TESTX",
        source_id="fixture-grid-001", source_date="2026-01-15", geom=VALID_POLY, srid=4326,
    )
    values.update(overrides)
    conn.execute(
        """INSERT INTO iris_core.parcel
               (country_code, region_code, parcel_code, source_id, source_date, geom)
           VALUES (%(country_code)s, %(region_code)s, %(parcel_code)s,
                   %(source_id)s, %(source_date)s, ST_GeomFromText(%(geom)s, %(srid)s))""",
        values,
    )


class TestCountryCode:
    def test_null_country_code_rejected(self, rollback_conn):
        with pytest.raises(psycopg.errors.NotNullViolation):
            insert_parcel(rollback_conn, country_code=None)

    def test_lowercase_country_code_rejected(self, rollback_conn):
        with pytest.raises(psycopg.errors.CheckViolation):
            insert_parcel(rollback_conn, country_code="gb")

    def test_blank_country_code_rejected(self, rollback_conn):
        with pytest.raises(psycopg.errors.CheckViolation):
            insert_parcel(rollback_conn, country_code="  ")

    def test_wrong_length_country_code_rejected(self, rollback_conn):
        with pytest.raises(psycopg.errors.CheckViolation):
            insert_parcel(rollback_conn, country_code="GBR")

    def test_valid_country_code_accepted(self, rollback_conn):
        rollback_conn.execute(
            "INSERT INTO iris_core.source_run (country_code, source_id, source_date) "
            "VALUES ('FR', 'fixture-grid-fr-001', '2026-01-15')"
        )
        insert_parcel(rollback_conn, country_code="FR", source_id="fixture-grid-fr-001", parcel_code="FRTEST")


class TestCountryScopedKeys:
    def test_duplicate_parcel_code_same_country_rejected(self, rollback_conn):
        insert_parcel(rollback_conn, parcel_code="DUPTEST")
        with pytest.raises(psycopg.errors.UniqueViolation):
            insert_parcel(rollback_conn, parcel_code="DUPTEST")

    def test_same_parcel_code_different_country_allowed(self, rollback_conn):
        rollback_conn.execute(
            "INSERT INTO iris_core.source_run (country_code, source_id, source_date) "
            "VALUES ('FR', 'fixture-grid-fr-001', '2026-01-15')"
        )
        insert_parcel(rollback_conn, country_code="GB", parcel_code="SHARED")
        insert_parcel(rollback_conn, country_code="FR", source_id="fixture-grid-fr-001", parcel_code="SHARED")


class TestGeometryContract:
    def test_bowtie_polygon_rejected(self, rollback_conn):
        with pytest.raises(psycopg.errors.CheckViolation):
            insert_parcel(rollback_conn, geom=BOWTIE_POLY)

    def test_empty_polygon_rejected(self, rollback_conn):
        with pytest.raises(psycopg.errors.CheckViolation):
            insert_parcel(rollback_conn, geom="POLYGON EMPTY")

    def test_out_of_range_longitude_rejected(self, rollback_conn):
        with pytest.raises(psycopg.errors.CheckViolation):
            insert_parcel(rollback_conn, geom="POLYGON((-200 0,-199 0,-199 1,-200 1,-200 0))")

    def test_wrong_srid_rejected(self, rollback_conn):
        # PostGIS enforces the typmod SRID at the type level, before any CHECK runs.
        with pytest.raises(psycopg.errors.InvalidParameterValue):
            insert_parcel(rollback_conn, geom=VALID_POLY, srid=27700)

    def test_point_rejected_for_polygon_column(self, rollback_conn):
        with pytest.raises(psycopg.errors.InvalidParameterValue):
            insert_parcel(rollback_conn, geom="POINT(-1.0 51.0)")

    def test_valid_geometry_accepted(self, rollback_conn):
        insert_parcel(rollback_conn, parcel_code="GEOMOK")


class TestProvenanceForeignKey:
    def test_unknown_source_run_rejected(self, rollback_conn):
        with pytest.raises(psycopg.errors.ForeignKeyViolation):
            insert_parcel(rollback_conn, source_id="does-not-exist", source_date="2026-01-15")

    def test_known_source_run_in_wrong_country_rejected(self, rollback_conn):
        # fixture-grid-nl-001/2026-01-15 exists, but only for NL, not GB.
        with pytest.raises(psycopg.errors.ForeignKeyViolation):
            insert_parcel(rollback_conn, country_code="GB", source_id="fixture-grid-nl-001", source_date="2026-01-15")


class TestPeatlandAndScreeningKeys:
    def test_duplicate_of_seed_peatland_rejected(self, rollback_conn):
        with pytest.raises(psycopg.errors.UniqueViolation):
            rollback_conn.execute(
                """INSERT INTO iris_core.peatland
                       (country_code, region_code, peatland_code, source_id, source_date, geom)
                   SELECT country_code, region_code, peatland_code, source_id, source_date, geom
                   FROM iris_core.peatland LIMIT 1"""
            )

    def test_screening_layer_versioned_by_source_date(self, rollback_conn):
        # A new source_date for the same layer/region/country is a new version,
        # not a duplicate-key error.
        rollback_conn.execute(
            """INSERT INTO iris_core.source_run (country_code, source_id, source_date)
               VALUES ('GB','fixture-environment-002','2026-06-01')"""
        )
        rollback_conn.execute(
            """INSERT INTO iris_core.screening_layer
                   (country_code, region_code, layer_code, source_id, source_date, geom)
               VALUES ('GB','ENG-NW','FLOOD_RISK','fixture-environment-002','2026-06-01',
                       ST_GeomFromText('MULTIPOLYGON(((-2.025 53.475,-2.018 53.475,-2.018 53.482,-2.025 53.482,-2.025 53.475)))', 4326))"""
        )


class TestSpatialRoundTrip:
    def test_ewkb_round_trip_preserves_geometry(self, conn):
        row = conn.execute(
            "SELECT ST_AsEWKB(geom) FROM iris_core.parcel WHERE parcel_code = 'P001' AND country_code = 'GB'"
        ).fetchone()
        assert row is not None
        (wkb,) = row
        restored = conn.execute(
            "SELECT ST_Equals(ST_GeomFromEWKB(%s), (SELECT geom FROM iris_core.parcel WHERE parcel_code = 'P001' AND country_code = 'GB'))",
            (bytes(wkb),),
        ).fetchone()[0]
        assert restored is True

    def test_index_used_for_proximity_query(self, conn):
        plan = conn.execute(
            """EXPLAIN SELECT p.parcel_code FROM iris_core.parcel p
               JOIN iris_core.substation s ON ST_DWithin(p.geom::geography, s.geom::geography, 500)
               WHERE p.country_code = 'GB'"""
        ).fetchall()
        plan_text = "\n".join(r[0] for r in plan)
        assert "idx_parcel_geog" in plan_text or "idx_substation_geog" in plan_text or "Index" in plan_text
