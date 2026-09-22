-- Indexes supporting the sync engine's delta-pull query pattern:
--   select * from <table> where user_id = auth.uid() and updated_at > :watermark
-- One composite index per syncable table keeps every pull cheap regardless
-- of how large a user's data grows.

create index life_areas_user_updated_idx on public.life_areas (user_id, updated_at);
create index visions_user_updated_idx on public.visions (user_id, updated_at);
create index goals_user_updated_idx on public.goals (user_id, updated_at);
create index goal_metrics_user_updated_idx on public.goal_metrics (user_id, updated_at);
create index milestones_user_updated_idx on public.milestones (user_id, updated_at);
create index projects_user_updated_idx on public.projects (user_id, updated_at);
create index tasks_user_updated_idx on public.tasks (user_id, updated_at);
create index calendar_events_user_updated_idx on public.calendar_events (user_id, updated_at);
create index time_blocks_user_updated_idx on public.time_blocks (user_id, updated_at);
create index focus_sessions_user_updated_idx on public.focus_sessions (user_id, updated_at);
create index daily_plans_user_updated_idx on public.daily_plans (user_id, updated_at);
create index weekly_plans_user_updated_idx on public.weekly_plans (user_id, updated_at);
create index monthly_plans_user_updated_idx on public.monthly_plans (user_id, updated_at);
create index yearly_plans_user_updated_idx on public.yearly_plans (user_id, updated_at);
create index daily_reviews_user_updated_idx on public.daily_reviews (user_id, updated_at);
create index weekly_reviews_user_updated_idx on public.weekly_reviews (user_id, updated_at);
create index monthly_reviews_user_updated_idx on public.monthly_reviews (user_id, updated_at);
create index financial_accounts_user_updated_idx on public.financial_accounts (user_id, updated_at);
create index transaction_categories_user_updated_idx on public.transaction_categories (user_id, updated_at);
create index transactions_user_updated_idx on public.transactions (user_id, updated_at);
create index budgets_user_updated_idx on public.budgets (user_id, updated_at);
create index budget_items_user_updated_idx on public.budget_items (user_id, updated_at);
create index savings_goals_user_updated_idx on public.savings_goals (user_id, updated_at);
create index financial_goals_user_updated_idx on public.financial_goals (user_id, updated_at);
create index notes_user_updated_idx on public.notes (user_id, updated_at);
