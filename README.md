# RecompDaily

AI recomp coach for men who lift. Flutter web (primary) + Go backend.

## Stack

| Layer | Choice |
|---|---|
| Frontend | Flutter 3.38 (Web / iOS / Android; Web is what we ship) |
| Backend | Go 1.23 + Gin + GORM + Postgres 16 + pgvector halfvec(3072) |
| AI | Gemini 2.5-flash (chat, vision, estimate) + gemini-embedding-001 (RAG) |
| Auth | Google Sign-In (web via GIS rendered button) + JWT (HS256) |
| i18n | flutter_localizations, English default + Simplified Chinese |

## Start

```bash
# Backend
cd backend
export GEMINI_API_KEY=<your-key>
make local-gemini    # with Gemini
# or
make local           # with mock AI (debug only)

# Frontend (web dev)
cd frontend
flutter pub get
flutter run -d web-server --web-port 8888
```

## Docs

- `CLAUDE.md` — project conventions, contracts, pitfalls. Read before editing.
- `STRATEGY_PIVOT.txt` — business / positioning working doc (untracked, lives
  at repo root).

## Tests

```bash
cd frontend && ./run_e2e_tests.sh      # ~30s, 26 cases against real backend
```

Backend must be running on `:8000` and rebuilt after any `.go` change.
