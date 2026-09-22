import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/luma/theme/tokens.dart';
import 'package:app/luma/widgets/luma_logo.dart';

/// Not a real test — a generator. Renders the Luma app icon masters from the
/// design's Brand section into assets/icon/ via the golden-file mechanism:
///
///   flutter test test/tools/app_icon_golden_test.dart --update-goldens
///
/// app_icon.png       — 1024 dark tile (iOS/legacy Android)
/// app_icon_fg.png    — mark on transparent, safe-zone inset (Android adaptive)
void main() {
  testWidgets('render app icon masters', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;

    // Full icon: dark tile, mark at 64/120 of the tile like the design's
    // 120px master (28px padding around a 64px mark).
    await tester.pumpWidget(
      const _IconCanvas(
        background: LumaColors.ink,
        markSize: 1024 * 64 / 120,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(_IconCanvas),
      matchesGoldenFile('../../assets/icon/app_icon.png'),
    );

    // Adaptive foreground: transparent, mark inside the ~66% safe zone.
    await tester.pumpWidget(
      const _IconCanvas(
        background: Colors.transparent,
        markSize: 1024 * 0.52,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(_IconCanvas),
      matchesGoldenFile('../../assets/icon/app_icon_fg.png'),
    );
  });
}

class _IconCanvas extends StatelessWidget {
  const _IconCanvas({required this.background, required this.markSize});

  final Color background;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Container(
        width: 1024,
        height: 1024,
        color: background,
        child: Center(
          child: LumaLogo(
            size: markSize,
            stroke: LumaColors.ground,
            sun: LumaColors.darkAccent,
          ),
        ),
      ),
    );
  }
}
