# Integration contract

Single source of truth for decisions that cross track boundaries. Update this
via PR as things get confirmed - don't let answers live only in chat.

## Environment variables

| Variable | Owner | Value / notes |
|---|---|---|
| `GEMINI_API_KEY` | AI | Gemini API key. Never commit a real value. |
| `GEMINI_MODEL` | AI | Configurable, defaults to `gemini-1.5-flash` |
| `DATABASE_URL` | DevOps | Set automatically by docker-compose from `POSTGRES_*` vars |
| `BACKEND_PORT` / `FRONTEND_PORT` / `AI_PORT` | DevOps | Default 8000 / 3000 / 8001 |
| `INTERNAL_SERVICE_TOKEN` | Backend | Shared secret for Data Eng -> Backend internal file-access calls. Implemented and tested by Backend. |

## Data Engineering DB connection - hardcoded localhost

**Status: resolved**

Fixed by Data Engineering - now reads from DATABASE_URL env var instead of
hardcoding localhost, matching the rest of the stack. Also added
seed_document_chunks.py for generic sample data.

## AI analysis endpoint + service networking

**Status: confirmed**

AI analysis endpoint: `POST /ai/analyze/{document_id}` - no Authorization/
Bearer header required.

Docker-compose networking: Backend -> AI should use `http://ai:8001`
(service name resolution within the compose network), not localhost.

AI -> Data Engineering connection controlled by env vars:
`DATA_ENGINEERING_BASE_URL` and `USE_DATA_ENGINEERING_SERVICE=true`.

Note: AI service is local/docker-compose only for this submission, not part
of the Railway deployment (see Production deployment section) - live AI
analysis is out of scope for the current deployment target.

## API path prefix

**Status: decided (final - per supervisor direction)**

Standardized on `/api/v1` prefix, for versioning (allows a future `/api/v2`
without breaking existing clients):
- `/api/v1/auth/...`
- `/api/v1/documents/...`

Backend: needs to update its existing endpoint from
`/documents/{document_id}/file` to `/api/v1/documents/{document_id}/file`.
Data Engineering: update calls to match once Backend's change is live.
Frontend: matches what was already assumed, just add `/v1`.

Note: frontend's own local dev server running on :4000 is unrelated - that's
just Next.js's dev port, not the backend's. Frontend calls out to backend's
:8000 (or BACKEND_PORT), it doesn't share a port with it.

## Masked-text handoff (AI -> Data Engineering)

**Status: confirmed**

AI provides PII-masked text only - the PII mapping stays server-side and is
never sent to the embedding or Gemini APIs.

Format: `document_id, chunk_id, masked_text`

Example:
```
DOC-001, DOC-001-CHUNK-001, "Client [CLIENT_1] invested in [ACCOUNT_1]..."
```

## Vector storage ownership

**Status: confirmed**

Data Engineering owns the vector storage/retrieval schema in the shared
Postgres + pgvector instance. AI consumes retrieval results rather than
maintaining a separate production vector store. Data Engineering is running
its own migrations for the embeddings table and will share the schema here
once finalized.

## Embedding model / API

**Status: resolved**

Both sides now on `all-MiniLM-L6-v2`, 384 dimensions. Data Engineering's
pipeline (extraction -> chunking -> embedding -> insert) and AI's embedding
integration both verified against this model.

## Retrieval API response shape

**Status: confirmed, tested end-to-end**

Rule lookup:
```
{ rule_id: string, rule_text: string, similarity_score: float }
```

Disclosure-by-absence (verified for both present and missing cases):
```
{ disclosure_id: string, disclosure_type: string, present: boolean, similarity_score: float, matched_chunk_id: string | null }
```

Precedent match:
```
{ document_id: string, chunk_id: string, similarity_score: float, chunk_text: string }
```

Note: `document_id` in precedent search is currently a placeholder on Data
Engineering's side, pending Backend's document metadata format.

## Production deployment (frontend + backend)

**Status: unblocked, ready to execute**

Per supervisor direction: Frontend deploys on Vercel, not via docker-compose.
Since Vercel-hosted frontend can't reach a local backend, Backend also needs
a public home.

Plan:
- Backend + Postgres/pgvector: Railway (supports pgvector on managed
  Postgres, deploys from a Dockerfile, keeps app and db on the same private
  network). Build context: compliance-document-review-app/Backend
- Frontend: Vercel, with `NEXT_PUBLIC_API_BASE_URL` (or equivalent) pointed
  at the Railway backend's public URL
- AI service: staying local/docker-compose only for now, not part of this
  deployment - production flow does not require live AI analysis yet

Backend's Dockerfile is done (in the Backend/ subfolder) - DevOps setting up
Railway next.

Still needed once backend is live: Backend must allow CORS requests from the
Vercel frontend's domain, or the browser will block API calls even if the
backend itself is reachable.

## Dockerfiles / deployment (needed for each service to run)

**Status: in progress**

| Repo | Deployment method | Notes |
|---|---|---|
| Backend (compliance-document-review-app) | Docker (docker-compose) | Done - Dockerfile lives in the Backend/ subfolder, build context set accordingly |
| AI (compliance-document-review-ai) | Docker (docker-compose) | Done - FastAPI/Uvicorn, port 8001, matches AI_PORT default |
| Frontend (compliance-document-review-frontend) | Vercel | Per supervisor direction - not run via docker-compose. Repo has a working Dockerfile if that ever changes, but Vercel is the current plan. |
| Data Engineering | N/A | Not run as its own compose service currently |

## Precedent retrieval - single source of truth

**Status: resolved**

Confirmed by Sushma (Data Eng) and Naga (AI): AI's local `vector_store.json`
is test-only. For the integrated system, AI consumes Data Engineering's
retrieval API as the single production source of truth for rules,
disclosures, and precedents. No further action needed from either side on
this specific question.

## Document-text handoff (Backend -> Data Engineering)

**Status: resolved**

Confirmed flow: Frontend -> Backend upload/storage -> Data Engineering
retrieves the original file via Backend endpoint -> extraction -> chunking ->
embeddings -> pgvector. Backend does not duplicate the extraction pipeline.

Endpoints (Backend):
- `POST /api/v1/documents/upload` - uploads file, stores it, creates document metadata
- `GET /api/v1/documents/{document_id}/file` - retrieves the original uploaded file by document_id, protected by INTERNAL_SERVICE_TOKEN (path update pending on Backend - see API path prefix section above)

Auth: `INTERNAL_SERVICE_TOKEN` shared secret, checked by Backend via
`verify_internal_service_token`. Tested successfully by Backend (200 + file
returned). Data Engineering: send this as a header when calling the file
endpoint - see .env.example for the var name.
