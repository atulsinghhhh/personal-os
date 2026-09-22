-- Goals, Goal Metrics, Milestones, Projects, Tasks, Task Dependencies.
-- This is the spine of the "Future -> Goal -> Milestone -> Project -> Task"
-- chain that the app surfaces on every task/project/goal detail screen.

create table public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  vision_id uuid references public.visions (id) on delete set null,
  -- denormalized for cheap "which life area does this goal serve" lookups
  -- without joining through visions.
  life_area_id uuid references public.life_areas (id) on delete set null,
  title text not null,
  description text,
  target_date date,
  status text not null default 'active'
    check (status in ('active', 'paused', 'achieved', 'abandoned')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index goals_user_id_idx on public.goals (user_id) where deleted_at is null;
create index goals_vision_id_idx on public.goals (vision_id);
create index goals_life_area_id_idx on public.goals (life_area_id);

create table public.goal_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  goal_id uuid not null references public.goals (id) on delete cascade,
  name text not null,
  unit text,
  target_value numeric,
  current_value numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index goal_metrics_goal_id_idx on public.goal_metrics (goal_id);

create table public.milestones (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  goal_id uuid not null references public.goals (id) on delete cascade,
  title text not null,
  target_date date,
  status text not null default 'pending' check (status in ('pending', 'done')),
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index milestones_goal_id_idx on public.milestones (goal_id);

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  milestone_id uuid references public.milestones (id) on delete set null,
  -- denormalized: a project can exist without a milestone but should still
  -- trace to a goal so money/time rollups and the breadcrumb chain work.
  goal_id uuid references public.goals (id) on delete set null,
  title text not null,
  description text,
  status text not null default 'active'
    check (status in ('active', 'paused', 'completed', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index projects_user_id_idx on public.projects (user_id) where deleted_at is null;
create index projects_milestone_id_idx on public.projects (milestone_id);
create index projects_goal_id_idx on public.projects (goal_id);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  project_id uuid references public.projects (id) on delete set null,
  title text not null,
  notes text,
  status text not null default 'todo'
    check (status in ('inbox', 'todo', 'in_progress', 'done', 'cancelled', 'someday')),
  priority smallint not null default 0,
  due_date date,
  scheduled_date date,
  estimate_minutes integer,
  -- actual_minutes is a cache rolled up from focus_sessions; the source of
  -- truth is the sum of focus_sessions.duration_minutes for this task, kept
  -- here only so simple list views don't need a join. Recomputed by the app
  -- whenever a focus session for this task completes.
  actual_minutes integer not null default 0,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index tasks_user_id_idx on public.tasks (user_id) where deleted_at is null;
create index tasks_project_id_idx on public.tasks (project_id);
create index tasks_scheduled_date_idx on public.tasks (user_id, scheduled_date) where deleted_at is null;
create index tasks_due_date_idx on public.tasks (user_id, due_date) where deleted_at is null;

create table public.task_dependencies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  task_id uuid not null references public.tasks (id) on delete cascade,
  depends_on_task_id uuid not null references public.tasks (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint task_dependencies_no_self_dependency check (task_id <> depends_on_task_id),
  constraint task_dependencies_unique unique (task_id, depends_on_task_id)
);

create index task_dependencies_task_id_idx on public.task_dependencies (task_id);
create index task_dependencies_depends_on_idx on public.task_dependencies (depends_on_task_id);
