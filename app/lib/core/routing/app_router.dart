import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/future/presentation/screens/future_overview_screen.dart';
import '../../features/money/presentation/screens/money_dashboard_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/planning/presentation/screens/plan_screen.dart';
import '../../features/review/presentation/screens/review_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/today/presentation/screens/today_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../providers/core_providers.dart';
import 'app_shell.dart';
import 'go_router_refresh_stream.dart';
import 'route_paths.dart';

/// The app's single [GoRouter], kept alive for the app's lifetime. Redirect
/// logic is the auth guard: signed-out users can only reach sign-in/sign-up,
/// signed-in users are bounced off those (and splash) to Today. Onboarding
/// completion is not yet gated here — that's added once the profile
/// repository exists (see the onboarding build step).
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final GoRouterRefreshStream refresh = GoRouterRefreshStream(
    ref.watch(supabaseClientProvider).auth.onAuthStateChange,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refresh,
    redirect: (_, GoRouterState state) {
      final bool signedIn =
          ref.read(supabaseClientProvider).auth.currentSession != null;
      final String location = state.matchedLocation;
      final bool goingToAuth =
          location == RoutePaths.signIn || location == RoutePaths.signUp;

      if (!signedIn) {
        return goingToAuth ? null : RoutePaths.signIn;
      }
      if (goingToAuth || location == RoutePaths.splash) {
        return RoutePaths.today;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.signIn,
        builder: (_, _) => const SignInScreen(),
      ),
      GoRoute(
        path: RoutePaths.signUp,
        builder: (_, _) => const SignUpScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, StatefulNavigationShell shell) =>
            AppShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RoutePaths.today,
                builder: (_, _) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RoutePaths.plan,
                builder: (_, _) => const PlanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RoutePaths.future,
                builder: (_, _) => const FutureOverviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RoutePaths.money,
                builder: (_, _) => const MoneyDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: RoutePaths.review,
                builder: (_, _) => const ReviewScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
