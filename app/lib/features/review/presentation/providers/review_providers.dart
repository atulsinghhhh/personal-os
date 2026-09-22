import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;

import '../../../../core/providers/repository_providers.dart';
import '../../../focus/domain/entities/focus_session.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../../money/transactions/domain/entities/transaction_entities.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../domain/entities/review_entities.dart';

/// Derived providers feeding the Review tab. Family keys are normalized
/// UTC dates so provider identity is stable.

/// Midnight-UTC normalization for date-keyed rows.
DateTime reviewUtcDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

/// The Monday (UTC midnight) of the week containing [date].
DateTime reviewMondayOf(DateTime date) {
  final DateTime day = reviewUtcDate(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

final StreamProviderFamily<DailyReview?, DateTime>
    dailyReviewForDateProvider =
    StreamProvider.family<DailyReview?, DateTime>((Ref ref, DateTime date) {
  return ref.watch(dailyReviewRepositoryProvider).watchForDate(date);
});

final StreamProviderFamily<WeeklyReview?, DateTime>
    weeklyReviewForWeekProvider = StreamProvider.family<WeeklyReview?,
        DateTime>((Ref ref, DateTime weekStart) {
  return ref.watch(weeklyReviewRepositoryProvider).watchForWeek(weekStart);
});

final StreamProviderFamily<MonthlyReview?, DateTime>
    monthlyReviewForMonthProvider =
    StreamProvider.family<MonthlyReview?, DateTime>(
        (Ref ref, DateTime month) {
  return ref.watch(monthlyReviewRepositoryProvider).watchForMonth(month);
});

/// Tasks scheduled on the reviewed date (for the "tasks done" context stat).
final StreamProviderFamily<List<Task>, DateTime> reviewTasksForDateProvider =
    StreamProvider.family<List<Task>, DateTime>((Ref ref, DateTime date) {
  return ref.watch(taskRepositoryProvider).watchScheduledForDate(date);
});

/// Focus minutes recorded on the reviewed date.
final StreamProviderFamily<int, DateTime> reviewFocusMinutesProvider =
    StreamProvider.family<int, DateTime>((Ref ref, DateTime date) {
  return ref
      .watch(focusSessionRepositoryProvider)
      .watchForDateRange(date, date.add(const Duration(days: 1)))
      .map(
        (List<FocusSession> sessions) => sessions.fold<int>(
          0,
          (int total, FocusSession session) =>
              total + (session.durationMinutes ?? 0),
        ),
      );
});

/// Transactions on the reviewed date (grouped per currency in the UI).
final StreamProviderFamily<List<MoneyTransaction>, DateTime>
    reviewTransactionsForDateProvider =
    StreamProvider.family<List<MoneyTransaction>, DateTime>(
        (Ref ref, DateTime date) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchForRange(date, date.add(const Duration(days: 1)));
});

/// Transactions in [start, start+days) — used by week/month context cards.
final StreamProviderFamily<List<MoneyTransaction>, (DateTime, int)>
    reviewTransactionsForRangeProvider = StreamProvider.family<
        List<MoneyTransaction>, (DateTime, int)>((Ref ref, (DateTime, int) key) {
  final (DateTime start, int days) = key;
  return ref
      .watch(transactionRepositoryProvider)
      .watchForRange(start, start.add(Duration(days: days)));
});

/// Focus minutes in [start, start+days).
final StreamProviderFamily<int, (DateTime, int)>
    reviewFocusMinutesForRangeProvider =
    StreamProvider.family<int, (DateTime, int)>((Ref ref, (DateTime, int) key) {
  final (DateTime start, int days) = key;
  return ref
      .watch(focusSessionRepositoryProvider)
      .watchForDateRange(start, start.add(Duration(days: days)))
      .map(
        (List<FocusSession> sessions) => sessions.fold<int>(
          0,
          (int total, FocusSession session) =>
              total + (session.durationMinutes ?? 0),
        ),
      );
});

/// All tasks — the week/month views filter client-side by scheduledDate,
/// since watchScheduledForDate only covers a single day.
final StreamProvider<List<Task>> reviewAllTasksProvider =
    StreamProvider<List<Task>>((Ref ref) {
  return ref.watch(taskRepositoryProvider).watchAll();
});

/// All goals — used to approximate "achieved this week/month" by status
/// plus updatedAt falling in range (a labeled approximation, not an exact
/// achieved-date field).
final StreamProvider<List<Goal>> reviewAllGoalsProvider =
    StreamProvider<List<Goal>>((Ref ref) {
  return ref.watch(goalRepositoryProvider).watchAll();
});

/// All projects — used to approximate "completed this month".
final StreamProvider<List<Project>> reviewAllProjectsProvider =
    StreamProvider<List<Project>>((Ref ref) {
  return ref.watch(projectRepositoryProvider).watchAll();
});
