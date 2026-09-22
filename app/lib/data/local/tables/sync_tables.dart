import 'package:drift/drift.dart';

/// Local write queue. Every repository write inserts one row here in the
/// same transaction as the entity write; SyncEngine drains it in
/// [createdAt] order. See core/sync/sync_engine.dart.
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityTable => text().named('entity_table')();
  TextColumn get entityId => text().named('entity_id')();
  TextColumn get operation => text()(); // insert | update | delete
  TextColumn get payload => text()(); // JSON snapshot of the row
  DateTimeColumn get baseServerUpdatedAt =>
      dateTime().named('base_server_updated_at').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  IntColumn get attemptCount =>
      integer().named('attempt_count').withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt =>
      dateTime().named('last_attempt_at').nullable()();
  TextColumn get lastError => text().named('last_error').nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // pending|in_flight|failed|conflict
}

/// Per-table pull watermark: "select * where updated_at > lastPulledAt".
class SyncMeta extends Table {
  TextColumn get entityTable => text().named('table_name')();
  DateTimeColumn get lastPulledAt =>
      dateTime().named('last_pulled_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{entityTable};
}

/// Local mirror of the server's `sync_conflicts` table — surfaced in the UI
/// via the conflict banner / Transaction detail resolution screen.
class ConflictQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityTable => text().named('entity_table')();
  TextColumn get entityId => text().named('entity_id')();
  TextColumn get localPayload => text().named('local_payload')();
  TextColumn get serverPayload => text().named('server_payload')();
  DateTimeColumn get detectedAt => dateTime().named('detected_at')();
  DateTimeColumn get resolvedAt =>
      dateTime().named('resolved_at').nullable()();
  TextColumn get resolution => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
