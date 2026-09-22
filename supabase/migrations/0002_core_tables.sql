-- Profile (1:1 with auth.users), Life Areas, Visions.
--
-- Timestamp convention used throughout this schema: `updated_at` is set by
-- the CLIENT on every write (it represents "when did the user make this
-- edit", not "when did the server receive it") so that last-write-wins
-- comparisons across an offline sync queue reflect true edit recency rather
-- than sync-arrival order. The `transactions` table (0005) is the one
-- exception — it additionally tracks a server-stamped `server_updated_at`
-- used for optimistic-concurrency conflict detection.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  -- ISO 4217 currency code. Nullable until the user completes onboarding's
  -- currency step; never hardcoded to a specific currency anywhere in the
  -- schema or app.
  default_currency text,
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is 'One row per authenticated user; default_currency is set during onboarding.';

-- Auto-create a profile row when a new auth user signs up, so the app never
-- has to special-case "profile missing" for an otherwise-authenticated user.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, created_at, updated_at)
  values (new.id, new.raw_user_meta_data ->> 'display_name', now(), now());
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create table public.life_areas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  color text,
  icon text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index life_areas_user_id_idx on public.life_areas (user_id) where deleted_at is null;

create table public.visions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  life_area_id uuid references public.life_areas (id) on delete set null,
  title text not null,
  description text,
  horizon_years integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index visions_user_id_idx on public.visions (user_id) where deleted_at is null;
create index visions_life_area_id_idx on public.visions (life_area_id);
