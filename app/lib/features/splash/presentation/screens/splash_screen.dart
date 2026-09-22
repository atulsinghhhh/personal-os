import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../features/settings/data/profile_repository.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/luma_logo.dart';
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

    // Design 01 "Splash": brand lockup centered, privacy note at the bottom.
    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LumaLogo(size: 76),
                const SizedBox(height: 22),
                Text('Luma', style: lumaSerif(size: 40, height: 1)),
                const SizedBox(height: 22),
                Text(
                  'PLAN · DO · REVIEW',
                  style: lumaSans(
                    size: 13,
                    color: LumaColors.ink3,
                    letterSpacing: 13 * 0.08,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LumaIcon(LumaIcons.lock,
                    size: 14, color: LumaColors.ink3),
                const SizedBox(width: 8),
                Text('Private by design',
                    style: lumaSans(size: 12.5, color: LumaColors.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
