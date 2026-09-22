# Personal OS

A mobile Personal Operating System: plan your life backward from the future
you want. One coherent system connecting

**Future → Goals → Money → Time → Projects → Tasks → Daily execution → Reviews.**

- **Frontend**: Flutter (Riverpod, go_router, Drift, Material 3)
- **Backend**: Supabase (Postgres + Auth + RLS), local dev via Supabase CLI
- **Offline-first**: every read/write hits the local Drift database; a sync
  engine reconciles with Supabase via an outbox (money edits are never
  silently overwritten — conflicts are surfaced for manual resolution)

See [docs/architecture.md](docs/architecture.md) for the full design.

## Getting started

Prerequisites: Flutter (stable), Supabase CLI, Docker.

```bash
# 1. Start the local backend (Postgres/Auth/Studio in Docker)
supabase start

# 2. Apply the schema + RLS policies
supabase db reset

# 3. Configure the app's env (copy the template, paste the values
#    `supabase start` printed — publishable key + API URL)
cp app/env/local.example.json app/env/local.json

# 4. Run the app (Android emulators need 10.0.2.2 instead of 127.0.0.1
#    as the SUPABASE_URL host — keep a separate env/local.android.json)
cd app
flutter pub get
flutter run --dart-define-from-file=env/local.json
```

## Tests

```bash
cd app
flutter analyze
flutter test                       # includes integration tests that
                                   # require `supabase start` to be running
flutter test test/core_loop_test.dart   # the Phase 1 acceptance test
```

## Project layout

```
app/        Flutter application (presentation / domain / data / core)
supabase/   SQL migrations (schema + RLS), local dev config
docs/       architecture notes
```

## Phase 1 scope

Auth, onboarding, Today command center, Future hierarchy (life areas →
visions → goals → milestones → projects → tasks) with time/money-invested
rollups, focus mode, day/week/month/year planning, money (accounts,
transactions, budgets, savings & financial goals) with conflict-safe sync,
reviews, settings + sync diagnostics.

Deferred to Phase 2+: AI planning (Groq via Edge Function), trajectory
engine, bills/subscriptions/debt, net worth, analytics, calendar sync,
notifications, search, export/backup.
