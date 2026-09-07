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
| `INTERNAL_SERVICE_TOKEN` | DevOps (proposed) | Shared secret for Data Eng -> Backend internal file-access calls. Not finalized. |

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

## Dockerfiles (needed for docker compose to build each service)

**Status: in progress**

| Repo | Has Dockerfile? | Notes |
|---|---|---|
| Backend (compliance-document-review-app) | Not yet | Flagged to Petros |
| AI (compliance-document-review-ai) | Done | FastAPI/Uvicorn, port 8001, matches AI_PORT default |
| Frontend | No repo yet | Blocked on frontend track sharing a repo |
| Data Engineering | N/A | Not run as its own compose service currently |

## Precedent retrieval - single source of truth

**Status: confirmed mismatch - owner: AI + Data Engineering to resolve**

Verified by running AI's container directly: on startup it logs
`Loaded vector store from /app/ai/data/vector_store.json (rules=34,
disclosures=25, precedents=100)`. This is a local, self-contained JSON file
bundled with the AI service - not a query against the shared Postgres +
pgvector instance that Data Engineering populated (12 rows verified there via
the sentence-transformers pipeline).

This means AI is currently running its own separate retrieval path with its
own separate data, not consuming Data Engineering's retrieval jobs. Two
sources of truth exist right now for rules/disclosures/precedents.

TODO: AI and Data Engineering to agree on how AI switches from its local
vector_store.json to querying Data Engineering's retrieval API/pgvector
instance instead.

## Document-text handoff (Backend -> Data Engineering)

**Status: endpoints implemented, service-to-service auth pending - owner: Backend + DevOps**

Confirmed flow: Frontend -> Backend upload/storage -> Data Engineering
retrieves the original file via Backend endpoint -> extraction -> chunking ->
embeddings -> pgvector. Backend does not duplicate the extraction pipeline.

Implemented endpoints (Backend):
- `POST /documents/upload` - uploads file, stores it, creates document metadata
- `GET /documents/{document_id}/file` - retrieves the original uploaded file by document_id

Backend owns file storage and document metadata. Data Engineering continues
to own PDF/DOCX/XLSX extraction, chunking, embeddings, and vector storage.
Upload -> db record -> retrieval flow tested successfully by Backend.

TODO: service-to-service auth mechanism for Data Engineering calling the
Backend file endpoint. Proposed by DevOps: a shared internal token (e.g.
`INTERNAL_SERVICE_TOKEN` env var, sent as a header) checked by Backend on
internal endpoints - simplest option for the current scope, doesn't require
running a full auth flow between services on the same docker network. Open
for Backend/Data Eng to weigh in before finalizing.
