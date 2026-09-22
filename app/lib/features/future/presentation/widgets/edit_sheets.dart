import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/design_system/widgets/date_selector.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../domain/entities/future_entities.dart';

/// Creation sheets for the Future hierarchy. Each writes through the
/// standard repository path and closes on save.

String? _currentUserId(WidgetRef ref) =>
    ref.read(supabaseClientProvider).auth.currentUser?.id;

Future<void> showLifeAreaSheet(BuildContext context, WidgetRef ref) {
  final TextEditingController name = TextEditingController();
  return showAppBottomSheet<void>(
    context: context,
    title: 'New life area',
    builder: (BuildContext sheetContext) {
      return _SingleFieldForm(
        controller: name,
        hint: 'e.g. Health',
        onSave: (String value) async {
          final String? userId = _currentUserId(ref);
          if (userId == null) return;
          final DateTime now = DateTime.now().toUtc();
          final List<Color> accents = AppSemanticColors.light.lifeAreaAccents;
          final int existing =
              (await ref.read(lifeAreaRepositoryProvider).watchAll().first)
                  .length;
          final Color accent = accents[existing % accents.length];
          await ref.read(lifeAreaRepositoryProvider).create(
                LifeArea(
                  id: const Uuid().v4(),
                  userId: userId,
                  name: value,
                  color:
                      '#${accent.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                  sortOrder: existing,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        },
      );
    },
  );
}

Future<void> showVisionSheet(
  BuildContext context,
  WidgetRef ref, {
  String? lifeAreaId,
}) {
  final TextEditingController title = TextEditingController();
  return showAppBottomSheet<void>(
    context: context,
    title: 'New vision',
    builder: (BuildContext sheetContext) {
      return _SingleFieldForm(
        controller: title,
        hint: 'Describe the future you want…',
        maxLines: 3,
        onSave: (String value) async {
          final String? userId = _currentUserId(ref);
          if (userId == null) return;
          final DateTime now = DateTime.now().toUtc();
          await ref.read(visionRepositoryProvider).create(
                Vision(
                  id: const Uuid().v4(),
                  userId: userId,
                  lifeAreaId: lifeAreaId,
                  title: value,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        },
      );
    },
  );
}

Future<void> showGoalSheet(
  BuildContext context,
  WidgetRef ref, {
  String? lifeAreaId,
  String? visionId,
}) {
  final TextEditingController title = TextEditingController();
  DateTime? targetDate;
  return showAppBottomSheet<void>(
    context: context,
    title: 'New goal',
    builder: (BuildContext sheetContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                controller: title,
                hint: 'What do you want to achieve?',
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.md),
              DateSelector(
                label: 'Target date (optional)',
                value: targetDate,
                onChanged: (DateTime date) =>
                    setState(() => targetDate = date),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Create goal',
                expand: true,
                onPressed: () async {
                  final String value = title.text.trim();
                  final String? userId = _currentUserId(ref);
                  if (value.isEmpty || userId == null) return;
                  final DateTime now = DateTime.now().toUtc();
                  await ref.read(goalRepositoryProvider).create(
                        Goal(
                          id: const Uuid().v4(),
                          userId: userId,
                          visionId: visionId,
                          lifeAreaId: lifeAreaId,
                          title: value,
                          targetDate: targetDate,
                          status: GoalStatus.active,
                          createdAt: now,
                          updatedAt: now,
                        ),
                      );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showMilestoneSheet(
  BuildContext context,
  WidgetRef ref, {
  required String goalId,
}) {
  final TextEditingController title = TextEditingController();
  return showAppBottomSheet<void>(
    context: context,
    title: 'New milestone',
    builder: (BuildContext sheetContext) {
      return _SingleFieldForm(
        controller: title,
        hint: 'e.g. Launch v1',
        onSave: (String value) async {
          final String? userId = _currentUserId(ref);
          if (userId == null) return;
          final DateTime now = DateTime.now().toUtc();
          await ref.read(goalRepositoryProvider).createMilestone(
                Milestone(
                  id: const Uuid().v4(),
                  userId: userId,
                  goalId: goalId,
                  title: value,
                  status: MilestoneStatus.pending,
                  sortOrder: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        },
      );
    },
  );
}

Future<void> showProjectSheet(
  BuildContext context,
  WidgetRef ref, {
  String? goalId,
  String? milestoneId,
}) {
  final TextEditingController title = TextEditingController();
  return showAppBottomSheet<void>(
    context: context,
    title: 'New project',
    builder: (BuildContext sheetContext) {
      return _SingleFieldForm(
        controller: title,
        hint: 'e.g. Livqeno',
        onSave: (String value) async {
          final String? userId = _currentUserId(ref);
          if (userId == null) return;
          final DateTime now = DateTime.now().toUtc();
          await ref.read(projectRepositoryProvider).create(
                Project(
                  id: const Uuid().v4(),
                  userId: userId,
                  goalId: goalId,
                  milestoneId: milestoneId,
                  title: value,
                  status: ProjectStatus.active,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        },
      );
    },
  );
}

Future<void> showTaskSheet(
  BuildContext context,
  WidgetRef ref, {
  String? projectId,
  bool scheduleToday = false,
}) {
  final TextEditingController title = TextEditingController();
  return showAppBottomSheet<void>(
    context: context,
    title: 'New task',
    builder: (BuildContext sheetContext) {
      return _SingleFieldForm(
        controller: title,
        hint: 'What needs doing?',
        onSave: (String value) async {
          final String? userId = _currentUserId(ref);
          if (userId == null) return;
          final DateTime now = DateTime.now().toUtc();
          // Local calendar date in a UTC container — the user's "today".
          final DateTime local = DateTime.now();
          await ref.read(taskRepositoryProvider).create(
                Task(
                  id: const Uuid().v4(),
                  userId: userId,
                  projectId: projectId,
                  title: value,
                  status: TaskStatus.todo,
                  priority: 0,
                  scheduledDate: scheduleToday
                      ? DateTime.utc(local.year, local.month, local.day)
                      : null,
                  actualMinutes: 0,
                  sortOrder: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        },
      );
    },
  );
}

class _SingleFieldForm extends StatelessWidget {
  const _SingleFieldForm({
    required this.controller,
    required this.hint,
    required this.onSave,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final Future<void> Function(String value) onSave;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          controller: controller,
          hint: hint,
          autofocus: true,
          maxLines: maxLines,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Save',
          expand: true,
          onPressed: () async {
            final String value = controller.text.trim();
            if (value.isEmpty) return;
            await onSave(value);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
