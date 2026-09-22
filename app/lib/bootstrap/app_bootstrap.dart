import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Ordered startup: initialize the Supabase client (auth session restore
/// happens automatically inside `Supabase.initialize`) before `runApp`.
/// The local Drift database is opened lazily by its own provider — no
/// explicit init needed here.
Future<void> bootstrapApp() async {
  if (!Env.isConfigured) {
    throw StateError(
      'Supabase env not configured. Run with '
      '--dart-define-from-file=env/local.json (see env/local.example.json).',
    );
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
}
