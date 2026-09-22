import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/sync/sync_providers.dart';
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
    unawaited(ref.read(syncEngineProvider).kick());
    // If the profile stream hasn't produced a decisive answer in time,
    // proceed with what we have (offline-first: never block on network).
    _graceTimer = Timer(const Duration(seconds: 2), () => _decide(null));
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
