import 'package:flutter/material.dart';

/// Luma palette from design/luma-design.html `<script id="luma-tokens">`.
/// A warm paper ground, near-black ink, one indigo accent, and four
/// semantic signal colors. [ColorScheme] is assembled from these in
/// app_theme_light/dark.dart.
abstract final class AppColors {
  static const Color brandSeed = Color(0xFF2F4F8F);

  // Light (color.light)
  static const Color ground = Color(0xFFF5F3EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color sunken = Color(0xFFEAE7E0);
  static const Color hairline = Color(0xFFE1DDD4);
  static const Color ink = Color(0xFF1B1B19);
  static const Color ink2 = Color(0xFF57544D);
  static const Color ink3 = Color(0xFF6F6B62);
  static const Color accent = Color(0xFF2F4F8F);
  static const Color accentSoft = Color(0xFFE3E8F2);

  // Dark (color.dark)
  static const Color darkGround = Color(0xFF121211);
  static const Color darkSurface = Color(0xFF1C1C1A);
  static const Color darkHairline = Color(0xFF2B2A27);
  static const Color darkInk = Color(0xFFEEECE6);
  static const Color darkInk2 = Color(0xFFA9A69D);
  static const Color darkAccent = Color(0xFF94ABDD);

  // Kept aliases used by existing screens.
  static const Color lightSurfaceContainer = surface;
  static const Color lightSurfaceContainerHigh = sunken;
  static const Color lightBackground = ground;
  static const Color lightOutline = hairline;

  static const Color darkSurfaceContainer = darkSurface;
  static const Color darkSurfaceContainerHigh = Color(0xFF232321);
  static const Color darkBackground = darkGround;
  static const Color darkOutline = darkHairline;

  // Semantic signal colors (color.semantic): income/positive,
  // expense/negative, warning; conflict reuses negative.
  static const Color incomeLight = Color(0xFF2E7250);
  static const Color incomeDark = Color(0xFF6FB893);
  static const Color expenseLight = Color(0xFFA33F2B);
  static const Color expenseDark = Color(0xFFD98871);
  static const Color warningLight = Color(0xFF8E6210);
  static const Color warningDark = Color(0xFFC9A45C);
  static const Color conflictLight = Color(0xFFA33F2B);
  static const Color conflictDark = Color(0xFFD98871);

  /// Assignable life-area accent swatches. Luma is monochrome + one accent,
  /// so these stay in the same muted register as the core palette.
  static const List<Color> lifeAreaAccents = <Color>[
    Color(0xFF2F4F8F),
    Color(0xFF2E7250),
    Color(0xFF8E6210),
    Color(0xFFA33F2B),
    Color(0xFF57544D),
    Color(0xFF4E6E58),
    Color(0xFF6E5A8E),
    Color(0xFF6F6B62),
  ];
}
