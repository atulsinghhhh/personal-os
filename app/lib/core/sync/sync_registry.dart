import 'package:drift/drift.dart';

import '../../data/local/database.dart';

/// Conflict policy per entity class. Everything is last-write-wins except
/// transactions, which must never be silently overwritten (hard product
/// requirement) — their push uses optimistic concurrency and surfaces
/// mismatches for manual resolution.
enum ConflictPolicy { lastWriteWins, manualResolve }

/// One syncable table: how to reach its Drift table, which Supabase table
/// mirrors it, and its conflict policy. The engine iterates this list for
/// pulls; pushes are driven by outbox rows carrying the table name.
class SyncTableSpec {
  const SyncTableSpec({
    required this.tableName,
    required this.policy,
    this.watermarkColumn = 'updated_at',
  });

  final String tableName;
  final ConflictPolicy policy;

  /// Column used for delta pulls. task_dependencies is an immutable link
  /// row with no updated_at, so it watermarks on created_at instead.
  final String watermarkColumn;
}

/// Every table that syncs, in dependency order: parents before children so
/// a pull can insert rows without hitting missing-foreign-key states, and
/// pushes drain the outbox in write order anyway (outbox is FIFO).
const List<SyncTableSpec> syncTables = <SyncTableSpec>[
  SyncTableSpec(tableName: 'life_areas', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'visions', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'goals', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'goal_metrics', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'milestones', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'projects', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'tasks', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(
    tableName: 'task_dependencies',
    policy: ConflictPolicy.lastWriteWins,
    watermarkColumn: 'created_at',
  ),
  SyncTableSpec(tableName: 'calendar_events', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'time_blocks', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'focus_sessions', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'daily_plans', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'weekly_plans', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'monthly_plans', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'yearly_plans', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'notes', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'daily_reviews', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'weekly_reviews', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'monthly_reviews', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'financial_accounts', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'transaction_categories', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'transactions', policy: ConflictPolicy.manualResolve),
  SyncTableSpec(tableName: 'budgets', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'budget_items', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'savings_goals', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'financial_goals', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'bills', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'subscriptions', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'debts', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'assets', policy: ConflictPolicy.lastWriteWins),
  SyncTableSpec(tableName: 'net_worth_snapshots', policy: ConflictPolicy.lastWriteWins),
];

/// Resolves a table name from the registry to its Drift [TableInfo] so the
/// engine can run generic upserts during pull.
TableInfo<Table, dynamic> driftTableByName(AppDatabase db, String name) {
  switch (name) {
    case 'profiles':
      return db.profiles;
    case 'life_areas':
      return db.lifeAreas;
    case 'visions':
      return db.visions;
    case 'goals':
      return db.goals;
    case 'goal_metrics':
      return db.goalMetrics;
    case 'milestones':
      return db.milestones;
    case 'projects':
      return db.projects;
    case 'tasks':
      return db.tasks;
    case 'task_dependencies':
      return db.taskDependencies;
    case 'calendar_events':
      return db.calendarEvents;
    case 'time_blocks':
      return db.timeBlocks;
    case 'focus_sessions':
      return db.focusSessions;
    case 'daily_plans':
      return db.dailyPlans;
    case 'weekly_plans':
      return db.weeklyPlans;
    case 'monthly_plans':
      return db.monthlyPlans;
    case 'yearly_plans':
      return db.yearlyPlans;
    case 'notes':
      return db.notes;
    case 'daily_reviews':
      return db.dailyReviews;
    case 'weekly_reviews':
      return db.weeklyReviews;
    case 'monthly_reviews':
      return db.monthlyReviews;
    case 'financial_accounts':
      return db.financialAccounts;
    case 'transaction_categories':
      return db.transactionCategories;
    case 'transactions':
      return db.transactions;
    case 'budgets':
      return db.budgets;
    case 'budget_items':
      return db.budgetItems;
    case 'savings_goals':
      return db.savingsGoals;
    case 'financial_goals':
      return db.financialGoals;
    case 'bills':
      return db.bills;
    case 'subscriptions':
      return db.subscriptions;
    case 'debts':
      return db.debts;
    case 'assets':
      return db.assets;
    case 'net_worth_snapshots':
      return db.netWorthSnapshots;
    default:
      throw ArgumentError('Unknown sync table: $name');
  }
}
