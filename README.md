# compliance-document-review-platform

This repo doesn't contain application code - it's the glue that brings all the
tracks' repos up together as one running app. Owned by DevOps/platform.

Full cross-team integration status (env vars, API contracts, open questions)
lives in [INTEGRATION.md](./INTEGRATION.md) - check there for the current
source of truth on anything that crosses track boundaries.

## Repo layout

Clone every track's repo into the same parent folder, next to this one:

```
compliance-review/
- compliance-document-review-app/              (Backend)
- compliance-document-review-frontend/         (no repo shared yet)
- compliance-document-review-ai/               (AI)
- compliance-document-review-data-engineering/ (Data Engineering)
- compliance-document-review-platform/         (this repo)
```

## Getting started (clean checkout)

1. Clone the repos above into the same parent folder as shown.
2. `cd` into `compliance-document-review-platform`.
3. Copy the example env file and fill in real values:
   ```
   cp .env.example .env
   ```
4. Bring up the database first:
   ```
   docker compose up -d db
   ```
5. Run the seed script:
   ```
   ./scripts/seed.sh
   ```
6. Bring up the rest (currently: backend, ai - frontend has no repo yet):
   ```
   docker compose up -d
   ```
7. Backend: http://localhost:8000 - AI service: http://localhost:8001

## Status

Done:
- [x] docker-compose with Postgres + pgvector, backend, frontend, and ai services
- [x] .env.example with all known env vars (Gemini, ports, db)
- [x] Repo names confirmed for backend, AI, and data engineering
- [x] CI (GitHub Actions) running on every push - spins up the db and confirms it's healthy
- [x] Clean-checkout tested end-to-end (fresh clone -> db -> seed all pass)
- [x] AI service Dockerfile confirmed working (builds and runs cleanly)
- [x] Embedding model mismatch (was AI 128-dim vs Data Eng 384-dim) - resolved, both on all-MiniLM-L6-v2
- [x] Retrieval API response shapes - confirmed and tested by Data Engineering

Open:
- [ ] Backend Dockerfile not yet added - blocks docker compose from building it
- [ ] Frontend - no repo shared yet
- [ ] AI currently loads a local vector_store.json instead of querying Data
      Engineering's shared pgvector retrieval jobs - confirmed via container
      logs, needs AI + Data Eng to align (see INTEGRATION.md)
- [ ] Service-to-service auth for Data Engineering calling Backend's file
      endpoint - proposed (shared internal token), not finalized

## Notes for the team

- Data Engineering's pipeline isn't run as its own long-lived service in this
  compose file - it's a separate pipeline against the shared Postgres/pgvector
  instance, not something docker-compose builds/starts directly.
- No real client data belongs anywhere in these repos, including seed data.
- No production AI API credits should be spent by this setup - use a
  free-tier/dev key per the spec.
