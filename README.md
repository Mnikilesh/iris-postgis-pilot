# IRIS-CAND-03 — Canonical PostGIS Pilot Schema

## Setup

Requires Docker (for Postgres/PostGIS) and Python 3.12+.

```bash
git clone <this-repo>
cd iris-postgis-pilot-submission
./scripts/reset.sh        # macOS / Linux
scripts\reset.bat         # Windows
```

This brings up `postgis/postgis:16-3.4` on `localhost:5433`, waits for the
healthcheck, installs `requirements.txt`, and runs `scripts/rebuild.py`,
which drops `iris_core`/`iris_staging`, applies every file in `migrations/`
in order, loads `seed/seed.sql`, and runs `tests/verify.sql`. The whole
script exits non-zero on the first failure, so "done" means it actually
worked, not that it got to the end.

To run behavioural tests after a rebuild:

```bash
pip install -r requirements.txt
pytest tests/test_schema.py -v
```

### Manual / without Docker

```bash
createdb iris
export IRIS_DATABASE_URL=postgresql://<user>@localhost:5432/iris
pip install -r requirements.txt
python3 scripts/rebuild.py
```

`scripts/rebuild.py --verify-only` re-runs `tests/verify.sql` without
touching data. `scripts/rebuild.py --no-seed` builds schema only.

## Assumptions
- One region per pilot run at a time (`ENG-NW` in the fixtures); the schema
  itself is not region-limited.
- `parcel_code`, `substation_code`, `peatland_code`, and `layer_code` are
  source-supplied natural keys, unique per country. They are declared as
  fields in the assignment's fixture context, not invented attributes.
- A `screening_layer` row is a versioned snapshot: same layer and region can
  recur with a new `source_date`, not update in place.
- No production credentials or paid APIs; `docker-compose.yml` runs Postgres
  locally with a fixed development password.

## Architecture choices
- **Country-scoped keys everywhere.** Every core table has `NOT NULL
  country_code` matching `^[A-Z]{2}$`, and every natural key is
  `(country_code, ...)`, not the bare code alone. Two countries can reuse the
  same `parcel_code` without colliding.
- **Provenance is a real foreign key, not a text field.** `source_run` is the
  single record of "this batch of data was loaded, from this source, on this
  date, for this country." Every business table has a composite FK to
  `(country_code, source_id, source_date)`, so a row cannot reference a
  source run that doesn't exist or belongs to a different country.
- **Geometry contract enforced by a CHECK, not convention.** `is_valid_wgs84()`
  rejects null, wrong-SRID, empty, invalid (self-intersecting), or
  out-of-range geometry at insert time. PostGIS's own typmod already rejects
  the wrong geometry type or SRID before the CHECK runs.
- **Staging is permissive on geometry, strict on country.** Raw records can
  be invalid (that's what triggers `validation_status = 'rejected'`), but
  `country_code` is still required and format-checked, since scoping happens
  before validation.
- **Indexes chosen for the two verticals**, not generic: geography-cast GiST
  for the BESS distance query (`ST_DWithin` in metres), plain geometry GiST
  for peatland/screening intersection, and `(country_code, region_code)`
  B-trees since every query filters on those first. See `docs/schema.md`.

## Deliverables map
| Requirement | Location |
|---|---|
| SQL migrations | `migrations/001`–`006` |
| Seed fixtures | `seed/seed.sql` |
| Schema diagram | `docs/schema.md` (Mermaid ERD) |
| Verification queries | `tests/verify.sql` (structural), `tests/test_schema.py` (behavioural, 19 cases) |
| Reset/rebuild | `scripts/reset.sh`, `scripts/reset.bat`, `scripts/rebuild.py` |
| Pilot query demos | `queries/bess_candidates.sql`, `queries/peatland_screening.sql` |

## Deliberate simplifications
See "Deliberate simplifications" in `docs/schema.md` for what's cut for pilot
scope (no row versioning, no RLS, single `feature_raw` staging table) and how
each would evolve for production.

## Uncertainty disclosure
Per project convention: preliminary prospecting material. Figures and site
suitability in any output built on this schema are indicative and based on
available source data and screening assumptions, not certified compensation
or confirmed feasibility. Ownership, planning, grid capacity, environmental
eligibility and transferability remain subject to project-specific
verification.
