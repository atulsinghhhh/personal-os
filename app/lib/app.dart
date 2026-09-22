import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/design_system/theme/app_theme_dark.dart';
import 'core/design_system/theme/app_theme_light.dart';
import 'core/routing/app_router.dart';

class PersonalOsApp extends ConsumerWidget {
  const PersonalOsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Personal OS',
      debugShowCheckedModeBanner: false,
      theme: buildAppThemeLight(),
      darkTheme: buildAppThemeDark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
