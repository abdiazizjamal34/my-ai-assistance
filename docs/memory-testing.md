# Memory Testing

Backend tests run with the deterministic provider and a local PostgreSQL database:

```powershell
cd backend
npm run prisma:generate
npm test
```

Sprint 6 coverage includes:

- Relevant ranking and score filtering
- Expiration and active-status filtering
- Irrelevant memory exclusion
- Access count and last-access tracking
- Bounded data-only context formatting
- Sensitive candidate rejection
- Stable and uncertain candidate decisions
- Duplicate and preference conflict resolution
- Agent context injection and memory-used reporting
- Confirmation candidates without automatic storage

Flutter checks:

```powershell
cd mobile
flutter analyze
flutter test
```

The development provider is deterministic; no real AI API calls are required by automated tests.
