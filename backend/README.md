# Backend · Go + Gin

RecompDaily backend. Go 1.23 + Gin + GORM + Postgres 16 (pgvector) +
Gemini 2.5-flash.

## Start

```bash
go mod download

# With Gemini (needs API key; add proxy first if your network requires it)
export GEMINI_API_KEY=<your-key>
make local-gemini      # uses config.gemini.yaml (gitignored)

# Without Gemini — AI endpoints return debug-mode mocks
make local             # uses config.test.yaml
```

Listens on `:8000`. Postgres DSN in `config.yaml` → defaults to
`localhost:5434/lossweight`.

## Layout

- `cmd/server/main.go` — entry point. Wires migrations, middleware, routes.
- `internal/auth/` — JWT issuance + verification.
- `internal/config/` — viper-driven config loader.
- `internal/database/` — DB connect + `Migrate()` (incl. manual `ALTER TABLE`s
  that AutoMigrate can't do).
- `internal/handlers/`, `internal/services/`, `internal/models/` — standard
  3-layer gin app. `ai_service.go` + `ai_memory.go` hold the LLM / RAG logic.
- `internal/middleware/` — CORS, logging, `AuthRequired`.
- `internal/routes/` — route group setup; called from main.

## Conventions

See repo-root `CLAUDE.md` for project-wide constraints (JWT claims, locale
parameter, macro formula, schema migration gotchas).
