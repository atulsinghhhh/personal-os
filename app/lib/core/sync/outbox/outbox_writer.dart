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
    // Supersede any still-pending rows for the same entity: the new payload
    // is a full row snapshot, so pushing stale intermediate states is
    // wasted work (conflict/in-flight rows are left alone).
    await (_db.delete(_db.syncOutbox)..where(
          ($SyncOutboxTable t) =>
              t.entityId.equals(entityId) &
              t.entityTable.equals(entityTable) &
              t.status.equals('pending'),
        ))
        .go();

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
