#!/usr/bin/env bash
# Bring up Postgres/PostGIS in Docker and rebuild the schema from empty.
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose up -d
echo "Waiting for Postgres to be healthy..."
until [ "$(docker inspect -f '{{.State.Health.Status}}' iris_postgis_db 2>/dev/null)" = "healthy" ]; do
    sleep 1
done

export IRIS_DATABASE_URL="${IRIS_DATABASE_URL:-postgresql://iris_user:iris_password@localhost:5433/iris}"
python3 -m pip install -q -r requirements.txt
if ! python3 scripts/rebuild.py; then
    echo "FAILED: rebuild.py exited with an error. See output above." >&2
    echo "If this is a password/auth error, the Docker volume likely predates" >&2
    echo "the current docker-compose.yml. Fix with:" >&2
    echo "    docker compose down -v && scripts/reset.sh" >&2
    exit 1
fi
echo "Done. Run 'pytest tests/test_schema.py -v' for the behavioural test suite."
