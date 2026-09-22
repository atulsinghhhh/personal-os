import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../projects/domain/entities/project_entities.dart';

/// Small shared building blocks for the four planner sub-views.

/// Prev/next chevrons around a period label (day, week, month, year).
class PlannerNavHeader extends StatelessWidget {
  const PlannerNavHeader({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous',
          onPressed: onPrevious,
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next',
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// Section label matching the Today screen's uppercase style.
TextStyle plannerSectionLabel(BuildContext context) {
  return AppTypography.labelMedium.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    letterSpacing: 1.2,
  );
}

/// Checkbox row that toggles a task between todo and done.
class TaskCheckRow extends ConsumerWidget {
  const TaskCheckRow({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool done = task.status == TaskStatus.done;

    return CheckboxListTile(
      value: done,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (bool? checked) {
        ref.read(taskRepositoryProvider).update(
              task.copyWith(
                status:
                    (checked ?? false) ? TaskStatus.done : TaskStatus.todo,
                updatedAt: DateTime.now().toUtc(),
              ),
            );
      },
      title: Text(
        task.title,
        style: AppTypography.bodyLarge.copyWith(
          decoration: done ? TextDecoration.lineThrough : null,
          color:
              done ? Theme.of(context).colorScheme.onSurfaceVariant : null,
        ),
      ),
    );
  }
}

/// Card with one (optionally multiline) text field and a save button —
/// used for the day intention and month/year themes.
class PlanTextFieldCard extends StatefulWidget {
  const PlanTextFieldCard({
    super.key,
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onSave,
    this.maxLines = 2,
  });

  final String label;
  final String hint;
  final String? initialValue;
  final Future<void> Function(String value) onSave;
  final int maxLines;

  @override
  State<PlanTextFieldCard> createState() => _PlanTextFieldCardState();
}

class _PlanTextFieldCardState extends State<PlanTextFieldCard> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            label: widget.label,
            hint: widget.hint,
            controller: _controller,
            maxLines: widget.maxLines,
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Save',
              variant: AppButtonVariant.secondary,
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      await widget.onSave(_controller.text.trim());
                      if (mounted) setState(() => _saving = false);
                    },
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats a minute count as "Xh Ym" (or "Ym" under an hour).
String formatMinutes(int minutes) {
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  if (hours == 0) return '${rest}m';
  if (rest == 0) return '${hours}h';
  return '${hours}h ${rest}m';
}
