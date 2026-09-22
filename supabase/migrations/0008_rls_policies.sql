-- Row Level Security. Every user-owned table gets the identical four-policy
-- pattern (select/insert/update/delete, all scoped to the owning user) so
-- the security model is uniform and easy to audit table-by-table. Written
-- out explicitly per table rather than generated dynamically.

-- profiles: keyed by `id`, not `user_id`.
alter table public.profiles enable row level security;

create policy "profiles_select_own" on public.profiles
  for select using (id = auth.uid());
create policy "profiles_insert_own" on public.profiles
  for insert with check (id = auth.uid());
create policy "profiles_update_own" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- Every remaining table below follows: select/insert/update/delete scoped
-- to user_id = auth.uid().

alter table public.life_areas enable row level security;
create policy "life_areas_select_own" on public.life_areas for select using (user_id = auth.uid());
create policy "life_areas_insert_own" on public.life_areas for insert with check (user_id = auth.uid());
create policy "life_areas_update_own" on public.life_areas for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "life_areas_delete_own" on public.life_areas for delete using (user_id = auth.uid());

alter table public.visions enable row level security;
create policy "visions_select_own" on public.visions for select using (user_id = auth.uid());
create policy "visions_insert_own" on public.visions for insert with check (user_id = auth.uid());
create policy "visions_update_own" on public.visions for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "visions_delete_own" on public.visions for delete using (user_id = auth.uid());

alter table public.goals enable row level security;
create policy "goals_select_own" on public.goals for select using (user_id = auth.uid());
create policy "goals_insert_own" on public.goals for insert with check (user_id = auth.uid());
create policy "goals_update_own" on public.goals for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "goals_delete_own" on public.goals for delete using (user_id = auth.uid());

alter table public.goal_metrics enable row level security;
create policy "goal_metrics_select_own" on public.goal_metrics for select using (user_id = auth.uid());
create policy "goal_metrics_insert_own" on public.goal_metrics for insert with check (user_id = auth.uid());
create policy "goal_metrics_update_own" on public.goal_metrics for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "goal_metrics_delete_own" on public.goal_metrics for delete using (user_id = auth.uid());

alter table public.milestones enable row level security;
create policy "milestones_select_own" on public.milestones for select using (user_id = auth.uid());
create policy "milestones_insert_own" on public.milestones for insert with check (user_id = auth.uid());
create policy "milestones_update_own" on public.milestones for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "milestones_delete_own" on public.milestones for delete using (user_id = auth.uid());

alter table public.projects enable row level security;
create policy "projects_select_own" on public.projects for select using (user_id = auth.uid());
create policy "projects_insert_own" on public.projects for insert with check (user_id = auth.uid());
create policy "projects_update_own" on public.projects for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "projects_delete_own" on public.projects for delete using (user_id = auth.uid());

alter table public.tasks enable row level security;
create policy "tasks_select_own" on public.tasks for select using (user_id = auth.uid());
create policy "tasks_insert_own" on public.tasks for insert with check (user_id = auth.uid());
create policy "tasks_update_own" on public.tasks for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "tasks_delete_own" on public.tasks for delete using (user_id = auth.uid());

alter table public.task_dependencies enable row level security;
create policy "task_dependencies_select_own" on public.task_dependencies for select using (user_id = auth.uid());
create policy "task_dependencies_insert_own" on public.task_dependencies for insert with check (user_id = auth.uid());
create policy "task_dependencies_update_own" on public.task_dependencies for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "task_dependencies_delete_own" on public.task_dependencies for delete using (user_id = auth.uid());

alter table public.calendar_events enable row level security;
create policy "calendar_events_select_own" on public.calendar_events for select using (user_id = auth.uid());
create policy "calendar_events_insert_own" on public.calendar_events for insert with check (user_id = auth.uid());
create policy "calendar_events_update_own" on public.calendar_events for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "calendar_events_delete_own" on public.calendar_events for delete using (user_id = auth.uid());

alter table public.time_blocks enable row level security;
create policy "time_blocks_select_own" on public.time_blocks for select using (user_id = auth.uid());
create policy "time_blocks_insert_own" on public.time_blocks for insert with check (user_id = auth.uid());
create policy "time_blocks_update_own" on public.time_blocks for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "time_blocks_delete_own" on public.time_blocks for delete using (user_id = auth.uid());

alter table public.focus_sessions enable row level security;
create policy "focus_sessions_select_own" on public.focus_sessions for select using (user_id = auth.uid());
create policy "focus_sessions_insert_own" on public.focus_sessions for insert with check (user_id = auth.uid());
create policy "focus_sessions_update_own" on public.focus_sessions for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "focus_sessions_delete_own" on public.focus_sessions for delete using (user_id = auth.uid());

alter table public.daily_plans enable row level security;
create policy "daily_plans_select_own" on public.daily_plans for select using (user_id = auth.uid());
create policy "daily_plans_insert_own" on public.daily_plans for insert with check (user_id = auth.uid());
create policy "daily_plans_update_own" on public.daily_plans for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "daily_plans_delete_own" on public.daily_plans for delete using (user_id = auth.uid());

alter table public.weekly_plans enable row level security;
create policy "weekly_plans_select_own" on public.weekly_plans for select using (user_id = auth.uid());
create policy "weekly_plans_insert_own" on public.weekly_plans for insert with check (user_id = auth.uid());
create policy "weekly_plans_update_own" on public.weekly_plans for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "weekly_plans_delete_own" on public.weekly_plans for delete using (user_id = auth.uid());

alter table public.monthly_plans enable row level security;
create policy "monthly_plans_select_own" on public.monthly_plans for select using (user_id = auth.uid());
create policy "monthly_plans_insert_own" on public.monthly_plans for insert with check (user_id = auth.uid());
create policy "monthly_plans_update_own" on public.monthly_plans for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "monthly_plans_delete_own" on public.monthly_plans for delete using (user_id = auth.uid());

alter table public.yearly_plans enable row level security;
create policy "yearly_plans_select_own" on public.yearly_plans for select using (user_id = auth.uid());
create policy "yearly_plans_insert_own" on public.yearly_plans for insert with check (user_id = auth.uid());
create policy "yearly_plans_update_own" on public.yearly_plans for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "yearly_plans_delete_own" on public.yearly_plans for delete using (user_id = auth.uid());

alter table public.daily_reviews enable row level security;
create policy "daily_reviews_select_own" on public.daily_reviews for select using (user_id = auth.uid());
create policy "daily_reviews_insert_own" on public.daily_reviews for insert with check (user_id = auth.uid());
create policy "daily_reviews_update_own" on public.daily_reviews for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "daily_reviews_delete_own" on public.daily_reviews for delete using (user_id = auth.uid());

alter table public.weekly_reviews enable row level security;
create policy "weekly_reviews_select_own" on public.weekly_reviews for select using (user_id = auth.uid());
create policy "weekly_reviews_insert_own" on public.weekly_reviews for insert with check (user_id = auth.uid());
create policy "weekly_reviews_update_own" on public.weekly_reviews for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "weekly_reviews_delete_own" on public.weekly_reviews for delete using (user_id = auth.uid());

alter table public.monthly_reviews enable row level security;
create policy "monthly_reviews_select_own" on public.monthly_reviews for select using (user_id = auth.uid());
create policy "monthly_reviews_insert_own" on public.monthly_reviews for insert with check (user_id = auth.uid());
create policy "monthly_reviews_update_own" on public.monthly_reviews for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "monthly_reviews_delete_own" on public.monthly_reviews for delete using (user_id = auth.uid());

alter table public.financial_accounts enable row level security;
create policy "financial_accounts_select_own" on public.financial_accounts for select using (user_id = auth.uid());
create policy "financial_accounts_insert_own" on public.financial_accounts for insert with check (user_id = auth.uid());
create policy "financial_accounts_update_own" on public.financial_accounts for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "financial_accounts_delete_own" on public.financial_accounts for delete using (user_id = auth.uid());

alter table public.transaction_categories enable row level security;
create policy "transaction_categories_select_own" on public.transaction_categories for select using (user_id = auth.uid());
create policy "transaction_categories_insert_own" on public.transaction_categories for insert with check (user_id = auth.uid());
create policy "transaction_categories_update_own" on public.transaction_categories for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "transaction_categories_delete_own" on public.transaction_categories for delete using (user_id = auth.uid());

alter table public.transactions enable row level security;
create policy "transactions_select_own" on public.transactions for select using (user_id = auth.uid());
create policy "transactions_insert_own" on public.transactions for insert with check (user_id = auth.uid());
create policy "transactions_update_own" on public.transactions for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "transactions_delete_own" on public.transactions for delete using (user_id = auth.uid());

alter table public.sync_conflicts enable row level security;
create policy "sync_conflicts_select_own" on public.sync_conflicts for select using (user_id = auth.uid());
create policy "sync_conflicts_insert_own" on public.sync_conflicts for insert with check (user_id = auth.uid());
create policy "sync_conflicts_update_own" on public.sync_conflicts for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "sync_conflicts_delete_own" on public.sync_conflicts for delete using (user_id = auth.uid());

alter table public.budgets enable row level security;
create policy "budgets_select_own" on public.budgets for select using (user_id = auth.uid());
create policy "budgets_insert_own" on public.budgets for insert with check (user_id = auth.uid());
create policy "budgets_update_own" on public.budgets for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "budgets_delete_own" on public.budgets for delete using (user_id = auth.uid());

alter table public.budget_items enable row level security;
create policy "budget_items_select_own" on public.budget_items for select using (user_id = auth.uid());
create policy "budget_items_insert_own" on public.budget_items for insert with check (user_id = auth.uid());
create policy "budget_items_update_own" on public.budget_items for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "budget_items_delete_own" on public.budget_items for delete using (user_id = auth.uid());

alter table public.savings_goals enable row level security;
create policy "savings_goals_select_own" on public.savings_goals for select using (user_id = auth.uid());
create policy "savings_goals_insert_own" on public.savings_goals for insert with check (user_id = auth.uid());
create policy "savings_goals_update_own" on public.savings_goals for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "savings_goals_delete_own" on public.savings_goals for delete using (user_id = auth.uid());

alter table public.financial_goals enable row level security;
create policy "financial_goals_select_own" on public.financial_goals for select using (user_id = auth.uid());
create policy "financial_goals_insert_own" on public.financial_goals for insert with check (user_id = auth.uid());
create policy "financial_goals_update_own" on public.financial_goals for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "financial_goals_delete_own" on public.financial_goals for delete using (user_id = auth.uid());

alter table public.notes enable row level security;
create policy "notes_select_own" on public.notes for select using (user_id = auth.uid());
create policy "notes_insert_own" on public.notes for insert with check (user_id = auth.uid());
create policy "notes_update_own" on public.notes for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "notes_delete_own" on public.notes for delete using (user_id = auth.uid());
