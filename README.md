# Personal AI Chief of Staff

Personal AI Chief of Staff is a cross-platform personal AI foundation. The long-term vision is an assistant that understands, remembers, plans, advises, and helps execute personal and professional work.

## Current Sprint

Sprint 1 establishes the project foundation: Flutter mobile client, Node.js REST API, Prisma, and PostgreSQL running locally through Docker.

## Architecture

```text
Flutter
	|
	v
REST API
	|
	v
Node.js + TypeScript
	|
	v
Prisma
	|
	v
PostgreSQL
```

The backend owns business logic. Flutter is an API client, and future AI and external integration modules will remain behind the backend boundary.

## Requirements

- Flutter 3.35 or newer
- Dart 3.9 or newer
- Node.js 22 or newer
- npm
- Docker Desktop with Docker Compose
- Git

## Installation

1. Clone the repository and enter it:

	```powershell
	git clone <repository-url>
	cd my-ai-assistance
	```

2. Create local environment configuration:

	```powershell
	Copy-Item .env.example .env
	```

3. Start PostgreSQL and the backend:

	```powershell
	docker compose up --build
	```

	The API is available at `http://localhost:4000`.

4. Start Flutter in another terminal:

	```powershell
	cd mobile
	flutter pub get
	flutter run
	```

	Flutter selects `http://10.0.2.2:4000` for Android emulators and `http://localhost:4000` for iOS, desktop, and web. Override the URL with `--dart-define=API_BASE_URL=http://...` when using a physical device or another host.

5. Test the health endpoint:

	```powershell
	Invoke-RestMethod http://localhost:4000/health
	```

	A healthy response is `{ "status": "ok", "service": "personal-ai-backend", "database": "ok" }`.

## Local Backend Without Docker

Start PostgreSQL with `docker compose up postgres -d`, then install and run the API:

```powershell
cd backend
npm install
npm run prisma:generate
npm run prisma:push
npm run dev
```

## Project Layout

```text
backend/          TypeScript API, Prisma schema, and health route
mobile/           Flutter application
infrastructure/   Docker-related supporting files
docs/             Architecture and local development documentation
```

## Scope

AI agents, LLM providers, voice, memory, tasks, reminders, notifications, and third-party integrations are intentionally out of scope for Sprint 1.

## Sprint 2 Personal Profile API

Sprint 2 adds profile, preferences, assistant settings, and goals. These endpoints require the temporary development user header until authentication is introduced:

```text
x-user-id: <user UUID>
```

Available endpoints:

```text
GET/PUT /api/profile
GET/PUT /api/preferences
GET/PUT /api/assistant-profile
GET/POST /api/goals
GET/PUT/DELETE /api/goals/:id
```

The Flutter client sends the configurable `USER_ID` value automatically. Override it with `--dart-define=USER_ID=<uuid>` when needed.

## Sprint 3 Tasks and Reminders

Task endpoints:

```text
GET    /api/tasks
POST   /api/tasks
GET    /api/tasks/:id
PUT    /api/tasks/:id
PATCH  /api/tasks/:id/status
DELETE /api/tasks/:id
```

Supported task filters include `status`, `priority`, `date=today`, `date=upcoming`, `date=overdue`, and `completed=true`.

Reminder endpoints:

```text
GET    /api/reminders
POST   /api/reminders
GET    /api/reminders/:id
PUT    /api/reminders/:id
PATCH  /api/reminders/:id/status
DELETE /api/reminders/:id
```

Example task request:

```powershell
Invoke-RestMethod -Method Post http://localhost:4000/api/tasks `
	-Headers @{ 'x-user-id' = '00000000-0000-4000-8000-000000000001' } `
	-ContentType 'application/json' `
	-Body '{"title":"Review plan","priority":"HIGH","dueDate":"2026-10-08T08:00:00Z"}'
```

Dates are stored as UTC timestamps. Today, upcoming, and overdue boundaries use the user's configured timezone, defaulting to `Africa/Nairobi`.

## Sprint 4 AI Agent

The backend exposes:

```text
POST /api/agent/chat
```

Example:

```powershell
Invoke-RestMethod -Method Post http://localhost:4000/api/agent/chat `
	-Headers @{ 'x-user-id' = '00000000-0000-4000-8000-000000000001' } `
	-ContentType 'application/json' `
	-Body '{"message":"What do I need to do today?"}'
```

The agent uses a controlled tool registry. It can access profile, preferences, assistant settings, goals, tasks, and reminders only through existing domain services. It never receives direct Prisma access. Configure `AI_API_KEY`, `AI_MODEL`, and `AI_BASE_URL` in the local `.env` to use an OpenAI-compatible provider; when no key is configured, a deterministic local provider supports basic development flows without network calls.