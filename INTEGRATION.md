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

**Status: mismatch confirmed - owner: AI to finalize**

Data Engineering: `sentence-transformers`, 384 dimensions, matching the
`document_chunks.embedding vector(384)` column. Pipeline tested end-to-end,
12 rows verified.

AI: currently uses a deterministic local vector engine at 128 dimensions -
**not compatible** with the 384-dim schema above.

AI has proposed standardizing on Data Engineering's 384-dim model once the
exact model/API is confirmed.

TODO: Data Engineering to confirm the exact embedding model/API (not just
"sentence-transformers" - which specific model, e.g. all-MiniLM-L6-v2) so AI
can align.

## Retrieval API response shape

**Status: proposed by Data Engineering, open to adjustment**

Rule lookup:
```
{ rule_id: string, rule_text: string, similarity_score: float }
```

Disclosure-by-absence:
```
{ disclosure_id: string, disclosure_type: string, present: boolean, similarity_score: float, matched_chunk_id: string | null }
```

Precedent match:
```
{ document_id: string, chunk_id: string, similarity_score: float, chunk_text: string }
```

## Dockerfiles (needed for docker compose to build each service)

**Status: in progress**

| Repo | Has Dockerfile? | Notes |
|---|---|---|
| Backend (compliance-document-review-app) | Not yet | Flagged to Petros |
| AI (compliance-document-review-ai) | In progress | Nagaa adding one - FastAPI/Uvicorn, port 8001, matches AI_PORT default |
| Frontend | No repo yet | Blocked on frontend track sharing a repo |
| Data Engineering | N/A | Not run as its own compose service currently |

## Document-text handoff (Backend -> Data Engineering)

**Status: flow agreed, contract details pending - owner: Backend**

Agreed flow: Frontend -> Backend upload/storage -> Data Engineering retrieves
the stored file -> Data Engineering runs extraction -> chunking -> embeddings
-> pgvector.

Backend stores uploaded files and will expose a way for Data Engineering to
access them (not pre-extracted text - Data Engineering continues to own
PDF/DOCX/XLSX extraction, so it isn't duplicated in Backend). AI does not need
direct file access.

TODO: Backend to share the file-storage/access contract (how Data Engineering
retrieves a given file - endpoint, storage path, etc).
