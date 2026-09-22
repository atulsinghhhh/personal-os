import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';
import 'text_theme_builder.dart';
import 'theme_extensions.dart';

ThemeData buildAppThemeDark() {
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.brandSeed,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.darkInk,
    onPrimary: AppColors.darkGround,
    primaryContainer: AppColors.darkSurface,
    onPrimaryContainer: AppColors.darkAccent,
    secondary: AppColors.darkAccent,
    onSecondary: AppColors.darkGround,
    secondaryContainer: AppColors.darkSurface,
    onSecondaryContainer: AppColors.darkAccent,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkInk,
    onSurfaceVariant: AppColors.darkInk2,
    surfaceContainerLowest: AppColors.darkSurface,
    surfaceContainerLow: AppColors.darkSurface,
    surfaceContainer: AppColors.darkSurface,
    surfaceContainerHigh: AppColors.darkSurfaceContainerHigh,
    surfaceContainerHighest: AppColors.darkSurfaceContainerHigh,
    outline: AppColors.darkHairline,
    outlineVariant: AppColors.darkHairline,
    error: AppColors.expenseDark,
  );

  final TextTheme textTheme = buildAppTextTheme(colorScheme.onSurface);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppTypography.sansFamily,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.darkGround,
    textTheme: textTheme,
    extensions: const <ThemeExtension<dynamic>>[AppSemanticColors.dark],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkGround,
      foregroundColor: AppColors.darkInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleMedium,
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.asBorderRadius(AppRadius.surface),
      ),
      shadowColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      hintStyle: textTheme.bodyLarge!.copyWith(color: AppColors.darkInk2),
      border: OutlineInputBorder(
        borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.darkHairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.darkHairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.darkInk),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.darkInk,
        foregroundColor: AppColors.darkGround,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        ),
        textStyle: AppTypography.sans(16, weight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.darkInk,
        foregroundColor: AppColors.darkGround,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        ),
        textStyle: AppTypography.sans(16, weight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkInk,
        side: const BorderSide(color: AppColors.darkHairline),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        ),
        textStyle: AppTypography.sans(15, weight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.darkAccent,
        textStyle: AppTypography.sans(14, weight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.asBorderRadius(AppRadius.button),
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkGround,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.darkHairline,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkHairline,
      thickness: 1,
      space: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: AppColors.darkInk,
      side: const BorderSide(color: AppColors.darkHairline),
      labelStyle: AppTypography.sans(14, weight: FontWeight.w500),
      shape: const StadiumBorder(),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll<Color>(AppColors.darkInk),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.darkAccent
            : AppColors.darkSurfaceContainerHigh,
      ),
      trackOutlineColor:
          const WidgetStatePropertyAll<Color>(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.darkAccent,
      linearTrackColor: AppColors.darkSurfaceContainerHigh,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.darkInk,
      foregroundColor: AppColors.darkGround,
      elevation: 0,
      shape: CircleBorder(),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.darkGround,
      indicatorColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
