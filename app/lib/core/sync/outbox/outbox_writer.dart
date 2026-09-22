import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/local/database.dart';

/// Enqueues sync work. Repositories call [enqueue] INSIDE the same Drift
/// transaction as their entity write so the entity change and its outbox
/// row commit atomically — a crash can never leave one without the other.
class OutboxWriter {
  const OutboxWriter(this._db);

  final AppDatabase _db;

  /// [payload] must be in wire format (snake_case keys, ISO 8601
  /// timestamps) — it is pushed to Supabase verbatim.
  /// [baseServerUpdatedAt] is only meaningful for `transactions` updates:
  /// the server_updated_at the edit was based on, used for the conditional
  /// optimistic-concurrency push.
  Future<void> enqueue({
    required String entityTable,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    DateTime? baseServerUpdatedAt,
  }) async {
    // Supersede any still-pending row for the same entity IN PLACE: the new
    // payload is a full row snapshot, so pushing the stale intermediate
    // state is wasted work — but the row must keep its original queue
    // position, otherwise a superseded parent (e.g. a task edited after a
    // focus session referencing it was queued) would push AFTER its
    // children and hit foreign-key violations server-side. If the pending
    // row was an insert, it stays an insert (the row doesn't exist
    // server-side yet). Conflict/in-flight rows are left alone.
    final SyncOutboxData? pending = await (_db.select(_db.syncOutbox)
          ..where(
            ($SyncOutboxTable t) =>
                t.entityId.equals(entityId) &
                t.entityTable.equals(entityTable) &
                t.status.equals('pending'),
          )
          ..limit(1))
        .getSingleOrNull();

    if (pending != null) {
      await (_db.update(_db.syncOutbox)
            ..where(($SyncOutboxTable t) => t.id.equals(pending.id)))
          .write(
        SyncOutboxCompanion(
          operation: Value<String>(
            pending.operation == 'insert' ? 'insert' : operation,
          ),
          payload: Value<String>(jsonEncode(payload)),
          baseServerUpdatedAt: Value<DateTime?>(
            baseServerUpdatedAt ?? pending.baseServerUpdatedAt,
          ),
          attemptCount: const Value<int>(0),
          lastError: const Value<String?>(null),
        ),
      );
      return;
    }

    await _db
        .into(_db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            entityTable: entityTable,
            entityId: entityId,
            operation: operation,
            payload: jsonEncode(payload),
            baseServerUpdatedAt: Value<DateTime?>(baseServerUpdatedAt),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }
}
