# Frontend · Flutter

RecompDaily frontend. Flutter 3.38, web-primary. iOS / Android compile but
aren't actively tested.

## Start

```bash
flutter pub get

# Dev server (hot reload)
flutter run -d web-server --web-port 8888

# Release build (~25s)
flutter build web --no-tree-shake-icons
# then serve build/web/ with any static server on :8888
```

Backend must be up at `http://localhost:8000/v1`. `ApiService` auto-detects
via `window.location.host` in dev; override with `ApiService().setBaseUrl(...)`.

## Layout

- `lib/main.dart` — app entry, theme, MaterialApp, Provider wiring.
- `lib/screens/` — one file per route (home, records, ai, profile, settings, login).
- `lib/widgets/` — reusable UI (macro dashboard, google sign-in button, voice input).
- `lib/providers/` — ChangeNotifier state (auth, user, locale).
- `lib/services/` — HTTP clients (auth, food, weight, exercise, ai, user).
- `lib/models/` — DTOs with fromJson/toJson.
- `lib/utils/` — pure helpers (macro formula, label mapping).
- `lib/config/` — public identifiers (Google OAuth client ID).
- `lib/l10n/` — ARB files + generated `AppLocalizations`. Run `flutter gen-l10n`
  after editing.

## i18n

Add new strings to BOTH `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`, then
`flutter gen-l10n`. Generated files are committed so CI doesn't need to regen.

## Tests

```bash
./run_e2e_tests.sh           # 26 Playwright tests, ~30s
./run_e2e_tests.sh --build   # force rebuild first
```

## Conventions

See repo-root `CLAUDE.md` for UI / auth / AI / ship-flow rules.
