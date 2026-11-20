# Architecture Overview

Sprint 1 uses a deliberately small boundary between the Flutter client and backend API:

```text
Flutter mobile app -> HTTP REST -> Express API -> Prisma -> PostgreSQL
```

Flutter owns presentation and network-client concerns. Business logic and future authorization, AI orchestration, controlled tools, and external integrations belong in the backend. The backend is organized so future modules can be added under `src/modules` without putting provider or database logic in the mobile application.

The `/health` route performs a database query, making it an end-to-end connectivity check rather than a process-only ping.

Sprint 2 adds user-owned profile, preferences, assistant profile, and goal modules. Until authentication exists, `x-user-id` or the optional `DEFAULT_USER_ID` environment variable supplies the request user context. Services enforce ownership and are the intended boundary for future AI tools.

Sprint 3 adds user-owned tasks and reminders. Tasks can reference a future project through nullable `projectId`; reminders optionally reference tasks and use `SetNull` behavior when a task is cancelled or removed. Date query services calculate local-day boundaries from the user's timezone before querying UTC database timestamps.

Sprint 4 adds the AI Agent Core. `AgentService` loads structured context, asks an `AIProvider` for an answer/tool calls, validates calls through `ToolRegistry`, delegates to domain services, and records `AgentAction` audit entries. The agent has no Prisma dependency and provider credentials remain backend-only.

Sprint 6 adds conversational memory intelligence. Before provider generation, `ToolRegistry` requests bounded, user-owned context through `MemoryRetrievalService`, explainable ranking, and `buildMemoryContext`. Expired, inactive, low-confidence, and irrelevant memories are excluded; selected memories update access tracking. After generation, conservative candidate detection either stores stable information through controlled tools or returns a confirmation candidate to Flutter. Memory is explicitly treated as untrusted data and cannot override system, developer, safety, or authorization rules. See `docs/memory-architecture.md` and `docs/memory-security.md`.