import 'package:flutter/material.dart';

import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';

/// Shared building blocks for the review sub-views, in the Luma style.

/// Serif period title with prev/next chevrons on the right.
class ReviewNavHeader extends StatelessWidget {
  const ReviewNavHeader({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    this.eyebrow,
    this.sub,
  });

  final String label;
  final String? eyebrow;
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
              if (eyebrow != null) ...<Widget>[
                Text(eyebrow!.toUpperCase(), style: lumaEyebrow()),
                const SizedBox(height: 6),
              ],
              Text(label, style: lumaSerif(size: 46, height: 1.05)),
              if (sub != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(sub!, style: lumaSans(size: 15, color: LumaColors.ink2)),
              ],
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(10, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _Chevron(
                  icon: LumaIcons.chevronLeft,
                  label: 'Previous',
                  onTap: onPrevious),
              _Chevron(
                  icon: LumaIcons.chevronRight, label: 'Next', onTap: onNext),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron(
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

/// Eyebrow section label.
TextStyle reviewSectionLabel(BuildContext context) => lumaEyebrow();

/// 1–5 selector rendered as the design's feeling chips
/// (Drained · Low · Okay · Good · Great).
class RatingSelector extends StatelessWidget {
  const RatingSelector({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int> onChanged;

  static const List<String> _levels = <String>[
    'Drained',
    'Low',
    'Okay',
    'Good',
    'Great',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: lumaSans(size: 14, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            for (int level = 1; level <= 5; level++) ...<Widget>[
              if (level > 1) const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  label: '${_levels[level - 1]}, $level of 5',
                  button: true,
                  selected: value == level,
                  child: GestureDetector(
                    onTap: () => onChanged(level),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: value == level
                            ? LumaColors.ink
                            : Colors.transparent,
                        border: Border.all(
                            color: value == level
                                ? LumaColors.ink
                                : LumaColors.hairline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _levels[level - 1],
                        style: lumaSans(
                          size: 13,
                          color: value == level
                              ? LumaColors.surface
                              : LumaColors.ink2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The design's reflection prompt: bold sans label over an italic-free serif
/// text field with a hairline underline.
class ReviewPromptField extends StatelessWidget {
  const ReviewPromptField({
    super.key,
    required this.label,
    required this.controller,
    this.hint = 'Write freely…',
    this.maxLines = 3,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: lumaSans(size: 14, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: LumaColors.hairline)),
          ),
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: 1,
            style: lumaSerif(size: 21, height: 1.4),
            cursorColor: LumaColors.ink,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintText: hint,
              hintStyle:
                  lumaSerif(size: 21, height: 1.4, color: LumaColors.ink3),
            ),
          ),
        ),
      ],
    );
  }
}

/// One labeled multiline field in a [ReviewStubForm].
class ReviewFieldSpec {
  const ReviewFieldSpec({
    required this.id,
    required this.label,
    required this.hint,
    this.initialValue,
  });

  final String id;
  final String label;
  final String hint;
  final String? initialValue;
}

/// Serif prompt fields with a single save button — the weekly and monthly
/// review forms. Trimmed empty values come back as null.
class ReviewStubForm extends StatefulWidget {
  const ReviewStubForm({
    super.key,
    required this.fields,
    required this.onSave,
    this.saveLabel = 'Complete review',
  });

  final List<ReviewFieldSpec> fields;
  final Future<void> Function(Map<String, String?> values) onSave;
  final String saveLabel;

  @override
  State<ReviewStubForm> createState() => _ReviewStubFormState();
}

class _ReviewStubFormState extends State<ReviewStubForm> {
  late final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{
    for (final ReviewFieldSpec field in widget.fields)
      field.id: TextEditingController(text: field.initialValue ?? ''),
  };
  bool _saving = false;

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final ReviewFieldSpec field in widget.fields) ...<Widget>[
          ReviewPromptField(
            label: field.label,
            hint: field.hint,
            controller: _controllers[field.id]!,
          ),
          const SizedBox(height: 24),
        ],
        LumaPrimaryButton(
          label: _saving ? 'Saving…' : widget.saveLabel,
          onTap: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  final Map<String, String?> values = <String, String?>{
                    for (final MapEntry<String, TextEditingController> entry
                        in _controllers.entries)
                      entry.key: entry.value.text.trim().isEmpty
                          ? null
                          : entry.value.text.trim(),
                  };
                  await widget.onSave(values);
                  if (!mounted) return;
                  setState(() => _saving = false);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Review saved.')),
                  );
                },
        ),
      ],
    );
  }
}
