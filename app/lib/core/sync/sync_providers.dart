import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient;

import '../../data/local/database.dart';
import '../providers/core_providers.dart';
import 'connectivity_service.dart';
import 'outbox/outbox_writer.dart';
import 'sync_engine.dart';

final Provider<OutboxWriter> outboxWriterProvider = Provider<OutboxWriter>((
  Ref ref,
) {
  return OutboxWriter(ref.watch(appDatabaseProvider));
});

final Provider<SyncEngine> syncEngineProvider = Provider<SyncEngine>((
  Ref ref,
) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  final SyncEngine engine = SyncEngine(
    db: ref.watch(appDatabaseProvider),
    client: client,
    currentUserId: () => client.auth.currentUser?.id,
  );
  ref.onDispose(engine.dispose);

  // Sync triggers: connectivity regained + a foreground heartbeat. App
  // start/resume and post-write kicks come from bootstrap and repositories.
  ref.listen(isOnlineProvider, (
    AsyncValue<bool>? previous,
    AsyncValue<bool> next,
  ) {
    final bool wasOnline = previous?.value ?? false;
    final bool isOnline = next.value ?? false;
    if (!wasOnline && isOnline) {
      unawaited(engine.kick());
    }
  });

  final Timer heartbeat = Timer.periodic(
    const Duration(minutes: 2),
    (_) => unawaited(engine.kick()),
  );
  ref.onDispose(heartbeat.cancel);

  return engine;
});

/// Live sync status for the diagnostics screen and banners: recomputed
/// after every sync pass and on outbox/conflict table changes.
final StreamProvider<SyncStatus> syncStatusProvider =
    StreamProvider<SyncStatus>((Ref ref) async* {
  final SyncEngine engine = ref.watch(syncEngineProvider);
  yield await engine.currentStatus();
  await for (final void _ in engine.changes) {
    yield await engine.currentStatus();
  }
});

/// Count of unresolved transaction conflicts, watched reactively from the
/// local conflict queue — drives the persistent conflict banner on Today
/// and the Money dashboard.
final StreamProvider<int> conflictCountProvider = StreamProvider<int>((
  Ref ref,
) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return (db.select(db.conflictQueue)
        ..where(($ConflictQueueTable t) => t.resolvedAt.isNull()))
      .watch()
      .map((List<ConflictQueueData> rows) => rows.length);
});
