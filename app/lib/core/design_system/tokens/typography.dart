import 'package:flutter/material.dart';

/// Type scale (Material 3 roles + two custom currency roles). Values are
/// color-agnostic; color is applied by the active [ThemeData]/[ColorScheme].
abstract final class AppTypography {
  // No custom font family is bundled in Phase 1 — ThemeData uses the
  // platform default (Roboto/San Francisco) so every style below renders
  // consistently without shipping font assets.

  static const TextStyle displayLarge = TextStyle(
    fontSize: 36,
    height: 44 / 36,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w500,
  );

  /// Big balances (account/goal totals). Tabular figures keep digits
  /// aligned when the value updates.
  static const TextStyle currencyLarge = TextStyle(
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w700,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Transaction-row-scale amounts.
  static const TextStyle currencyMedium = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}
