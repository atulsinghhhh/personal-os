import 'package:flutter/material.dart';

import '../tokens/colors.dart';

/// Semantic colors Material 3's [ColorScheme] has no role for: money
/// signal colors and the life-area accent palette. Access via
/// `Theme.of(context).extension<AppSemanticColors>()!`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.income,
    required this.expense,
    required this.warning,
    required this.conflict,
    required this.lifeAreaAccents,
  });

  final Color income;
  final Color expense;
  final Color warning;
  final Color conflict;
  final List<Color> lifeAreaAccents;

  static const AppSemanticColors light = AppSemanticColors(
    income: AppColors.incomeLight,
    expense: AppColors.expenseLight,
    warning: AppColors.warningLight,
    conflict: AppColors.conflictLight,
    lifeAreaAccents: AppColors.lifeAreaAccents,
  );

  static const AppSemanticColors dark = AppSemanticColors(
    income: AppColors.incomeDark,
    expense: AppColors.expenseDark,
    warning: AppColors.warningDark,
    conflict: AppColors.conflictDark,
    lifeAreaAccents: AppColors.lifeAreaAccents,
  );

  @override
  AppSemanticColors copyWith({
    Color? income,
    Color? expense,
    Color? warning,
    Color? conflict,
    List<Color>? lifeAreaAccents,
  }) {
    return AppSemanticColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
      conflict: conflict ?? this.conflict,
      lifeAreaAccents: lifeAreaAccents ?? this.lifeAreaAccents,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      conflict: Color.lerp(conflict, other.conflict, t)!,
      lifeAreaAccents: t < 0.5 ? lifeAreaAccents : other.lifeAreaAccents,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
