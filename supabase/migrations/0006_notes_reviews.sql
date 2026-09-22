-- Notes and daily/weekly/monthly reviews.

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text,
  body text,
  project_id uuid references public.projects (id) on delete set null,
  goal_id uuid references public.goals (id) on delete set null,
  task_id uuid references public.tasks (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index notes_user_id_idx on public.notes (user_id) where deleted_at is null;
create index notes_project_id_idx on public.notes (project_id);
create index notes_goal_id_idx on public.notes (goal_id);
create index notes_task_id_idx on public.notes (task_id);

create table public.daily_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null,
  energy smallint check (energy between 1 and 5),
  focus smallint check (focus between 1 and 5),
  mood smallint check (mood between 1 and 5),
  accomplished text,
  blocked_by text,
  change_tomorrow text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint daily_reviews_user_date_unique unique (user_id, date)
);

create table public.weekly_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  week_start date not null,
  went_well text,
  went_poorly text,
  learned text,
  stop_doing text,
  continue_doing text,
  next_week_focus text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint weekly_reviews_user_week_unique unique (user_id, week_start)
);

create table public.monthly_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  month date not null,
  summary text,
  what_mattered text,
  what_wasted_time text,
  what_was_worth_the_money text,
  change_next_month text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint monthly_reviews_user_month_unique unique (user_id, month)
);
