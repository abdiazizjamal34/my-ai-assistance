# Production deployment

The production stack runs the backend and PostgreSQL with Docker Compose.
PostgreSQL is private to the Compose network and its data is stored in the
`postgres_data` volume. Put an HTTPS reverse proxy in front of the backend's
loopback-bound port.

## Initial setup

1. Copy `.env.example` to `.env` on the server.
2. Replace every placeholder, especially `POSTGRES_PASSWORD`, `JWT_SECRET`,
   `DEFAULT_USER_ID`, `AI_API_KEY`, and `CORS_ORIGINS`.
3. Ensure the reverse proxy forwards requests to `127.0.0.1:4000`.

Do not commit `.env` or pass secrets in the Dockerfile.

## Deploy

From the repository root:

```sh
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml --profile migrate run --rm backend-migrate
docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml ps
```

Run the migration command before starting the new application version for each
release. The application container does not run schema changes on startup.

## Verify

```sh
curl http://127.0.0.1:4000/health
docker compose -f docker-compose.prod.yml logs --tail=100 backend
```

The health endpoint checks both the HTTP process and the database connection.
