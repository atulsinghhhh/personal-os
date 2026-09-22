import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/local/database.dart';

/// The Supabase client, initialized in bootstrap/app_bootstrap.dart before
/// runApp. Feature repositories (built in a later step) read this to push/
/// pull through SyncEngine — the UI itself never talks to this directly.
final Provider<SupabaseClient> supabaseClientProvider =
    Provider<SupabaseClient>((Ref ref) => Supabase.instance.client);

/// The local-first source of truth. Kept alive for the app's lifetime and
/// disposed when the provider container is disposed (app shutdown/tests).
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((
  Ref ref,
) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
