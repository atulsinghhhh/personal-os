import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/core_tables.dart';
import 'tables/money_phase2_tables.dart';
import 'tables/money_tables.dart';
import 'tables/notes_reviews_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/time_planning_tables.dart';

part 'database.g.dart';

/// The local-first source of truth the entire UI reads from via `.watch()`
/// streams. Supabase is synced to/from this database by SyncEngine; the UI
/// never queries Supabase directly.
@DriftDatabase(
  tables: <Type>[
    Profiles,
    LifeAreas,
    Visions,
    Goals,
    GoalMetrics,
    Milestones,
    Projects,
    Tasks,
    TaskDependencies,
    CalendarEvents,
    TimeBlocks,
    FocusSessions,
    DailyPlans,
    WeeklyPlans,
    MonthlyPlans,
    YearlyPlans,
    Notes,
    DailyReviews,
    WeeklyReviews,
    MonthlyReviews,
    FinancialAccounts,
    TransactionCategories,
    Transactions,
    Budgets,
    BudgetItems,
    SavingsGoals,
    FinancialGoals,
    Bills,
    Subscriptions,
    Debts,
    Assets,
    NetWorthSnapshots,
    SyncOutbox,
    SyncMeta,
    ConflictQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(bills);
            await m.createTable(subscriptions);
            await m.createTable(debts);
            await m.createTable(assets);
            await m.createTable(netWorthSnapshots);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'personal_os');
  }
}
