# Integration contract

Single source of truth for decisions that cross track boundaries. Update this
via PR as things get confirmed - don't let answers live only in chat.

## Environment variables

| Variable | Owner | Value / notes |
|---|---|---|
| `GEMINI_API_KEY` | AI | Gemini API key. Never commit a real value. |
| `GEMINI_MODEL` | AI | gemini-3.6-flash (confirmed - AI repo default since day one) |
| `DATABASE_URL` | DevOps | Set automatically by docker-compose from `POSTGRES_*` vars |
| `BACKEND_PORT` / `FRONTEND_PORT` / `AI_PORT` | DevOps | Default 8000 / 3000 / 8001 |
| `INTERNAL_SERVICE_TOKEN` | Backend | Shared secret for Data Eng -> Backend internal file-access calls. Implemented and tested by Backend. |

## GET /api/v1/documents/{id} response fields

**Status: confirmed**

Confirmed field names (Backend, via Petros):
- Advisor display name: `advisorName` (camelCase, sourced from User.full_name).
  NOT `advisor_name`, `advisor.full_name`, `advisor.name`, or `submitted_by`.
- File retrieval: no direct `file_url` field. Do NOT use `GET /api/v1/documents/{id}/file`
  for frontend view/download - that's internal-only (INTERNAL_SERVICE_TOKEN, not user JWT).
  See the dedicated section below for the correct user-facing endpoint (pending from Backend).

## GET /api/v1/documents/{id}/file - internal only, NOT for frontend

**Status: clarified**

This endpoint is intentionally internal service-to-service only, for Data
Engineering's file retrieval. Auth: `INTERNAL_SERVICE_TOKEN` only - does NOT
accept a regular user's JWT (confirmed: returns 401 for user tokens).

Frontend must NOT call this endpoint directly for view/download. Backend
(Petros) will provide a separate user-facing endpoint for advisor/officer
document view/download, authenticated with the normal user JWT and enforcing
document-level authorization (users can only access documents they're
permitted to view).

TODO: Backend to share the exact path/contract for the new user-facing
endpoint. Frontend's DocumentViewer/download code currently calls the
internal /file endpoint incorrectly and needs to be updated once the new
endpoint exists.

## User role string values

**Status: confirmed via live login response**

The backend's actual role values (as returned by POST /api/v1/auth/login and
used throughout the JWT/session) are:

- Advisor: `ADVISOR`
- Officer: `COMPLIANCE_OFFICER` (not `OFFICER` - this caused a real bug where
  the frontend compared against `"OFFICER"` and never matched, silently
  bouncing officers back to the login page. Fixed on the frontend to compare
  against `COMPLIANCE_OFFICER` instead.)

Anyone comparing `user.role` directly (frontend, or any other service) should
use these exact values, not assumed/shortened versions.

## Data Engineering DB connection - hardcoded localhost

**Status: resolved**

Fixed by Data Engineering - now reads from DATABASE_URL env var instead of
hardcoding localhost, matching the rest of the stack. Also added
seed_document_chunks.py for generic sample data.

## AI analysis endpoint + service networking

**Status: confirmed, tested live end-to-end**

AI analysis endpoint: `POST /ai/analyze/{document_id}` - no Authorization/
Bearer header required.

Docker-compose networking: Backend -> AI should use `http://ai:8001`
(service name resolution within the compose network), not localhost.

AI -> Data Engineering connection controlled by env vars:
`DATA_ENGINEERING_BASE_URL` and `USE_DATA_ENGINEERING_SERVICE=true`.

Live test confirmed by Naga: AI successfully called Data Engineering's
`/rule-lookup`, `/disclosure-check`, and `/precedent-search` (3 rules, 25
disclosures, 3 precedents retrieved), followed by a successful Gemini call
and 200 OK from `/ai/analyze/{document_id}`. Full AI -> Data Eng -> Gemini
pipeline confirmed working locally.

Note: AI service is local/docker-compose only for this submission, not part
of the Railway deployment (see Production deployment section) - live AI
analysis on the public site is out of scope for the current deployment
target, but is fully functional in the local docker-compose setup, which
is what the spec actually grades.

## API path prefix

**Status: decided (final - per supervisor direction)**

Standardized on `/api/v1` prefix, for versioning (allows a future `/api/v2`
without breaking existing clients):
- `/api/v1/auth/...`
- `/api/v1/documents/...`

Backend: updated its endpoint to `/api/v1/documents/{document_id}/file`.
Data Engineering: update calls to match. Frontend: matches what was already
assumed, just add `/v1`.

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

**Status: live**

Per supervisor direction: Frontend deployed on Vercel, not via docker-compose.
Backend deployed on Railway (Postgres/pgvector + backend service, same
private network, built from Backend/ subfolder's Dockerfile).

Frontend's `NEXT_PUBLIC_API_URL` points at the Railway backend's public URL.
CORS configured on backend to allow the Vercel domain.

AI service: staying local/docker-compose only for now, not part of this
deployment - production flow does not require live AI analysis yet.

## Dockerfiles / deployment (needed for each service to run)

**Status: done**

| Repo | Deployment method | Notes |
|---|---|---|
| Backend (compliance-document-review-app) | Railway (Docker) | Dockerfile lives in the Backend/ subfolder |
| AI (compliance-document-review-ai) | Docker (docker-compose) | FastAPI/Uvicorn, port 8001, matches AI_PORT default |
| Frontend (compliance-document-review-frontend) | Vercel | Per supervisor direction - not run via docker-compose |
| Data Engineering | N/A | Not run as its own compose service currently |

## Precedent retrieval - single source of truth

**Status: resolved**

Confirmed by Sushma (Data Eng) and Naga (AI): AI's local `vector_store.json`
is test-only. For the integrated system, AI consumes Data Engineering's
retrieval API as the single production source of truth for rules,
disclosures, and precedents.

## Document-text handoff (Backend -> Data Engineering)

**Status: resolved**

Confirmed flow: Frontend -> Backend upload/storage -> Data Engineering
retrieves the original file via Backend endpoint -> extraction -> chunking ->
embeddings -> pgvector. Backend does not duplicate the extraction pipeline.

Endpoints (Backend):
- `POST /api/v1/documents/upload` - uploads file, stores it, creates document metadata
- `GET /api/v1/documents/{document_id}/file` - retrieves the original uploaded file by document_id, protected by INTERNAL_SERVICE_TOKEN

Auth: `INTERNAL_SERVICE_TOKEN` shared secret, checked by Backend via
`verify_internal_service_token`. Data Engineering sends this as a header
when calling the file endpoint.
