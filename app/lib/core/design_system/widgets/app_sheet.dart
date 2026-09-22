import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Single call site for every modal bottom sheet in the app (quick capture,
/// add expense/income, conflict resolution, pickers), so sheet chrome
/// (drag handle, title, padding, safe-area) stays consistent everywhere.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    builder: (BuildContext context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTypography.titleLarge),
                const SizedBox(height: AppSpacing.md),
                Builder(builder: builder),
              ],
            ),
          ),
        ),
      );
    },
  );
}
