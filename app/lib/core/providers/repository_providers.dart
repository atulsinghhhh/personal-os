import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient;

import '../../features/calendar/data/calendar_repositories_impl.dart';
import '../../features/calendar/domain/repositories/calendar_repositories.dart';
import '../../features/focus/data/focus_repository_impl.dart';
import '../../features/focus/domain/repositories/focus_repository.dart';
import '../../features/future/data/future_repositories_impl.dart';
import '../../features/future/domain/repositories/future_repositories.dart';
import '../../features/goals/data/goal_repository_impl.dart';
import '../../features/goals/domain/repositories/goal_repositories.dart';
import '../../features/money/accounts/data/account_repository_impl.dart';
import '../../features/money/accounts/domain/repositories/account_repository.dart';
import '../../features/money/budgets/data/budget_repository_impl.dart';
import '../../features/money/budgets/domain/repositories/budget_repository.dart';
import '../../features/money/financial_goals/data/financial_goal_repository_impl.dart';
import '../../features/money/financial_goals/domain/repositories/financial_goal_repository.dart';
import '../../features/money/savings_goals/data/savings_goal_repository_impl.dart';
import '../../features/money/savings_goals/domain/repositories/savings_goal_repository.dart';
import '../../features/money/transactions/data/transaction_repositories_impl.dart';
import '../../features/money/transactions/domain/repositories/transaction_repositories.dart';
import '../../features/notes/data/note_repository_impl.dart';
import '../../features/notes/domain/repositories/note_repository.dart';
import '../../features/planning/data/plan_repositories_impl.dart';
import '../../features/planning/domain/repositories/plan_repositories.dart';
import '../../features/projects/data/project_repository_impl.dart';
import '../../features/projects/data/task_repository_impl.dart';
import '../../features/projects/domain/repositories/project_repositories.dart';
import '../../features/review/data/review_repositories_impl.dart';
import '../../features/review/domain/repositories/review_repositories.dart';
import '../../features/settings/data/profile_repository.dart';
import '../../shared/models/profile.dart';
import '../sync/sync_providers.dart';
import 'core_providers.dart';

/// One place to construct every repository implementation: Drift + outbox +
/// a post-write sync kick. New feature repos register here.

void Function() _kicker(Ref ref) {
  return () => unawaited(ref.read(syncEngineProvider).kick());
}

final Provider<LifeAreaRepository> lifeAreaRepositoryProvider =
    Provider<LifeAreaRepository>((Ref ref) {
  return DriftLifeAreaRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<VisionRepository> visionRepositoryProvider =
    Provider<VisionRepository>((Ref ref) {
  return DriftVisionRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>((Ref ref) {
  return ProfileRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

/// The signed-in user's profile, watched from the local database.
final StreamProvider<Profile?> currentProfileProvider =
    StreamProvider<Profile?>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  final String? userId = client.auth.currentUser?.id;
  if (userId == null) return Stream<Profile?>.value(null);
  return ref.watch(profileRepositoryProvider).watch(userId);
});

final Provider<ProjectRepository> projectRepositoryProvider =
    Provider<ProjectRepository>((Ref ref) {
  return DriftProjectRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<TaskRepository> taskRepositoryProvider =
    Provider<TaskRepository>((Ref ref) {
  return DriftTaskRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<GoalRepository> goalRepositoryProvider =
    Provider<GoalRepository>((Ref ref) {
  return DriftGoalRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<FocusSessionRepository> focusSessionRepositoryProvider =
    Provider<FocusSessionRepository>((Ref ref) {
  return DriftFocusSessionRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<CalendarEventRepository> calendarEventRepositoryProvider =
    Provider<CalendarEventRepository>((Ref ref) {
  return DriftCalendarEventRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<TimeBlockRepository> timeBlockRepositoryProvider =
    Provider<TimeBlockRepository>((Ref ref) {
  return DriftTimeBlockRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<DailyPlanRepository> dailyPlanRepositoryProvider =
    Provider<DailyPlanRepository>((Ref ref) {
  return DriftDailyPlanRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<WeeklyPlanRepository> weeklyPlanRepositoryProvider =
    Provider<WeeklyPlanRepository>((Ref ref) {
  return DriftWeeklyPlanRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<MonthlyPlanRepository> monthlyPlanRepositoryProvider =
    Provider<MonthlyPlanRepository>((Ref ref) {
  return DriftMonthlyPlanRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<YearlyPlanRepository> yearlyPlanRepositoryProvider =
    Provider<YearlyPlanRepository>((Ref ref) {
  return DriftYearlyPlanRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<DailyReviewRepository> dailyReviewRepositoryProvider =
    Provider<DailyReviewRepository>((Ref ref) {
  return DriftDailyReviewRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<WeeklyReviewRepository> weeklyReviewRepositoryProvider =
    Provider<WeeklyReviewRepository>((Ref ref) {
  return DriftWeeklyReviewRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<MonthlyReviewRepository> monthlyReviewRepositoryProvider =
    Provider<MonthlyReviewRepository>((Ref ref) {
  return DriftMonthlyReviewRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<FinancialAccountRepository> financialAccountRepositoryProvider =
    Provider<FinancialAccountRepository>((Ref ref) {
  return DriftFinancialAccountRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<TransactionRepository> transactionRepositoryProvider =
    Provider<TransactionRepository>((Ref ref) {
  return DriftTransactionRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<TransactionCategoryRepository>
    transactionCategoryRepositoryProvider =
    Provider<TransactionCategoryRepository>((Ref ref) {
  return DriftTransactionCategoryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<BudgetRepository> budgetRepositoryProvider =
    Provider<BudgetRepository>((Ref ref) {
  return DriftBudgetRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<SavingsGoalRepository> savingsGoalRepositoryProvider =
    Provider<SavingsGoalRepository>((Ref ref) {
  return DriftSavingsGoalRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<FinancialGoalRepository> financialGoalRepositoryProvider =
    Provider<FinancialGoalRepository>((Ref ref) {
  return DriftFinancialGoalRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<NoteRepository> noteRepositoryProvider =
    Provider<NoteRepository>((Ref ref) {
  return DriftNoteRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});
