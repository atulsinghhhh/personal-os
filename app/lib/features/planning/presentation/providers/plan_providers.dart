import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;

import '../../../../core/providers/repository_providers.dart';
import '../../../calendar/domain/entities/calendar_entities.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../../money/transactions/domain/entities/transaction_entities.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../domain/entities/plan_entities.dart';

/// Derived providers feeding the Plan tab. All family keys are normalized
/// UTC dates (or a plain year int) so provider identity is stable.

/// Midnight-UTC normalization for date-keyed rows.
DateTime utcDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

/// The Monday (UTC midnight) of the week containing [date].
DateTime mondayOf(DateTime date) {
  final DateTime day = utcDate(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

final StreamProviderFamily<DailyPlan?, DateTime> dailyPlanForDateProvider =
    StreamProvider.family<DailyPlan?, DateTime>((Ref ref, DateTime date) {
  return ref.watch(dailyPlanRepositoryProvider).watchForDate(date);
});

final StreamProviderFamily<List<Task>, DateTime> tasksForDateProvider =
    StreamProvider.family<List<Task>, DateTime>((Ref ref, DateTime date) {
  return ref.watch(taskRepositoryProvider).watchScheduledForDate(date);
});

final StreamProviderFamily<List<TimeBlock>, DateTime>
    timeBlocksForDateProvider =
    StreamProvider.family<List<TimeBlock>, DateTime>((Ref ref, DateTime date) {
  return ref.watch(timeBlockRepositoryProvider).watchForDate(date);
});

final StreamProviderFamily<WeeklyPlan?, DateTime> weeklyPlanForWeekProvider =
    StreamProvider.family<WeeklyPlan?, DateTime>(
        (Ref ref, DateTime weekStart) {
  return ref.watch(weeklyPlanRepositoryProvider).watchForWeek(weekStart);
});

final StreamProviderFamily<MonthlyPlan?, DateTime>
    monthlyPlanForMonthProvider =
    StreamProvider.family<MonthlyPlan?, DateTime>((Ref ref, DateTime month) {
  return ref.watch(monthlyPlanRepositoryProvider).watchForMonth(month);
});

final StreamProviderFamily<YearlyPlan?, int> yearlyPlanForYearProvider =
    StreamProvider.family<YearlyPlan?, int>((Ref ref, int year) {
  return ref.watch(yearlyPlanRepositoryProvider).watchForYear(year);
});

/// All tasks — filtered client-side for week views (scheduled/carry-over).
final StreamProvider<List<Task>> allTasksProvider =
    StreamProvider<List<Task>>((Ref ref) {
  return ref.watch(taskRepositoryProvider).watchAll();
});

/// All goals — filtered client-side by targetDate for month/year views.
final StreamProvider<List<Goal>> allGoalsProvider =
    StreamProvider<List<Goal>>((Ref ref) {
  return ref.watch(goalRepositoryProvider).watchAll();
});

/// Transactions inside [start, end) — used for the month money summary.
final StreamProviderFamily<List<MoneyTransaction>,
        ({DateTime start, DateTime end})> transactionsForRangeProvider =
    StreamProvider.family<List<MoneyTransaction>,
        ({DateTime start, DateTime end})>(
  (Ref ref, ({DateTime start, DateTime end}) range) {
    return ref
        .watch(transactionRepositoryProvider)
        .watchForRange(range.start, range.end);
  },
);
