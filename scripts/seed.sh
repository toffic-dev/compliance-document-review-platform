#!/usr/bin/env bash
# Idempotent database setup + corpus seeding.
# Run this after `docker compose up -d db` on a fresh checkout.

set -euo pipefail

echo "==> Waiting for database to be ready..."
until docker compose exec -T db pg_isready -U "${POSTGRES_USER:-compliance}" > /dev/null 2>&1; do
  sleep 1
done

echo "==> Enabling pgvector extension..."
docker compose exec -T db psql -U "${POSTGRES_USER:-compliance}" -d "${POSTGRES_DB:-compliance_review}" -c "CREATE EXTENSION IF NOT EXISTS vector;"

echo "==> Creating retrieval tables (rules, document_chunks) if not present..."
docker compose exec -T db psql -U "${POSTGRES_USER:-compliance}" -d "${POSTGRES_DB:-compliance_review}" <<SQL
CREATE TABLE IF NOT EXISTS rules (
  id SERIAL PRIMARY KEY,
  rule_id TEXT,
  rule_text TEXT,
  embedding vector(384)
);

CREATE TABLE IF NOT EXISTS document_chunks (
  id SERIAL PRIMARY KEY,
  chunk_text TEXT,
  embedding vector(384)
);
SQL

echo "==> Running backend migrations..."
# TODO: replace with real migration command once Backend defines one, e.g.:
# docker compose exec backend python manage.py migrate

echo "==> Seeding corpus via Data Engineering's scripts..."
# Assumes compliance-document-review-data-engineering is cloned as a sibling
# repo (see README repo layout). Requires python + dependencies installed
# locally, or adjust to run inside a container if Data Eng provides one.
DATA_ENG_DIR="../compliance-document-review-data-engineering"
if [ -d "$DATA_ENG_DIR" ]; then
  # TODO: confirm exact script paths with Data Engineering - placeholders below
  if [ -f "$DATA_ENG_DIR/seed_rules.py" ]; then
    (cd "$DATA_ENG_DIR" && python3 seed_rules.py)
  else
    echo "    seed_rules.py not found at expected path - skipping, confirm path with Data Eng"
  fi
  if [ -f "$DATA_ENG_DIR/store_embeddings.py" ]; then
    (cd "$DATA_ENG_DIR" && python3 store_embeddings.py)
  else
    echo "    store_embeddings.py not found at expected path - skipping, confirm path with Data Eng"
  fi
else
  echo "    $DATA_ENG_DIR not found - clone it as a sibling repo to seed corpus data"
fi

echo "==> Done."
