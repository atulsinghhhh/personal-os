import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient;

import '../../features/future/data/future_repositories_impl.dart';
import '../../features/future/domain/repositories/future_repositories.dart';
import '../../features/settings/data/profile_repository.dart';
import '../../shared/models/profile.dart';
import '../sync/sync_providers.dart';
import 'core_providers.dart';

/// One place to construct every repository implementation: Drift + outbox +
/// a post-write sync kick. New feature repos register here.

void Function() _kicker(Ref ref) {
  return () => unawaited(ref.read(syncEngineProvider).kick());
}

final Provider<LifeAreaRepository> lifeAreaRepositoryProvider =
    Provider<LifeAreaRepository>((Ref ref) {
  return DriftLifeAreaRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<VisionRepository> visionRepositoryProvider =
    Provider<VisionRepository>((Ref ref) {
  return DriftVisionRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>((Ref ref) {
  return ProfileRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(outboxWriterProvider),
    _kicker(ref),
  );
});

/// The signed-in user's profile, watched from the local database.
final StreamProvider<Profile?> currentProfileProvider =
    StreamProvider<Profile?>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  final String? userId = client.auth.currentUser?.id;
  if (userId == null) return Stream<Profile?>.value(null);
  return ref.watch(profileRepositoryProvider).watch(userId);
});
