import 'package:flutter/material.dart';

/// Brand seed and semantic color roles Material 3's [ColorScheme] doesn't
/// cover (financial signal colors, life-area accents). [ColorScheme] itself
/// is derived via `ColorScheme.fromSeed` in app_theme_light/dark.dart; the
/// explicit overrides below exist because a seeded scheme alone can't
/// guarantee brand-correct surface-container tones or the exact semantic
/// hues a finance app needs (income/expense/warning/conflict).
abstract final class AppColors {
  static const Color brandSeed = Color(0xFF2D5BFF);

  // Light scheme overrides
  static const Color lightSurfaceContainer = Color(0xFFF2F3F7);
  static const Color lightSurfaceContainerHigh = Color(0xFFE8EAF0);
  static const Color lightBackground = Color(0xFFFAFAFC);
  static const Color lightOutline = Color(0xFFC4C7CE);

  // Dark scheme overrides
  static const Color darkSurfaceContainer = Color(0xFF1D1F23);
  static const Color darkSurfaceContainerHigh = Color(0xFF26282D);
  static const Color darkBackground = Color(0xFF0F1012);
  static const Color darkOutline = Color(0xFF8B8F99);

  // Semantic signal colors (income/expense/warning/conflict), light + dark.
  static const Color incomeLight = Color(0xFF1B8A5A);
  static const Color incomeDark = Color(0xFF6FD79B);
  static const Color expenseLight = Color(0xFFC4432B);
  static const Color expenseDark = Color(0xFFFF8A6B);
  static const Color warningLight = Color(0xFFB8860B);
  static const Color warningDark = Color(0xFFF2C744);
  static const Color conflictLight = Color(0xFFD32F2F);
  static const Color conflictDark = Color(0xFFFF6B6B);

  /// Assignable life-area accent swatches (8 presets), same in both themes.
  static const List<Color> lifeAreaAccents = <Color>[
    Color(0xFF2D5BFF),
    Color(0xFF7C4DFF),
    Color(0xFFFF6D9E),
    Color(0xFFFF8A3D),
    Color(0xFF2BB673),
    Color(0xFF26C6DA),
    Color(0xFF8D6E63),
    Color(0xFF78909C),
  ];
}
