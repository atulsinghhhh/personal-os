import 'package:flutter/material.dart';

import 'core/design_system/debug_token_gallery.dart';
import 'core/design_system/theme/app_theme_dark.dart';
import 'core/design_system/theme/app_theme_light.dart';

/// Root widget. Today this just wires up the theme and shows the token
/// gallery so both themes can be verified visually; the navigation shell
/// (splash -> onboarding/auth -> 5-tab app) replaces [home] in a later step.
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
      home: const DebugTokenGallery(),
    );
  }
}
