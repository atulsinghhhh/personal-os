import 'package:drift/drift.dart';

import 'sync_columns.dart';

class Bills extends Table with SyncableColumns {
  TextColumn get name => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  DateTimeColumn get dueDate => dateTime().named('due_date')();
  TextColumn get recurrence =>
      text().withDefault(const Constant('monthly'))();
  TextColumn get accountId => text().named('account_id').nullable()();
  TextColumn get categoryId => text().named('category_id').nullable()();
  IntColumn get reminderDaysBefore =>
      integer().named('reminder_days_before').nullable()();
  DateTimeColumn get lastPaidAt =>
      dateTime().named('last_paid_at').nullable()();
}

class Subscriptions extends Table with SyncableColumns {
  TextColumn get service => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text()();
  TextColumn get billingCycle =>
      text().named('billing_cycle').withDefault(const Constant('monthly'))();
  DateTimeColumn get renewalDate =>
      dateTime().named('renewal_date').nullable()();
  TextColumn get categoryId => text().named('category_id').nullable()();
  TextColumn get accountId => text().named('account_id').nullable()();
  TextColumn get cancellationNote =>
      text().named('cancellation_note').nullable()();
  BoolColumn get isActive =>
      boolean().named('is_active').withDefault(const Constant(true))();
}

class Debts extends Table with SyncableColumns {
  TextColumn get name => text()();
  RealColumn get principal => real()();
  RealColumn get currentBalance => real().named('current_balance')();
  TextColumn get currency => text()();
  RealColumn get interestRatePercent =>
      real().named('interest_rate_percent').nullable()();
  RealColumn get minimumPayment =>
      real().named('minimum_payment').nullable()();
  TextColumn get paymentFrequency => text()
      .named('payment_frequency')
      .withDefault(const Constant('monthly'))();
  DateTimeColumn get dueDate => dateTime().named('due_date').nullable()();
  DateTimeColumn get startDate =>
      dateTime().named('start_date').nullable()();
  DateTimeColumn get targetPayoffDate =>
      dateTime().named('target_payoff_date').nullable()();
}

class Assets extends Table with SyncableColumns {
  TextColumn get name => text()();
  RealColumn get value => real()();
  TextColumn get currency => text()();
  TextColumn get note => text().nullable()();
}

/// breakdown is the JSON-encoded per-currency map
/// {"INR": {"assets": 1000, "liabilities": 200}, ...}.
class NetWorthSnapshots extends Table with SyncableColumns {
  DateTimeColumn get date => dateTime()();
  TextColumn get breakdown => text()();
}
