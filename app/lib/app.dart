import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/design_system/debug_token_gallery.dart';
import 'core/design_system/theme/app_theme_dark.dart';
import 'core/design_system/theme/app_theme_light.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/sign_in_screen.dart';

/// Root widget. [_AuthGate] below is a placeholder for the real navigation
/// shell (splash -> onboarding/auth -> 5-tab app via go_router), built in a
/// later step; today it just proves the auth flow works end-to-end by
/// showing sign-in when signed out and the token gallery when signed in.
class PersonalOsApp extends StatelessWidget {
  const PersonalOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal OS',
      debugShowCheckedModeBanner: false,
      theme: buildAppThemeLight(),
      darkTheme: buildAppThemeDark(),
      themeMode: ThemeMode.system,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? user = ref.watch(currentUserProvider);
    return user == null ? const SignInScreen() : const DebugTokenGallery();
  }
}
