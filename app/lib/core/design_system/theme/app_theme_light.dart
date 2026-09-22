import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';
import 'text_theme_builder.dart';
import 'theme_extensions.dart';

ThemeData buildAppThemeLight() {
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.brandSeed,
    brightness: Brightness.light,
  ).copyWith(
    // Luma: ink-black primary actions, indigo accent for links/emphasis.
    primary: AppColors.ink,
    onPrimary: AppColors.surface,
    primaryContainer: AppColors.accentSoft,
    onPrimaryContainer: AppColors.accent,
    secondary: AppColors.accent,
    onSecondary: AppColors.surface,
    secondaryContainer: AppColors.accentSoft,
    onSecondaryContainer: AppColors.accent,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.ink2,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.sunken,
    surfaceContainerHighest: AppColors.sunken,
    outline: AppColors.hairline,
    outlineVariant: AppColors.hairline,
    error: AppColors.expenseLight,
  );

  final TextTheme textTheme = buildAppTextTheme(colorScheme.onSurface);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppTypography.sansFamily,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.ground,
    textTheme: textTheme,
    extensions: const <ThemeExtension<dynamic>>[AppSemanticColors.light],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleMedium,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.asBorderRadius(AppRadius.surface),
      ),
      shadowColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      hintStyle: textTheme.bodyLarge!.copyWith(color: AppColors.ink3),
      border: OutlineInputBorder(
        borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.ink),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.surface,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        ),
        textStyle: AppTypography.sans(16, weight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.surface,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        ),
        textStyle: AppTypography.sans(16, weight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.hairline),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        ),
        textStyle: AppTypography.sans(15, weight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: AppTypography.sans(14, weight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.ground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.hairline,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.hairline,
      thickness: 1,
      space: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: AppColors.ink,
      side: const BorderSide(color: AppColors.hairline),
      labelStyle: AppTypography.sans(14, weight: FontWeight.w500),
      shape: const StadiumBorder(),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll<Color>(AppColors.surface),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.accent
            : AppColors.sunken,
      ),
      trackOutlineColor:
          const WidgetStatePropertyAll<Color>(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.sunken,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.surface,
      elevation: 0,
      shape: CircleBorder(),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.ground,
      indicatorColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
