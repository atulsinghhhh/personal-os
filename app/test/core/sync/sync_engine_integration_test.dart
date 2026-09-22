@Tags(<String>['integration'])
library;

import 'dart:convert';

import 'package:app/core/sync/outbox/outbox_writer.dart';
import 'package:app/core/sync/sync_engine.dart';
import 'package:app/core/sync/wire_codec.dart';
import 'package:app/data/local/database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Integration tests against the LOCAL Supabase stack (`supabase start`
/// must be running). Validates the sync engine end-to-end on one LWW
/// entity (life_areas) and the transaction conflict path, per the plan's
/// "validate the pattern against one entity before wiring every feature".
///
/// Run: flutter test test/core/sync/sync_engine_integration_test.dart
const String supabaseUrl = 'http://127.0.0.1:54321';
const String publishableKey = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';

void main() {
  late SupabaseClient client;
  late AppDatabase db;
  late SyncEngine engine;
  late OutboxWriter outbox;
  late String userId;

  setUpAll(() async {
    client = SupabaseClient(
      supabaseUrl,
      publishableKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
    final String email =
        'sync-test-${DateTime.now().millisecondsSinceEpoch}@example.com';
    final AuthResponse response = await client.auth.signUp(
      email: email,
      password: 'SyncTest123!',
    );
    userId = response.user!.id;
  });

  tearDownAll(() async {
    await client.auth.signOut();
    await client.dispose();
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    outbox = OutboxWriter(db);
    engine = SyncEngine(
      db: db,
      client: client,
      currentUserId: () => userId,
    );
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  Map<String, dynamic> lifeAreaWire(String id, String name, DateTime now) {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'name': name,
      'color': '#2D5BFF',
      'icon': null,
      'sort_order': 0,
      'created_at': WireCodec.toWireTimestamp(now),
      'updated_at': WireCodec.toWireTimestamp(now),
      'deleted_at': null,
    };
  }

  test('push: locally created LifeArea lands in Supabase and is marked clean',
      () async {
    final String id = const Uuid().v4();
    final DateTime now = DateTime.now().toUtc();

    await db.transaction(() async {
      await db.into(db.lifeAreas).insert(
            LifeAreasCompanion.insert(
              id: id,
              userId: userId,
              name: 'Health',
              createdAt: now,
              updatedAt: now,
              isDirty: const Value<bool>(true),
            ),
          );
      await outbox.enqueue(
        entityTable: 'life_areas',
        entityId: id,
        operation: 'insert',
        payload: lifeAreaWire(id, 'Health', now),
      );
    });

    await engine.kick();

    final List<dynamic> remote =
        await client.from('life_areas').select().eq('id', id);
    expect(remote, hasLength(1));
    expect((remote.single as Map<String, dynamic>)['name'], 'Health');

    final LifeArea local = await (db.select(db.lifeAreas)
          ..where(($LifeAreasTable t) => t.id.equals(id)))
        .getSingle();
    expect(local.isDirty, isFalse);

    final List<SyncOutboxData> remaining =
        await db.select(db.syncOutbox).get();
    expect(remaining, isEmpty);
  });

  test('pull: server-side LifeArea appears locally after a sync pass',
      () async {
    final String id = const Uuid().v4();
    final DateTime now = DateTime.now().toUtc();
    await client.from('life_areas').insert(lifeAreaWire(id, 'Career', now));

    await engine.kick();

    final LifeArea? local = await (db.select(db.lifeAreas)
          ..where(($LifeAreasTable t) => t.id.equals(id)))
        .getSingleOrNull();
    expect(local, isNotNull);
    expect(local!.name, 'Career');
    expect(local.isDirty, isFalse);
  });

  test(
      'transaction conflict: concurrent server edit is surfaced, never '
      'silently overwritten', () async {
    final String accountId = const Uuid().v4();
    final String txnId = const Uuid().v4();
    final DateTime now = DateTime.now().toUtc();

    // Server-side account + transaction (as if created by another device).
    await client.from('financial_accounts').insert(<String, dynamic>{
      'id': accountId,
      'user_id': userId,
      'name': 'Cash',
      'type': 'cash',
      'currency': 'INR',
      'created_at': WireCodec.toWireTimestamp(now),
      'updated_at': WireCodec.toWireTimestamp(now),
    });
    await client.from('transactions').insert(<String, dynamic>{
      'id': txnId,
      'user_id': userId,
      'account_id': accountId,
      'kind': 'expense',
      'amount': 100,
      'currency': 'INR',
      'occurred_at': WireCodec.toWireTimestamp(now),
      'client_updated_at': WireCodec.toWireTimestamp(now),
      'created_at': WireCodec.toWireTimestamp(now),
      'updated_at': WireCodec.toWireTimestamp(now),
    });

    // Pull it locally, capturing the server-stamped server_updated_at.
    await engine.kick();
    final Transaction pulled = await (db.select(db.transactions)
          ..where(($TransactionsTable t) => t.id.equals(txnId)))
        .getSingle();

    // Another device edits the amount on the server AFTER our pull.
    await client
        .from('transactions')
        .update(<String, dynamic>{'amount': 250}).eq('id', txnId);

    // Meanwhile we edit the same transaction locally, based on the stale
    // server_updated_at.
    final DateTime editTime = DateTime.now().toUtc();
    await db.transaction(() async {
      await (db.update(db.transactions)
            ..where(($TransactionsTable t) => t.id.equals(txnId)))
          .write(
        TransactionsCompanion(
          amount: const Value<double>(175),
          isDirty: const Value<bool>(true),
          updatedAt: Value<DateTime>(editTime),
        ),
      );
      await outbox.enqueue(
        entityTable: 'transactions',
        entityId: txnId,
        operation: 'update',
        payload: <String, dynamic>{
          'id': txnId,
          'user_id': userId,
          'account_id': accountId,
          'kind': 'expense',
          'amount': 175,
          'currency': 'INR',
          'occurred_at': WireCodec.toWireTimestamp(now),
          'client_updated_at': WireCodec.toWireTimestamp(editTime),
          'updated_at': WireCodec.toWireTimestamp(editTime),
        },
        baseServerUpdatedAt: pulled.serverUpdatedAt,
      );
    });

    await engine.kick();

    // The push must NOT have overwritten the server amount.
    final List<dynamic> remote =
        await client.from('transactions').select().eq('id', txnId);
    expect((remote.single as Map<String, dynamic>)['amount'], 250.0);

    // A conflict must be queued locally, with both versions.
    final List<ConflictQueueData> conflicts =
        await db.select(db.conflictQueue).get();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.entityId, txnId);
    final Map<String, dynamic> localVersion =
        jsonDecode(conflicts.single.localPayload) as Map<String, dynamic>;
    final Map<String, dynamic> serverVersion =
        jsonDecode(conflicts.single.serverPayload) as Map<String, dynamic>;
    expect(localVersion['amount'], 175);
    expect(serverVersion['amount'], 250.0);

    // The local row is flagged for review, and the outbox row is parked in
    // 'conflict' (not retried, not dropped).
    final Transaction local = await (db.select(db.transactions)
          ..where(($TransactionsTable t) => t.id.equals(txnId)))
        .getSingle();
    expect(local.conflictState, 'pending_review');

    final List<SyncOutboxData> parked = await (db.select(db.syncOutbox)
          ..where(($SyncOutboxTable t) => t.status.equals('conflict')))
        .get();
    expect(parked, hasLength(1));
  });
}
