import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../features/settings/data/profile_repository.dart';
import '../../../../shared/models/profile.dart';

/// Decides where a signed-in user lands: onboarding if their profile hasn't
/// completed it, Today otherwise. Kicks a sync first so a fresh install on
/// a second device can pull the existing profile; waits at most a short
/// grace period so the app still opens instantly offline.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _graceTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Fast path: the local DB already has the profile (any repeat launch) —
    // ref.listen in build fires almost immediately. Slow path: fresh
    // install, so wait for the first full sync pass to pull the profile
    // before deciding. Fallback timer covers the offline-fresh-install case.
    unawaited(
      ref.read(syncEngineProvider).kick().then((_) async {
        // The widget may have unmounted (fast path already navigated);
        // touching ref then throws.
        if (!mounted || _navigated) return;
        final String? userId = ref
            .read(supabaseClientProvider)
            .auth
            .currentUser
            ?.id;
        if (userId == null) return;
        final ProfileRepository profiles =
            ref.read(profileRepositoryProvider);
        final Profile? profile = await profiles.get(userId);
        if (mounted) _decide(profile);
      }),
    );
    _graceTimer = Timer(const Duration(seconds: 8), () => _decide(null));
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  void _decide(Profile? profile) {
    if (_navigated || !mounted) return;
    _navigated = true;
    final bool onboarded = profile?.onboardingCompletedAt != null;
    context.go(onboarded ? RoutePaths.today : RoutePaths.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentProfileProvider, (
      AsyncValue<Profile?>? previous,
      AsyncValue<Profile?> next,
    ) {
      final Profile? profile = next.value;
      if (profile != null) _decide(profile);
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
