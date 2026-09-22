-- Calendar events, time blocks, focus sessions, and the Day/Week/Month/Year
-- plan tables.

create table public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  all_day boolean not null default false,
  related_task_id uuid references public.tasks (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint calendar_events_valid_range check (end_at >= start_at)
);

create index calendar_events_user_id_idx on public.calendar_events (user_id) where deleted_at is null;
create index calendar_events_start_at_idx on public.calendar_events (user_id, start_at);

create table public.time_blocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  task_id uuid references public.tasks (id) on delete set null,
  date date not null,
  start_at timestamptz,
  end_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index time_blocks_user_id_date_idx on public.time_blocks (user_id, date) where deleted_at is null;
create index time_blocks_task_id_idx on public.time_blocks (task_id);

create table public.focus_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  task_id uuid references public.tasks (id) on delete set null,
  started_at timestamptz not null,
  ended_at timestamptz,
  duration_minutes integer,
  was_completed boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index focus_sessions_user_id_idx on public.focus_sessions (user_id) where deleted_at is null;
create index focus_sessions_task_id_idx on public.focus_sessions (task_id);
create index focus_sessions_started_at_idx on public.focus_sessions (user_id, started_at);

-- Plan tables are intentionally simple in Phase 1: an ordered id list plus a
-- short free-text field. Deeper analytics (time/money allocation, rollups)
-- are computed by the app by joining against tasks/goals/transactions, not
-- stored redundantly here.

create table public.daily_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null,
  intention text,
  task_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint daily_plans_user_date_unique unique (user_id, date)
);

create table public.weekly_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  week_start date not null,
  focus_goal_ids uuid[] not null default '{}',
  outcomes text,
  reflection text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint weekly_plans_user_week_unique unique (user_id, week_start)
);

create table public.monthly_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  month date not null,
  theme text,
  goal_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint monthly_plans_user_month_unique unique (user_id, month)
);

create table public.yearly_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  year integer not null,
  theme text,
  vision_ids uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint yearly_plans_user_year_unique unique (user_id, year)
);
