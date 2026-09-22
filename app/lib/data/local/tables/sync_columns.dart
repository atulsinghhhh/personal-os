import 'package:drift/drift.dart';

/// Shared columns for every entity table that participates in offline sync:
/// a client-generated uuid [id], the owning [userId], client-managed
/// [createdAt]/[updatedAt] (updatedAt reflects the user's actual edit time,
/// not sync-arrival time — see docs/architecture.md), a soft-delete
/// [deletedAt] tombstone, and [isDirty]/[localUpdatedAt] which the sync
/// engine uses to know a row has local changes not yet pushed.
mixin SyncableColumns on Table {
  TextColumn get id => text()();
  TextColumn get userId => text().named('user_id')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  BoolColumn get isDirty =>
      boolean().named('is_dirty').withDefault(const Constant(false))();
  DateTimeColumn get localUpdatedAt =>
      dateTime().named('local_updated_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
