-- Money system: accounts, categories, transactions, budgets, savings goals,
-- financial goals. `transactions` is the one table with real multi-writer
-- conflict handling (see comment above its definition) — everything else
-- uses simple client-timestamp last-write-wins.

create table public.financial_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  type text not null check (type in ('cash', 'bank', 'savings', 'credit_card', 'wallet', 'investment', 'other')),
  currency text not null,
  opening_balance numeric(18, 4) not null default 0,
  institution_name text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index financial_accounts_user_id_idx on public.financial_accounts (user_id) where deleted_at is null;

create table public.transaction_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  kind text not null check (kind in ('expense', 'income')),
  parent_id uuid references public.transaction_categories (id) on delete set null,
  icon text,
  color text,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index transaction_categories_user_id_idx on public.transaction_categories (user_id) where deleted_at is null;
create index transaction_categories_parent_id_idx on public.transaction_categories (parent_id);

-- Transactions carry real optimistic-concurrency conflict detection because
-- silently overwriting a concurrent edit to money data is unacceptable (hard
-- product requirement). `server_updated_at` is stamped by the trigger below
-- on every write and can never be set by the client; the sync engine's push
-- path does `update ... where id = :id and server_updated_at = :base` and
-- treats a zero-row result as a conflict rather than retrying blindly.
-- `client_updated_at` is the user's actual local edit time (client-supplied,
-- used for display/audit, not for concurrency control).
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  account_id uuid not null references public.financial_accounts (id) on delete cascade,
  category_id uuid references public.transaction_categories (id) on delete set null,
  project_id uuid references public.projects (id) on delete set null,
  goal_id uuid references public.goals (id) on delete set null,
  kind text not null check (kind in ('expense', 'income', 'transfer')),
  amount numeric(18, 4) not null check (amount >= 0),
  currency text not null,
  occurred_at timestamptz not null,
  note text,
  client_updated_at timestamptz not null default now(),
  server_updated_at timestamptz not null default now(),
  conflict_state text not null default 'none' check (conflict_state in ('none', 'pending_review', 'resolved')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index transactions_user_id_idx on public.transactions (user_id) where deleted_at is null;
create index transactions_account_id_idx on public.transactions (account_id);
create index transactions_project_id_idx on public.transactions (project_id);
create index transactions_goal_id_idx on public.transactions (goal_id);
create index transactions_occurred_at_idx on public.transactions (user_id, occurred_at);
create index transactions_conflict_state_idx on public.transactions (user_id, conflict_state) where conflict_state <> 'none';

create function public.stamp_transaction_server_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.server_updated_at := now();
  return new;
end;
$$;

create trigger transactions_stamp_server_updated_at
  before insert or update on public.transactions
  for each row execute procedure public.stamp_transaction_server_updated_at();

-- Server-side audit trail of every detected transaction conflict, so a
-- resolution history survives even across reinstalls / multiple devices.
create table public.sync_conflicts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  entity_table text not null,
  entity_id uuid not null,
  local_payload jsonb not null,
  server_payload jsonb not null,
  detected_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolution text check (resolution in ('keep_local', 'keep_server', 'merged'))
);

create index sync_conflicts_user_id_idx on public.sync_conflicts (user_id);
create index sync_conflicts_entity_idx on public.sync_conflicts (entity_table, entity_id);
create index sync_conflicts_unresolved_idx on public.sync_conflicts (user_id) where resolved_at is null;

create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  period text not null check (period in ('weekly', 'monthly', 'custom')),
  period_start date not null,
  period_end date,
  currency text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index budgets_user_id_idx on public.budgets (user_id) where deleted_at is null;

create table public.budget_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  budget_id uuid not null references public.budgets (id) on delete cascade,
  category_id uuid not null references public.transaction_categories (id) on delete cascade,
  planned_amount numeric(18, 4) not null check (planned_amount >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint budget_items_budget_category_unique unique (budget_id, category_id)
);

create index budget_items_budget_id_idx on public.budget_items (budget_id);

create table public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  target_amount numeric(18, 4) not null check (target_amount >= 0),
  currency text not null,
  current_amount numeric(18, 4) not null default 0,
  target_date date,
  linked_account_id uuid references public.financial_accounts (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index savings_goals_user_id_idx on public.savings_goals (user_id) where deleted_at is null;

create table public.financial_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  -- schema-ready for Phase 2 goal types (debt_payoff, net_worth_target)
  -- without a destructive migration; only 'custom' and 'savings_target' are
  -- exercised by the Phase 1 UI.
  goal_type text not null default 'custom'
    check (goal_type in ('custom', 'savings_target', 'debt_payoff', 'net_worth_target', 'income_target')),
  target_amount numeric(18, 4),
  currency text not null,
  target_date date,
  linked_goal_id uuid references public.goals (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index financial_goals_user_id_idx on public.financial_goals (user_id) where deleted_at is null;
create index financial_goals_linked_goal_id_idx on public.financial_goals (linked_goal_id);
