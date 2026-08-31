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

**Status: open - owner: AI + Data Engineering**

TODO: confirm which embedding model/API both sides will use so masked-text
embeddings (Data Engineering) and any AI-side embedding calls stay consistent.

## Retrieval API response shape

**Status: open - owner: Data Engineering**

TODO: define the response shape for the three retrieval jobs (rule lookup,
disclosure-by-absence, precedent match) that AI will consume.

## Document-text handoff (Backend -> AI / Data Engineering)

**Status: open - owner: Backend**

TODO: confirm how Backend exposes extracted document text to the AI/Data
Engineering pipeline. AI only needs the extracted clean text for masking and
analysis - direct access to uploaded files is not required.
