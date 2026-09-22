import 'package:flutter/material.dart';

/// Luma type scale. Instrument Serif 400 for titles and big numbers,
/// Geist for everything else, tabular numerals throughout
/// (the design sets `font-variant-numeric: tabular-nums` on every screen).
abstract final class AppTypography {
  static const String serifFamily = 'Instrument Serif';
  static const String sansFamily = 'Geist';

  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle serif(double size, {double? height, Color? color}) =>
      TextStyle(
        fontFamily: serifFamily,
        fontSize: size,
        height: height,
        fontWeight: FontWeight.w400,
        letterSpacing: size * -0.01,
        color: color,
        fontFeatures: _tabular,
      );

  static TextStyle sans(
    double size, {
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: sansFamily,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
        fontFeatures: _tabular,
      );

  // Display roles — Instrument Serif (type.title / heroTask / reflection).
  static final TextStyle displayLarge = serif(44, height: 1.04);
  static final TextStyle displayMedium = serif(38, height: 1.05);
  static final TextStyle displaySmall = serif(36, height: 1.05);
  static final TextStyle headlineLarge = serif(30, height: 1.08);
  static final TextStyle headlineSmall = serif(22, height: 1.15);

  // Text roles — Geist.
  static final TextStyle titleLarge = sans(18, weight: FontWeight.w600);
  static final TextStyle titleMedium = sans(16, weight: FontWeight.w500);
  static final TextStyle bodyLarge = sans(16, height: 1.5);
  static final TextStyle bodyMedium = sans(15, height: 1.45);
  static final TextStyle labelLarge = sans(15, weight: FontWeight.w600);
  static final TextStyle labelMedium = sans(12.5, weight: FontWeight.w500);

  /// Eyebrow: 11px uppercase with 0.08em tracking.
  static final TextStyle labelSmall =
      sans(11, weight: FontWeight.w500, letterSpacing: 11 * 0.08);

  /// Big balances (account/goal totals) — serif like the design's metrics.
  static final TextStyle currencyLarge = serif(34, height: 1.08);

  /// Transaction-row-scale amounts.
  static final TextStyle currencyMedium = sans(15, weight: FontWeight.w500);
}
