#!/usr/bin/env bash
# Idempotent database setup + corpus seeding.
# Run this after `docker-compose up -d db` on a fresh checkout.
#
# TODO (pair with Data engineering once schema/embedding pipeline lands):
#   1. Run migrations against the db service
#   2. Load the seed corpus (rules, disclosures, ~100 sample docs)
#   3. Generate + store embeddings via the data-engineering pipeline

set -euo pipefail

echo "==> Waiting for database to be ready..."
until docker compose exec -T db pg_isready -U "${POSTGRES_USER:-compliance}" > /dev/null 2>&1; do
  sleep 1
done

echo "==> Running migrations..."
# TODO: replace with real migration command once backend defines one, e.g.:
# docker compose exec backend npm run migrate

echo "==> Seeding corpus..."
# TODO: replace with real seed command once data-engineering defines one, e.g.:
# docker compose exec data-engineering python seed.py

echo "==> Done."
