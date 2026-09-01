#!/usr/bin/env bash
# Idempotent database setup + corpus seeding.
# Run this after `docker compose up -d db` on a fresh checkout.
#
# Status:
#   - Data Engineering runs its own migrations for the embeddings/vector
#     tables directly from their repo (compliance-document-review-data-engineering).
#     Nothing to do here for that piece.
#   - Backend migrations (rules, disclosures, core app schema): TODO, waiting
#     on Backend to define a migration command.
#   - Seed corpus (rules, disclosures, ~100 sample docs): TODO, one-time job
#     per the spec, ~half a day with an LLM.

set -euo pipefail

echo "==> Waiting for database to be ready..."
until docker compose exec -T db pg_isready -U "${POSTGRES_USER:-compliance}" > /dev/null 2>&1; do
  sleep 1
done

echo "==> Running backend migrations..."
# TODO: replace with real migration command once Backend defines one, e.g.:
# docker compose exec backend python manage.py migrate

echo "==> Data Engineering migrations are run from their own repo, not here."
echo "    See compliance-document-review-data-engineering for details."

echo "==> Seeding corpus..."
# TODO: replace with real seed command once corpus generation is scripted, e.g.:
# docker compose exec backend python seed_corpus.py

echo "==> Done."
