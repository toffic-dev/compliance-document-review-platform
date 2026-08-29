# compliance-document-review-platform

This repo doesn't contain application code — it's the glue that brings all the
tracks' repos up together as one running app. Owned by DevOps/platform.

## Repo layout

Clone every track's repo into the same parent folder, next to this one:

```
compliance-review/
├── compliance-document-review-backend/
├── compliance-document-review-frontend/
├── compliance-document-review-ai/
├── compliance-document-review-data-engineering/
└── compliance-document-review-platform/   <- you are here
```

> If your team's repo names differ from the above, update the `context:`
> paths in `docker-compose.yml` to match before continuing.

## Getting started (clean checkout)

1. Clone all five repos into the same parent folder as shown above.
2. `cd` into `compliance-document-review-platform`.
3. Copy the example env file and fill in real values:
   ```
   cp .env.example .env
   ```
4. Bring up the database first:
   ```
   docker compose up -d db
   ```
5. Run the seed script (migrations + corpus seeding):
   ```
   ./scripts/seed.sh
   ```
6. Bring up everything else:
   ```
   docker compose up -d
   ```
7. Backend: http://localhost:8000 · Frontend: http://localhost:3000 · AI service: http://localhost:8001

## Status

- [x] docker-compose skeleton (db, backend, frontend, ai)
- [x] .env.example
- [ ] Confirmed repo names from each track
- [ ] Confirmed AI_API_KEY env var name with AI track
- [ ] Real migration + seed commands (pairing with Backend / Data engineering)
- [ ] CI workflow running tests on push

## Notes for the team

- Data engineering's pipeline isn't run as its own long-lived service in this
  compose file yet — right now it's assumed to be invoked as a script/job by
  the seed process or by the AI service. Flag me if that's wrong and it needs
  its own container.
- No real client data belongs anywhere in these repos, including seed data.
- No production AI API credits should be spent by this setup — use a
  free-tier/dev key per the spec.
