# Local Development

## Prerequisites

Install Flutter, Dart, Node.js/npm, Docker Desktop, and Git.

## Environment

Copy `.env.example` to `.env`. The included values are development-only defaults. Never commit `.env` or production credentials.

## Run the stack

From the repository root:

```powershell
docker compose up --build
```

PostgreSQL is exposed on port 5432 and the API on port 4000. Docker waits for the PostgreSQL health check before starting the backend, then Prisma creates/updates the development schema.

## Run Flutter

```powershell
cd mobile
flutter pub get
flutter run
```

Voice is enabled by default. Use `flutter run --dart-define=VOICE_ENABLED=false` for a text-only session. The first voice implementation uses device speech recognition and text-to-speech; no voice provider secrets are required.

The app selects `http://10.0.2.2:4000` for Android emulators and `http://localhost:4000` for iOS simulators, desktop, and web. For a physical device or another host, use `flutter run --dart-define=API_BASE_URL=http://...`.

## Checks

```powershell
cd backend
npm install
npm run build
cd ..\mobile
flutter analyze
flutter test
```

Check the running API with `Invoke-RestMethod http://localhost:4000/health`.

Sprint 2 profile endpoints require a user context. Example:

```powershell
Invoke-RestMethod http://localhost:4000/api/profile -Headers @{ 'x-user-id' = '00000000-0000-4000-8000-000000000001' }
```

The Flutter client sends this value from `USER_ID`, which defaults to a development UUID and can be overridden with `--dart-define=USER_ID=<uuid>`.

Task and reminder API smoke checks:

```powershell
Invoke-RestMethod http://localhost:4000/api/tasks -Headers @{ 'x-user-id' = '00000000-0000-4000-8000-000000000001' }
Invoke-RestMethod http://localhost:4000/api/reminders -Headers @{ 'x-user-id' = '00000000-0000-4000-8000-000000000001' }

The AI chat endpoint uses the same user context:

```powershell
Invoke-RestMethod -Method Post http://localhost:4000/api/agent/chat `
	-Headers @{ 'x-user-id' = '00000000-0000-4000-8000-000000000001' } `
	-ContentType 'application/json' `
	-Body '{"message":"Create a task called Review deployment"}'
```

Set `AI_API_KEY` only in the ignored local `.env`. Never place it in Flutter configuration or `--dart-define` values.
```