import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../projects/domain/entities/project_entities.dart';

/// Small shared building blocks for the four planner sub-views, in the Luma
/// style: serif period titles, 44px chevron targets, hairline rows.

/// Serif period title with prev/next chevrons on the right (design 12).
class PlannerNavHeader extends StatelessWidget {
  const PlannerNavHeader({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    this.sub,
  });

  final String label;
  final String? sub;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: lumaSerif(size: 38, height: 1.05)),
              if (sub != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(sub!, style: lumaSans(size: 14, color: LumaColors.ink2)),
              ],
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(10, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _NavChevron(
                  icon: LumaIcons.chevronLeft,
                  label: 'Previous',
                  onTap: onPrevious),
              _NavChevron(
                  icon: LumaIcons.chevronRight, label: 'Next', onTap: onNext),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavChevron extends StatelessWidget {
  const _NavChevron(
      {required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: LumaIcon(icon, size: 21, color: LumaColors.ink2),
          ),
        ),
      ),
    );
  }
}

/// Eyebrow section label (11px uppercase, 0.08em).
TextStyle plannerSectionLabel(BuildContext context) => lumaEyebrow();

/// Hairline task row that toggles a task between todo and done.
class TaskCheckRow extends ConsumerWidget {
  const TaskCheckRow({super.key, required this.task, this.hairlineTop = true});

  final Task task;
  final bool hairlineTop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool done = task.status == TaskStatus.done;

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        border: hairlineTop
            ? const Border(top: BorderSide(color: LumaColors.hairline))
            : null,
      ),
      child: Row(
        children: <Widget>[
          LumaCheckbox(
            checked: done,
            semanticLabel: 'Complete ${task.title}',
            onTap: () => ref.read(taskRepositoryProvider).update(
                  task.copyWith(
                    status: done ? TaskStatus.todo : TaskStatus.done,
                    updatedAt: DateTime.now().toUtc(),
                  ),
                ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              task.title,
              style: done
                  ? lumaSans(
                          size: 15,
                          weight: FontWeight.w500,
                          color: LumaColors.ink3)
                      .copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: LumaColors.ink3)
                  : lumaSans(size: 15, weight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card with one (optionally multiline) text field and a save button —
/// used for the day intention and month/year themes. The field renders in
/// the design's italic serif "intention" voice.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _controller,
          maxLines: widget.maxLines,
          style: lumaSerif(size: 21, height: 1.3, style: FontStyle.italic)
              .copyWith(color: LumaColors.ink2),
          cursorColor: LumaColors.ink,
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            hintText: '“${widget.hint}”',
            hintStyle:
                lumaSerif(size: 21, height: 1.3, style: FontStyle.italic)
                    .copyWith(color: LumaColors.ink3),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: LumaTextButton(
            label: _saving ? 'Saving…' : 'Save',
            height: 36,
            fontSize: 14,
            color: LumaColors.accent,
            onTap: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onSave(_controller.text.trim());
                    if (mounted) setState(() => _saving = false);
                  },
          ),
        ),
      ],
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
