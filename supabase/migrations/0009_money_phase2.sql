-- Phase 2 money entities: bills, subscriptions, debts, manual assets, and
-- net worth snapshots. Same conventions as Phase 1: client-generated uuid
-- ids, client-managed updated_at (LWW), soft-delete tombstones, RLS scoped
-- to the owning user.

create table public.bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  amount numeric(18, 4) not null check (amount >= 0),
  currency text not null,
  due_date date not null,
  -- none = one-off; otherwise the app rolls due_date forward on payment.
  recurrence text not null default 'monthly'
    check (recurrence in ('none', 'weekly', 'monthly', 'yearly')),
  account_id uuid references public.financial_accounts (id) on delete set null,
  category_id uuid references public.transaction_categories (id) on delete set null,
  reminder_days_before integer,
  last_paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index bills_user_id_idx on public.bills (user_id) where deleted_at is null;
create index bills_due_date_idx on public.bills (user_id, due_date);
create index bills_user_updated_idx on public.bills (user_id, updated_at);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  service text not null,
  amount numeric(18, 4) not null check (amount >= 0),
  currency text not null,
  billing_cycle text not null default 'monthly'
    check (billing_cycle in ('weekly', 'monthly', 'yearly')),
  renewal_date date,
  category_id uuid references public.transaction_categories (id) on delete set null,
  account_id uuid references public.financial_accounts (id) on delete set null,
  cancellation_note text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index subscriptions_user_id_idx on public.subscriptions (user_id) where deleted_at is null;
create index subscriptions_user_updated_idx on public.subscriptions (user_id, updated_at);

create table public.debts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  principal numeric(18, 4) not null check (principal >= 0),
  current_balance numeric(18, 4) not null check (current_balance >= 0),
  currency text not null,
  -- Stored as an annual percentage the user entered; used only for
  -- transparent arithmetic, never for advice.
  interest_rate_percent numeric(7, 4),
  minimum_payment numeric(18, 4),
  payment_frequency text not null default 'monthly'
    check (payment_frequency in ('weekly', 'monthly', 'yearly')),
  due_date date,
  start_date date,
  target_payoff_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index debts_user_id_idx on public.debts (user_id) where deleted_at is null;
create index debts_user_updated_idx on public.debts (user_id, updated_at);

-- Manually tracked assets that aren't bank/investment accounts (vehicle,
-- property, valuables). Value is user-entered; the app never estimates it.
create table public.assets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  value numeric(18, 4) not null check (value >= 0),
  currency text not null,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index assets_user_id_idx on public.assets (user_id) where deleted_at is null;
create index assets_user_updated_idx on public.assets (user_id, updated_at);

-- Point-in-time net worth records, one per user per date, written by the
-- app (on demand and when the month rolls over). Amounts are stored per
-- currency as JSON: {"INR": {"assets": 1000, "liabilities": 200}, ...} —
-- currencies are never merged.
create table public.net_worth_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null,
  breakdown jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint net_worth_snapshots_user_date_unique unique (user_id, date)
);

create index net_worth_snapshots_user_id_idx on public.net_worth_snapshots (user_id) where deleted_at is null;
create index net_worth_snapshots_user_updated_idx on public.net_worth_snapshots (user_id, updated_at);

-- RLS: identical four-policy pattern.
alter table public.bills enable row level security;
create policy "bills_select_own" on public.bills for select using (user_id = auth.uid());
create policy "bills_insert_own" on public.bills for insert with check (user_id = auth.uid());
create policy "bills_update_own" on public.bills for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "bills_delete_own" on public.bills for delete using (user_id = auth.uid());

alter table public.subscriptions enable row level security;
create policy "subscriptions_select_own" on public.subscriptions for select using (user_id = auth.uid());
create policy "subscriptions_insert_own" on public.subscriptions for insert with check (user_id = auth.uid());
create policy "subscriptions_update_own" on public.subscriptions for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "subscriptions_delete_own" on public.subscriptions for delete using (user_id = auth.uid());

alter table public.debts enable row level security;
create policy "debts_select_own" on public.debts for select using (user_id = auth.uid());
create policy "debts_insert_own" on public.debts for insert with check (user_id = auth.uid());
create policy "debts_update_own" on public.debts for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "debts_delete_own" on public.debts for delete using (user_id = auth.uid());

alter table public.assets enable row level security;
create policy "assets_select_own" on public.assets for select using (user_id = auth.uid());
create policy "assets_insert_own" on public.assets for insert with check (user_id = auth.uid());
create policy "assets_update_own" on public.assets for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "assets_delete_own" on public.assets for delete using (user_id = auth.uid());

alter table public.net_worth_snapshots enable row level security;
create policy "net_worth_snapshots_select_own" on public.net_worth_snapshots for select using (user_id = auth.uid());
create policy "net_worth_snapshots_insert_own" on public.net_worth_snapshots for insert with check (user_id = auth.uid());
create policy "net_worth_snapshots_update_own" on public.net_worth_snapshots for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "net_worth_snapshots_delete_own" on public.net_worth_snapshots for delete using (user_id = auth.uid());
