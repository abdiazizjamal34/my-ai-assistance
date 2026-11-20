# Conversational Memory Architecture

Sprint 6 keeps memory behind the existing agent boundary:

```text
AgentService
  -> ToolRegistry.getContext
  -> MemoryRetrievalService
  -> memory-ranking.service
  -> memory-context.service
  -> AIProvider
```

`MemoryRetrievalService` filters by `userId`, active status, and `expiresAt`, then ranks candidates using semantic token overlap, importance, confidence, recency, access history, and category priority. Selected memories increment `accessCount` and update `lastAccessedAt` in one transaction.

`buildMemoryContext` removes low-confidence entries and enforces configured item and approximate token limits. It formats memory as explicitly labeled user data. Memory text is never treated as system or developer instructions.

After a response, `memory-detection.service` evaluates stable preferences, projects, and goals. Stable high-confidence candidates are saved through `ToolRegistry`; uncertain candidates are returned to the client for confirmation. Similar memories update existing records, and opposite light/dark preferences supersede the prior preference.

Memory retrieval failures are logged with user ID, query length, and error metadata, then conversation generation continues without memory context.

## Configuration

- `MEMORY_ENABLED`
- `MEMORY_RETRIEVAL_ENABLED`
- `MEMORY_MAX_ITEMS` (default `8`)
- `MEMORY_MIN_SCORE` (default `0.65`)
- `MEMORY_MAX_CONTEXT_TOKENS` (default `1500`)
- `MEMORY_AUTO_SAVE_ENABLED`
- `MEMORY_CONFIRMATION_ENABLED`
