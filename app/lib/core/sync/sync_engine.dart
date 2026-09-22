import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/database.dart';
import 'sync_registry.dart';
import 'wire_codec.dart';

/// Overall engine state surfaced to the UI (sync diagnostics screen,
/// offline/conflict banners).
enum SyncPhase { idle, syncing, error }

class SyncStatus {
  const SyncStatus({
    required this.phase,
    required this.pendingCount,
    required this.failedCount,
    required this.conflictCount,
    this.lastSyncedAt,
    this.lastError,
  });

  final SyncPhase phase;
  final int pendingCount;
  final int failedCount;
  final int conflictCount;
  final DateTime? lastSyncedAt;
  final String? lastError;

  static const SyncStatus initial = SyncStatus(
    phase: SyncPhase.idle,
    pendingCount: 0,
    failedCount: 0,
    conflictCount: 0,
  );
}

/// Push/pull reconciler between the local Drift database and Supabase.
///
/// Push: drains `sync_outbox` FIFO. Most tables are blind upserts (last-
/// write-wins by client `updated_at`). `transactions` updates instead use a
/// conditional update on `server_updated_at`; a zero-row result means the
/// server moved since this edit was based → recorded as a conflict for
/// manual resolution, never overwritten.
///
/// Pull: per-table watermark on `updated_at` (with a small overlap window —
/// client-managed timestamps aren't strictly monotonic across devices, and
/// upserts are idempotent so re-pulling is harmless). Server rows never
/// overwrite locally-dirty rows: for LWW tables the newer `updated_at`
/// wins; dirty transactions are always left for push-time conflict
/// detection.
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required SupabaseClient client,
    required String? Function() currentUserId,
    Logger? logger,
  })  : _db = db, // ignore: prefer_initializing_formals
        _client = client, // ignore: prefer_initializing_formals
        _currentUserId = currentUserId, // ignore: prefer_initializing_formals
        _log = logger ?? Logger(printer: SimplePrinter());

  final AppDatabase _db;
  final SupabaseClient _client;
  final String? Function() _currentUserId;
  final Logger _log;

  static const Duration _pullOverlap = Duration(minutes: 5);
  static const Duration _maxBackoff = Duration(minutes: 5);

  bool _running = false;
  bool _kickQueuedWhileRunning = false;
  DateTime? _lastSyncedAt;
  String? _lastError;

  /// Emits after every sync pass; the status provider re-reads counts then.
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;
  bool get isRunning => _running;

  /// Requests a sync pass. Safe to call from anywhere, any number of times;
  /// concurrent kicks coalesce into at most one queued follow-up pass.
  Future<void> kick() async {
    if (_currentUserId() == null) return;
    if (_running) {
      _kickQueuedWhileRunning = true;
      return;
    }
    _running = true;
    try {
      await _push();
      await _pull();
      _lastSyncedAt = DateTime.now().toUtc();
      _lastError = null;
    } on Object catch (error, stackTrace) {
      _lastError = error.toString();
      _log.w('Sync pass failed', error: error, stackTrace: stackTrace);
    } finally {
      _running = false;
      _changes.add(null);
    }
    if (_kickQueuedWhileRunning) {
      _kickQueuedWhileRunning = false;
      await kick();
    }
  }

  // ---------------------------------------------------------------- push --

  Future<void> _push() async {
    final List<SyncOutboxData> rows =
        await (_db.select(_db.syncOutbox)
              ..where(($SyncOutboxTable t) => t.status.equals('pending'))
              ..orderBy(<OrderingTerm Function($SyncOutboxTable)>[
                ($SyncOutboxTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    final DateTime now = DateTime.now().toUtc();

    for (final SyncOutboxData row in rows) {
      if (!_backoffElapsed(row, now)) continue;

      final Map<String, dynamic> payload =
          jsonDecode(row.payload) as Map<String, dynamic>;

      try {
        if (row.entityTable == 'transactions' &&
            row.operation == 'update' &&
            row.baseServerUpdatedAt != null) {
          await _pushTransactionUpdate(row, payload);
        } else if (row.entityTable == 'transactions') {
          // Insert path: the server trigger stamps server_updated_at, so
          // read the row back and store it — later edits base their
          // optimistic-concurrency check on it.
          final Map<String, dynamic> upsertPayload =
              Map<String, dynamic>.of(payload)..remove('server_updated_at');
          final List<dynamic> inserted = await _client
              .from('transactions')
              .upsert(upsertPayload)
              .select();
          if (inserted.isNotEmpty) {
            await _applyServerRow(
              'transactions',
              inserted.first as Map<String, dynamic>,
              markClean: true,
            );
          }
          await (_db.delete(_db.syncOutbox)
                ..where(($SyncOutboxTable t) => t.id.equals(row.id)))
              .go();
        } else {
          await _client.from(row.entityTable).upsert(payload);
          await _completeOutboxRow(row);
        }
      } on Object catch (error) {
        await _recordPushFailure(row, error);
      }
    }
  }

  Future<void> _pushTransactionUpdate(
    SyncOutboxData row,
    Map<String, dynamic> payload,
  ) async {
    // Optimistic concurrency: only apply if the server row is still at the
    // version this edit was based on. server_updated_at is trigger-stamped,
    // so it must not be part of the update payload itself.
    final Map<String, dynamic> update = Map<String, dynamic>.of(payload)
      ..remove('server_updated_at')
      ..remove('id');

    final List<dynamic> updated = await _client
        .from('transactions')
        .update(update)
        .eq('id', row.entityId)
        .eq(
          'server_updated_at',
          WireCodec.toWireTimestamp(row.baseServerUpdatedAt!),
        )
        .select();

    if (updated.isNotEmpty) {
      final Map<String, dynamic> serverRow =
          updated.first as Map<String, dynamic>;
      await _applyServerRow('transactions', serverRow, markClean: true);
      await (_db.delete(_db.syncOutbox)
            ..where(($SyncOutboxTable t) => t.id.equals(row.id)))
          .go();
      return;
    }

    // Zero rows affected: the server moved. Surface a conflict — never
    // overwrite.
    _log.w('Transaction conflict detected for ${row.entityId}');
    final List<dynamic> serverRows = await _client
        .from('transactions')
        .select()
        .eq('id', row.entityId);
    final String serverPayload =
        serverRows.isEmpty ? '{}' : jsonEncode(serverRows.first);

    final String conflictId = const Uuid().v4();
    await _db.transaction(() async {
      await _db.into(_db.conflictQueue).insert(
            ConflictQueueCompanion.insert(
              id: conflictId,
              entityTable: 'transactions',
              entityId: row.entityId,
              localPayload: row.payload,
              serverPayload: serverPayload,
              detectedAt: DateTime.now().toUtc(),
            ),
          );
      await (_db.update(_db.transactions)
            ..where(($TransactionsTable t) => t.id.equals(row.entityId)))
          .write(
        const TransactionsCompanion(
          conflictState: Value<String>('pending_review'),
        ),
      );
      await (_db.update(_db.syncOutbox)
            ..where(($SyncOutboxTable t) => t.id.equals(row.id)))
          .write(
        const SyncOutboxCompanion(status: Value<String>('conflict')),
      );
    });

    // Best-effort server-side audit record; the local conflict_queue row is
    // the operative one.
    try {
      await _client.from('sync_conflicts').insert(<String, dynamic>{
        'id': conflictId,
        'user_id': _currentUserId(),
        'entity_table': 'transactions',
        'entity_id': row.entityId,
        'local_payload': jsonDecode(row.payload),
        'server_payload': jsonDecode(serverPayload),
      });
    } on Object catch (error) {
      _log.w('Failed to record server-side conflict audit', error: error);
    }
  }

  bool _backoffElapsed(SyncOutboxData row, DateTime now) {
    if (row.attemptCount == 0 || row.lastAttemptAt == null) return true;
    final Duration backoff = Duration(
      seconds: math.min(
        math.pow(2, row.attemptCount).toInt() * 2,
        _maxBackoff.inSeconds,
      ),
    );
    return now.isAfter(row.lastAttemptAt!.add(backoff));
  }

  Future<void> _completeOutboxRow(SyncOutboxData row) async {
    await _db.transaction(() async {
      await (_db.delete(_db.syncOutbox)
            ..where(($SyncOutboxTable t) => t.id.equals(row.id)))
          .go();
      await _markEntityClean(row.entityTable, row.entityId);
    });
  }

  Future<void> _markEntityClean(String tableName, String entityId) async {
    final TableInfo<Table, dynamic> table = driftTableByName(_db, tableName);
    final GeneratedColumn<Object>? dirtyColumn =
        table.columnsByName['is_dirty'];
    if (dirtyColumn == null) return;
    final GeneratedColumn<String> idColumn =
        table.columnsByName['id']! as GeneratedColumn<String>;

    await (_db.update(table)..where((_) => idColumn.equals(entityId))).write(
      RawValuesInsertable<Never>(<String, Expression<Object>>{
        'is_dirty': const Constant<bool>(false),
      }),
    );
  }

  Future<void> _recordPushFailure(SyncOutboxData row, Object error) async {
    final bool permanent = error is PostgrestException &&
        error.code != null &&
        !error.code!.startsWith('5') &&
        error.code != '429';

    _log.w(
      'Push failed for ${row.entityTable}/${row.entityId} '
      '(attempt ${row.attemptCount + 1}, permanent: $permanent)',
      error: error,
    );

    await (_db.update(_db.syncOutbox)
          ..where(($SyncOutboxTable t) => t.id.equals(row.id)))
        .write(
      SyncOutboxCompanion(
        attemptCount: Value<int>(row.attemptCount + 1),
        lastAttemptAt: Value<DateTime?>(DateTime.now().toUtc()),
        lastError: Value<String?>(error.toString()),
        status: Value<String>(permanent ? 'failed' : 'pending'),
      ),
    );
  }

  // ---------------------------------------------------------------- pull --

  Future<void> _pull() async {
    final String? userId = _currentUserId();
    if (userId == null) return;

    for (final SyncTableSpec spec in syncTables) {
      final DateTime? watermark = await _watermarkFor(spec.tableName);

      PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _client
          .from(spec.tableName)
          .select()
          .eq('user_id', userId);
      if (watermark != null) {
        query = query.gt(
          spec.watermarkColumn,
          WireCodec.toWireTimestamp(watermark.subtract(_pullOverlap)),
        );
      }

      final List<Map<String, dynamic>> rows =
          await query.order(spec.watermarkColumn, ascending: true).limit(500);
      if (rows.isEmpty) continue;

      DateTime newWatermark = watermark ?? DateTime.utc(1970);
      for (final Map<String, dynamic> wire in rows) {
        await _applyPulledRow(spec, wire);
        final DateTime rowUpdated =
            DateTime.parse(wire[spec.watermarkColumn] as String).toUtc();
        if (rowUpdated.isAfter(newWatermark)) newWatermark = rowUpdated;
      }

      await _db.into(_db.syncMeta).insertOnConflictUpdate(
            SyncMetaCompanion.insert(
              entityTable: spec.tableName,
              lastPulledAt: Value<DateTime?>(newWatermark),
            ),
          );
    }
  }

  Future<void> _applyPulledRow(
    SyncTableSpec spec,
    Map<String, dynamic> wire,
  ) async {
    final String entityId = wire['id'] as String;
    final TableInfo<Table, dynamic> table =
        driftTableByName(_db, spec.tableName);

    final bool localIsDirty = await _isLocallyDirty(table, entityId);

    if (!localIsDirty) {
      await _applyServerRow(spec.tableName, wire, markClean: true);
      return;
    }

    if (spec.policy == ConflictPolicy.manualResolve) {
      // Dirty local transaction: leave it — the push path's conditional
      // update is the single place transaction conflicts are detected.
      return;
    }

    // LWW with a dirty local row: newer client edit time wins. Tables
    // without updated_at (immutable link rows) just take the server copy.
    if (wire['updated_at'] == null) {
      await _applyServerRow(spec.tableName, wire, markClean: true);
      return;
    }
    final DateTime serverUpdated =
        DateTime.parse(wire['updated_at'] as String).toUtc();
    final DateTime? localUpdated = await _localUpdatedAt(table, entityId);
    if (localUpdated != null && localUpdated.isAfter(serverUpdated)) {
      return; // local pending edit is newer; push will overwrite server
    }

    // Server wins: apply and drop the superseded local pending pushes.
    await _db.transaction(() async {
      await _applyServerRow(spec.tableName, wire, markClean: true);
      await (_db.delete(_db.syncOutbox)..where(
            ($SyncOutboxTable t) =>
                t.entityId.equals(entityId) &
                t.entityTable.equals(spec.tableName) &
                t.status.equals('pending'),
          ))
          .go();
    });
  }

  Future<void> _applyServerRow(
    String tableName,
    Map<String, dynamic> wire, {
    required bool markClean,
  }) async {
    final TableInfo<Table, dynamic> table = driftTableByName(_db, tableName);
    await _db
        .into(table)
        .insertOnConflictUpdate(
          WireCodec.wireToInsertable(table, wire, markClean: markClean),
        );
  }

  Future<bool> _isLocallyDirty(
    TableInfo<Table, dynamic> table,
    String entityId,
  ) async {
    if (!table.columnsByName.containsKey('is_dirty')) return false;
    final QueryRow? row = await _db
        .customSelect(
          'SELECT is_dirty FROM ${table.actualTableName} WHERE id = ?',
          variables: <Variable<Object>>[Variable<String>(entityId)],
        )
        .getSingleOrNull();
    return row?.read<bool>('is_dirty') ?? false;
  }

  Future<DateTime?> _localUpdatedAt(
    TableInfo<Table, dynamic> table,
    String entityId,
  ) async {
    if (!table.columnsByName.containsKey('updated_at')) return null;
    final QueryRow? row = await _db
        .customSelect(
          'SELECT updated_at FROM ${table.actualTableName} WHERE id = ?',
          variables: <Variable<Object>>[Variable<String>(entityId)],
        )
        .getSingleOrNull();
    return row?.readNullable<DateTime>('updated_at')?.toUtc();
  }

  Future<DateTime?> _watermarkFor(String tableName) async {
    final SyncMetaData? meta = await (_db.select(_db.syncMeta)
          ..where(($SyncMetaTable t) => t.entityTable.equals(tableName)))
        .getSingleOrNull();
    return meta?.lastPulledAt;
  }

  // ------------------------------------------------------------- status --

  Future<SyncStatus> currentStatus() async {
    final int pending = await _countOutbox('pending');
    final int failed = await _countOutbox('failed');
    final int conflicts = await (_db.select(_db.conflictQueue)
          ..where(($ConflictQueueTable t) => t.resolvedAt.isNull()))
        .get()
        .then((List<ConflictQueueData> rows) => rows.length);

    return SyncStatus(
      phase: _running
          ? SyncPhase.syncing
          : (_lastError != null ? SyncPhase.error : SyncPhase.idle),
      pendingCount: pending,
      failedCount: failed,
      conflictCount: conflicts,
      lastSyncedAt: _lastSyncedAt,
      lastError: _lastError,
    );
  }

  Future<int> _countOutbox(String status) async {
    final List<SyncOutboxData> rows = await (_db.select(_db.syncOutbox)
          ..where(($SyncOutboxTable t) => t.status.equals(status)))
        .get();
    return rows.length;
  }

  void dispose() {
    _changes.close();
  }
}
