import 'package:go_router/go_router.dart';

import '../../search/presentation/screens/search_screen.dart';
import '../../settings/presentation/screens/export_screen.dart';
import '../../settings/presentation/screens/settings_screen.dart';
import '../../settings/presentation/screens/sync_diagnostics_screen.dart';
import 'screens/trajectory_screen.dart';

/// Sub-routes mounted under the Review tab ('/review'): Settings lives here
/// because Review is the least crowded tab and there is no dedicated
/// "More" tab in the 5-tab shell.
final List<RouteBase> reviewSubRoutes = <RouteBase>[
  GoRoute(
    path: 'settings',
    builder: (_, _) => const SettingsScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: 'sync',
        builder: (_, _) => const SyncDiagnosticsScreen(),
      ),
      GoRoute(
        path: 'export',
        builder: (_, _) => const ExportScreen(),
      ),
    ],
  ),
  GoRoute(
    path: 'trajectory',
    builder: (_, _) => const TrajectoryScreen(),
  ),
  GoRoute(
    path: 'search',
    builder: (_, _) => const SearchScreen(),
  ),
];
