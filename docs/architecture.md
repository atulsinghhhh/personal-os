# Personal OS — Architecture

Phase 1 (MVP core loop). Flutter app + Supabase backend, offline-first.

## The core product relationship

Everything in the app hangs off one chain:

```
Vision ← Life Area
  ↑
Goal ← GoalMetric, Milestone
  ↑
Project
  ↑
Task ← TaskDependency
  ↑                          ↑
FocusSession (time)      Transaction (money, via project_id/goal_id)
```

Time invested is computed from `focus_sessions` (never stored redundantly,
except a display cache in `tasks.actual_minutes`); money invested is
computed from `transactions` linked to a project/goal, always grouped by
currency (amounts in different currencies are never summed). The
`BreadcrumbChain` widget (lib/shared/widgets/breadcrumb_chain.dart) renders
this chain + investments on Task/Project/Goal detail and in Focus mode.

## Layers

```
presentation/  screens + Riverpod providers (watch streams, call repos)
domain/        freezed entities + abstract repositories (no IO knowledge)
data/          Drift-backed repository impls (reads = reactive queries,
               writes = dirty-flag + outbox, soft deletes)
core/sync/     the sync engine (below)
data/local/    Drift schema — the UI's single source of truth
supabase/      SQL migrations (schema + RLS), applied via supabase CLI
```

The UI never talks to Supabase directly (the auth controller is the one
exception, by design). Every read is a Drift `.watch()` stream; every write
is instant and local.

## Offline-first sync

Local outbox pattern, hand-rolled (no CRDTs — single-user app):

- **Write path**: repository writes run one Drift transaction that
  (1) upserts the entity row with `is_dirty = true` and (2) enqueues a
  wire-format JSON snapshot in `sync_outbox`. A crash can never separate
  the two. Re-editing an entity with a pending outbox row supersedes that
  row IN PLACE (same queue position, insert-op preserved) — appending
  instead would push children before their re-edited parent and violate
  server foreign keys.
- **Push**: FIFO drain. Ordinary tables are blind `upsert`s (last-write-
  wins by client `updated_at`). `transactions` updates are conditional
  (`WHERE id = ? AND server_updated_at = ?`); zero rows affected = the
  server moved = a conflict, never an overwrite. Transient failures retry
  with exponential backoff; permanent (4xx) failures park as `failed`.
- **Pull**: per-table watermarks on `updated_at` with a 5-minute overlap
  window (client clocks aren't monotonic; upserts are idempotent). Server
  rows never blindly overwrite dirty local rows: LWW tables compare edit
  times; dirty transactions are always left for push-time detection.
- **Transaction conflicts**: both versions land in a local
  `conflict_queue` + a server-side `sync_conflicts` audit row; the row is
  flagged `pending_review`; the UI surfaces a persistent banner and offers
  keep-mine / keep-server / merge. Nothing about money is ever resolved
  silently.

`server_updated_at` is stamped by a Postgres trigger and can never be set
by the client. Profiles sync as a special case (keyed by auth user id,
created server-side by the `handle_new_user` trigger).

## Security

- RLS on every table, the same four-policy pattern scoped to
  `user_id = auth.uid()` (see supabase/migrations/0008_rls_policies.sql).
- Publishable key only in the client (via `--dart-define-from-file`,
  gitignored); no service keys, no bank credentials, nothing logged.

## Multi-currency

Currency is stored explicitly on every financial record (`Money` value
object in the domain). The profile's `default_currency` (chosen at
onboarding) only pre-fills new records. No exchange rates anywhere —
conversion is a future provider abstraction and is never fabricated.

## Tests

- `test/data/local/database_test.dart` — Drift schema smoke test.
- `test/core/sync/sync_engine_integration_test.dart` — push/pull/conflict
  against the real local Supabase stack (requires `supabase start`).
- `test/core_loop_test.dart` — the Phase 1 acceptance test: the entire
  vision→goal→project→task→focus→expense loop with rollups, sync, and
  cold-start reconstruction on a second device.

## Phase 2+ (not built, schema-ready)

AI planning/financial analysis (Groq via a Supabase Edge Function — key
stays server-side), trajectory engine, bills/subscriptions/debt, net
worth, deeper analytics, calendar sync, push notifications, search,
export/backup. The Phase 1 schema (per-record currency, conflict columns,
`financial_goals.goal_type`, `sync_conflicts`) was designed so none of
these require destructive migrations.
