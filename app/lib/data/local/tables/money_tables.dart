import 'package:drift/drift.dart';

import 'sync_columns.dart';

class FinancialAccounts extends Table with SyncableColumns {
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get currency => text()();
  RealColumn get openingBalance =>
      real().named('opening_balance').withDefault(const Constant(0))();
  TextColumn get institutionName =>
      text().named('institution_name').nullable()();
  BoolColumn get isArchived =>
      boolean().named('is_archived').withDefault(const Constant(false))();
}

class TransactionCategories extends Table with SyncableColumns {
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get parentId => text().named('parent_id').nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  BoolColumn get isSystem =>
      boolean().named('is_system').withDefault(const Constant(false))();
}

/// Mirrors the Postgres `transactions` table's conflict-tracking columns:
/// [clientUpdatedAt] is the user's real local edit time (informational),
/// [serverUpdatedAt] is stamped by the server on every accepted write and
/// used as the optimistic-concurrency base value, [conflictState] flips to
/// 'pending_review' when a push is rejected because the server row moved —
/// see core/sync/conflict/.
class Transactions extends Table with SyncableColumns {
  TextColumn get accountId => text().named('account_id')();
  TextColumn get categoryId => text().named('category_id').nullable()();
  TextColumn get projectId => text().named('project_id').nullable()();
  TextColumn get goalId => text().named('goal_id').nullable()();
  TextColumn get kind => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  DateTimeColumn get occurredAt => dateTime().named('occurred_at')();
  TextColumn get note => text().nullable()();
  DateTimeColumn get clientUpdatedAt =>
      dateTime().named('client_updated_at')();
  DateTimeColumn get serverUpdatedAt =>
      dateTime().named('server_updated_at')();
  TextColumn get conflictState => text()
      .named('conflict_state')
      .withDefault(const Constant('none'))();
}

class Budgets extends Table with SyncableColumns {
  TextColumn get name => text()();
  TextColumn get period => text()();
  DateTimeColumn get periodStart => dateTime().named('period_start')();
  DateTimeColumn get periodEnd =>
      dateTime().named('period_end').nullable()();
  TextColumn get currency => text()();
}

class BudgetItems extends Table with SyncableColumns {
  TextColumn get budgetId => text().named('budget_id')();
  TextColumn get categoryId => text().named('category_id')();
  RealColumn get plannedAmount => real().named('planned_amount')();
}

class SavingsGoals extends Table with SyncableColumns {
  TextColumn get name => text()();
  RealColumn get targetAmount => real().named('target_amount')();
  TextColumn get currency => text()();
  RealColumn get currentAmount =>
      real().named('current_amount').withDefault(const Constant(0))();
  DateTimeColumn get targetDate =>
      dateTime().named('target_date').nullable()();
  TextColumn get linkedAccountId =>
      text().named('linked_account_id').nullable()();
}

class FinancialGoals extends Table with SyncableColumns {
  TextColumn get name => text()();
  TextColumn get goalType =>
      text().named('goal_type').withDefault(const Constant('custom'))();
  RealColumn get targetAmount =>
      real().named('target_amount').nullable()();
  TextColumn get currency => text()();
  DateTimeColumn get targetDate =>
      dateTime().named('target_date').nullable()();
  TextColumn get linkedGoalId =>
      text().named('linked_goal_id').nullable()();
}
