import 'package:flutter/material.dart';

import '../tokens/typography.dart';

/// Builds a full Material [TextTheme] from [AppTypography]'s roles, filling
/// the handful of Material roles we don't define a custom value for
/// (displayMedium/Small, headlineMedium, titleSmall, bodySmall) by
/// interpolating between adjacent defined roles so every default Text/
/// widget still renders sensibly without needing an explicit style.
TextTheme buildAppTextTheme(Color color) {
  TextStyle c(TextStyle style) => style.copyWith(color: color);

  return TextTheme(
    displayLarge: c(AppTypography.displayLarge),
    displayMedium: c(AppTypography.headlineLarge),
    displaySmall: c(AppTypography.headlineSmall),
    headlineLarge: c(AppTypography.headlineLarge),
    headlineMedium: c(AppTypography.headlineSmall),
    headlineSmall: c(AppTypography.headlineSmall),
    titleLarge: c(AppTypography.titleLarge),
    titleMedium: c(AppTypography.titleMedium),
    titleSmall: c(AppTypography.labelLarge),
    bodyLarge: c(AppTypography.bodyLarge),
    bodyMedium: c(AppTypography.bodyMedium),
    bodySmall: c(AppTypography.labelMedium),
    labelLarge: c(AppTypography.labelLarge),
    labelMedium: c(AppTypography.labelMedium),
    labelSmall: c(AppTypography.labelSmall),
  );
}
