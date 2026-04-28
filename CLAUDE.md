# RecompDaily — project conventions

Read this before touching code. Short on purpose; details live in
STRATEGY_PIVOT.txt (strategy) and the code itself (how).

---

## Product

- **Name**: RecompDaily (was CutBro — renamed, don't go back)
- **Tagline**: "Your daily recomp coach" / 中文 "你的每日身体重塑教练"
- **Audience**: men who lift, recomp-focused (fat loss + muscle retention /
  lean gain). 20-35 primary, 30-45 secondary.
- **Market**: **overseas first** (English primary), China secondary. Solo dev.
- **Pricing target**: $9.99/mo or $59/yr. Day-1 paywall eventually — AI features
  pay-gated, manual logging free.

Full market/pivot rationale: see `STRATEGY_PIVOT.txt` at repo root — working
doc, don't modify unless asked.
iOS submission plan: `APPSTORE_CHECKLIST.md`.

---

## Platforms

- **Web (primary, shipped)**: Flutter web + Go backend. This is where we test
  and ship. Static assets served by `tests/static_server.js` on :8888 for E2E,
  or `flutter run -d web-server` locally.
- **iOS / Android**: code compiles but not actively tested. iOS/Android
  Google OAuth clients are NOT set up yet. Don't claim mobile is "working".

---

## Hard tech contracts (both sides must stay in sync)

| Thing | Where | Keep in sync |
|-------|-------|--------------|
| Macro target formula | `backend/internal/services/ai_service.go:deriveMacroTargetsBackend` + `frontend/lib/utils/macros.dart:deriveMacroTargets` | both compute `protein = w*1.8, fat = w*0.8, carbs = (cal - 4p - 9f)/4` |
| Locale → language name | `ai_service.go:languageName` | client sends locale code in every AI request; backend resolves to English language name for prompts |
| JWT format | `backend/internal/auth/token.go:TokenIssuer` | HS256, `cfg.SecretKey`, claims `{uid, iat, exp}`, TTL `cfg.JWTExpireDays` days |
| `UserAccount` identifiers | `models/auth.go` | `Phone / Email / GoogleSub` all `*string` uniqueIndex nullable. At least one must be set for an account to exist. |
| Default thread title | `"New chat"` | `ai_service.go:maybeAutoTitleThread` treats `""`, `"New chat"`, or legacy `"新对话"` as auto-title triggers |
| Daily-boundary timezone | `backend/internal/services/timezone.go` (`ResolveLocation` + `StartOfDay`) + every daily/range endpoint + `frontend/lib/utils/timezone.dart` | client sends IANA `tz` (e.g. `Asia/Shanghai`) on `/v1/{food,exercise}/daily-summary`, `/v1/{food,exercise,weight}/records` (query), `/v1/ai/{daily-brief,chat,chat/stream}` (body). Backend computes `StartOfDay(t, ResolveLocation(tz))`. Empty/unknown tz → UTC. Range query `endDate` semantics is half-open (`<`); handler bumps inclusive client `end_date` to next-day midnight in client tz. |

---

## UI conventions

- **Dark-mode variants only** (for now). Two user-selectable palettes, both
  `Brightness.dark`: `dark` (AMOLED black `#000000 / #0E0E10 / #1A1A1D`) and
  `medium` / "graphite" (softer `#1A1A1C / #26262A / #32323A`). Picker lives
  in Settings → Appearance. No true light theme — text is always light on
  dark surfaces. Brand color `#E53935` (accent red) across both variants.
  Palettes live in `lib/main.dart`; preference persisted via `ThemeProvider`
  under prefs key `app.theme`.
- **No emoji** in UI copy, AI output, logs the user might see, or commit
  messages. The AI system prompt explicitly says "no emoji".
- **i18n via `flutter_localizations`** (`lib/l10n/app_en.arb` + `app_zh.arb`).
  English is the template (metadata lives there). Add new strings to BOTH
  files + `flutter gen-l10n`.
- **Typography pitfall**: every `TextStyle(...)` must set `color:`
  explicitly. `textTheme.apply(bodyColor: X).copyWith(bodyLarge: TextStyle(...))`
  **loses the color** — `copyWith` is whole-style replacement. See `main.dart`
  for the right pattern.
- **Units**: metric everywhere (kg, kcal, g, km). No imperial even as an option.
- **Text style**: data-driven, terse, no pep-talk, no "you got this". The
  AI system prompt enforces this for AI output; we hold ourselves to the same.

---

## Login & auth

- **Web login**: Google only, via `google_sign_in` 7.x + `google_sign_in_web`.
  On web, use the GIS-rendered button (`renderButton()` from
  `web_only.dart`) — GIS refuses to issue ID tokens from a button we draw
  ourselves. `GoogleSignIn.instance.authenticate()` **throws `UnimplementedError`
  on web** by design.
- **Mobile login (future)**: same Dart API, `authenticate()` works there.
  Requires platform-specific OAuth clients (not set up).
- **SMS login**: backend endpoints (`/v1/auth/sms/*`) are kept for E2E + dev
  convenience, but **no UI** on the frontend login screen.
- **Test user** (for E2E + local curl): phone `13800138000`, code `123456`,
  with `SKIP_SMS_VERIFY=true` env var set on backend.
- **Token**: real JWT (HS256). Old `token_<uid>_<ts>` format is dead;
  `middleware.AuthRequired(tokens)` uses `tokens.Verify`.

---

## AI prompt conventions

- Every AI-facing endpoint (`/v1/ai/chat`, `/v1/ai/chat/stream`, `/v1/ai/brief`,
  `/v1/ai/recognize`, `/v1/ai/estimate/*`, `/v1/ai/parse-weight`,
  `/v1/ai/encouragement`) accepts an optional `locale` field. Frontend
  pulls it from `LocaleProvider` via `effectiveAiLocale(context)`.
- `languageName(locale)` gets interpolated into prompts as
  `"Reply in {language}"`. Unknown locale → "English".
- System prompt establishes: "You are RecompDaily, a direct, data-driven
  AI recomp coach for men who lift. Skip fluff, skip pep-talk, skip emoji."
  When editing prompts, preserve this tone.
- Facts extraction and thread summarization use the **conversation's own
  language** (not the request's locale) so memory feels natural.
- Background tasks (embedding, summarization, fact extraction) run async,
  errors only log — never block user-facing latency.

---

## External dependencies (human controls, not in code)

These can't be created programmatically. Keep them current or things break
silently.

1. **Google Cloud Console** (project id `604310975641`):
   - OAuth 2.0 Web Client ID: baked into `backend/config.yaml:google_client_id`
     and `frontend/lib/config/auth_config.dart`. Hardcoded because it's
     public by design.
   - Authorized JavaScript origins must include `http://localhost:8888`
     and any prod domain.
   - **People API must be enabled** in the project (legacy google_sign_in
     quirk — even v7 may hit it in certain flows).
2. **Gemini API key** (`GEMINI_API_KEY` env var or `config.gemini.yaml`).
   `config.gemini.yaml` is gitignored.
3. **Domains to register** (not yet done): `recompdaily.app`, `recompdaily.com`.
4. **Stripe + RevenueCat** (not integrated yet). When integrated, document
   env vars and webhook endpoints here.

---

## Dev workflow

- **Start stack**: user decides between `make local` and `make local-gemini`
  for the backend. Never pick one on their behalf.
- **Backend changes need a restart** — Go is not hot-reload. After any `.go`
  change, the user must kill + restart before E2E / curl hits new code.
- **Migrations**: `database.Migrate` runs on boot. AutoMigrate adds columns
  but does NOT drop `NOT NULL` constraints — for constraint relaxations
  see the manual `ALTER TABLE` pattern in `database.go`
  (e.g. `user_accounts.phone` was relaxed there).
- **L10n generation**: always `flutter gen-l10n` after editing ARB files.
  Generated files in `lib/l10n/generated/` are committed (so CI doesn't
  need to regen).
- **E2E**: `cd frontend && ./run_e2e_tests.sh` — 26 tests, ~30s against
  new backend. Uses `waitUntil: 'domcontentloaded'` (NOT `networkidle` —
  the GIS script from `accounts.google.com` keeps network non-idle).

---

## Ship flow (when user says "ship")

1. `git status` — if clean, stop and tell user.
2. `ss -tlnp | grep 8000` — if backend down, stop and ask user to start
   (`make local` vs `make local-gemini` — let them choose).
3. If backend restart happened recently (or my changes modify backend
   code / schema), verify new backend with a quick curl sanity check
   before E2E.
4. Run E2E. Any failure → stop, show the case, don't commit.
5. Green → commit. Conventions:
   - Chinese commit message, `feat(scope):` / `fix(scope):` / `chore(scope):` prefix.
   - `git add <specific files>` only — never `git add -A`.
   - HEREDOC for the message body.
   - Footer `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.
   - Never `--no-verify`, never `--amend`.
6. `git push`, print the sha range.

---

## Anti-patterns (don't do this without asking)

- Don't change the Flutter package name `loss_weight` (pubspec.yaml) or the
  Go module path `github.com/your-org/loss-weight/backend` (go.mod). Rename
  cascades everywhere and is not worth it — users don't see these strings.
- Don't rename the GitHub repo from `loss-weight` automatically.
- Don't add features beyond the current ask. The STRATEGY_PIVOT.txt
  explicitly warns against engineer's完美主义 rabbit holes.
- Don't add free-tier AI usage without a quota — Gemini vision calls run
  ~$0.03 / photo and a heavy free user can cost $1+/day.
- Don't reintroduce a true light theme (light text on dark is a hard
  constraint — `medium` variant is still Brightness.dark), emoji in
  prompts, pep-talk tone, or imperial units.
- Don't modify `STRATEGY_PIVOT.txt` — it's the human's working doc,
  updated only when they ask.
- Don't `flutter build web` just to test syntax — use `flutter analyze`,
  it's 100x faster.

---

## Known pitfalls (save yourself debugging time)

- **`textTheme.apply(...).copyWith(...)` loses colors** — see UI
  conventions above. Fixed once, will come back if someone isn't
  careful.
- **`google_sign_in` 6.x on web doesn't return ID tokens**. We're on 7.x
  and use the rendered button. Don't "simplify" back to 6.x.
- **Flutter web plugin registrant can go stale** after pubspec changes.
  If a plugin seems missing at runtime despite `flutter pub get`,
  `flutter clean && flutter pub get && flutter build web`.
- **E2E timing**: the `networkidle` waitUntil with the GIS script loaded
  will hang for 2-5s per test (~20-50s per run). We use
  `domcontentloaded` + explicit `toBeVisible()` waits.
- **User history biases AI language**: if a user's thread history is
  heavily Chinese, Gemini will answer in Chinese even with
  "Reply in English" in the system prompt. New threads pick up the
  locale setting immediately; old threads take a few messages to shift.
- **Schema non-null relaxations don't AutoMigrate** — manual ALTER TABLE
  in `database.go`, pattern already exists for the `phone` column.
