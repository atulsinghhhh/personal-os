import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/design_system/debug_token_gallery.dart';
import 'package:app/core/design_system/theme/app_theme_light.dart';

void main() {
  testWidgets('DebugTokenGallery renders every token section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppThemeLight(),
          home: const DebugTokenGallery(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Design Token Gallery'), findsOneWidget);
    expect(find.text('Typography'), findsOneWidget);
    expect(find.text('Semantic colors'), findsOneWidget);
  });
}
