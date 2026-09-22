import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/models/money.dart';
import '../../../calendar/domain/entities/calendar_entities.dart';
import '../../../focus/domain/entities/focus_session.dart';
import '../../../focus/domain/repositories/focus_repository.dart';
import '../../../future/domain/entities/future_entities.dart';
import '../../../money/transactions/domain/entities/transaction_entities.dart';
import '../../../projects/domain/entities/project_entities.dart';

/// Derived, read-only providers feeding the Today screen. All of them read
/// the local Drift database only — instant, offline-first.

DateTime _todayUtc() {
  final DateTime now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day);
}

/// Tasks scheduled for today, ordered by priority/sort.
final StreamProvider<List<Task>> todayTasksProvider =
    StreamProvider<List<Task>>((Ref ref) {
  return ref
      .watch(taskRepositoryProvider)
      .watchScheduledForDate(_todayUtc());
});

/// The user's most recent vision — the "direction" line under the greeting.
final StreamProvider<Vision?> directionProvider = StreamProvider<Vision?>((
  Ref ref,
) {
  return ref
      .watch(visionRepositoryProvider)
      .watchAll()
      .map((List<Vision> visions) => visions.isEmpty ? null : visions.first);
});

/// Today's time blocks (the schedule section).
final StreamProvider<List<TimeBlock>> todayTimeBlocksProvider =
    StreamProvider<List<TimeBlock>>((Ref ref) {
  return ref.watch(timeBlockRepositoryProvider).watchForDate(_todayUtc());
});

/// Focus minutes recorded today.
final StreamProvider<int> todayFocusMinutesProvider = StreamProvider<int>((
  Ref ref,
) {
  final FocusSessionRepository repo =
      ref.watch(focusSessionRepositoryProvider);
  final DateTime start = _todayUtc();
  return repo
      .watchForDateRange(start, start.add(const Duration(days: 1)))
      .map(
        (List<FocusSession> sessions) => sessions.fold<int>(
          0,
          (int total, FocusSession session) =>
              total + (session.durationMinutes ?? 0),
        ),
      );
});

/// Money spent today, grouped by currency.
final StreamProvider<List<Money>> todaySpentProvider =
    StreamProvider<List<Money>>((Ref ref) {
  final DateTime start = _todayUtc();
  return ref
      .watch(transactionRepositoryProvider)
      .watchForRange(start, start.add(const Duration(days: 1)))
      .map((List<MoneyTransaction> transactions) {
    final Map<String, double> byCurrency = <String, double>{};
    for (final MoneyTransaction transaction in transactions) {
      if (transaction.kind != TransactionKind.expense) continue;
      byCurrency.update(
        transaction.amount.currency,
        (double total) => total + transaction.amount.amount,
        ifAbsent: () => transaction.amount.amount,
      );
    }
    return byCurrency.entries
        .map(
          (MapEntry<String, double> entry) =>
              Money(amount: entry.value, currency: entry.key),
        )
        .toList(growable: false);
  });
});
