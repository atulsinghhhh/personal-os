import 'package:flutter/material.dart';

import '../tokens/typography.dart';

/// Builds the Material [TextTheme] from Luma's type roles: Instrument Serif
/// for the display/headline tier, Geist for everything else.
TextTheme buildAppTextTheme(Color color) {
  TextStyle c(TextStyle style) => style.copyWith(color: color);

  return TextTheme(
    displayLarge: c(AppTypography.displayLarge),
    displayMedium: c(AppTypography.displayMedium),
    displaySmall: c(AppTypography.displaySmall),
    headlineLarge: c(AppTypography.headlineLarge),
    headlineMedium: c(AppTypography.headlineLarge),
    headlineSmall: c(AppTypography.headlineSmall),
    titleLarge: c(AppTypography.titleLarge),
    titleMedium: c(AppTypography.titleMedium),
    titleSmall: c(AppTypography.sans(15, weight: FontWeight.w500)),
    bodyLarge: c(AppTypography.bodyLarge),
    bodyMedium: c(AppTypography.bodyMedium),
    bodySmall: c(AppTypography.sans(12.5)),
    labelLarge: c(AppTypography.labelLarge),
    labelMedium: c(AppTypography.labelMedium),
    labelSmall: c(AppTypography.labelSmall),
  );
}
