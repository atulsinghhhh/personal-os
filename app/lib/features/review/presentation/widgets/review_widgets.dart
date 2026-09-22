import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';

/// Shared building blocks for the review sub-views.

/// Prev/next chevrons around a period label (day, week, month).
class ReviewNavHeader extends StatelessWidget {
  const ReviewNavHeader({
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
TextStyle reviewSectionLabel(BuildContext context) {
  return AppTypography.labelMedium.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    letterSpacing: 1.2,
  );
}

/// 1–5 star selector used for energy / focus / mood.
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

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        for (int star = 1; star <= 5; star++)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '$star of 5',
            icon: Icon(
              (value ?? 0) >= star ? Icons.star : Icons.star_border,
              size: 22,
              color: (value ?? 0) >= star
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
            onPressed: () => onChanged(star),
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

/// Card of multiline fields with a single save button — the weekly and
/// monthly review stubs. Trimmed empty values come back as null.
class ReviewStubForm extends StatefulWidget {
  const ReviewStubForm({
    super.key,
    required this.fields,
    required this.onSave,
  });

  final List<ReviewFieldSpec> fields;
  final Future<void> Function(Map<String, String?> values) onSave;

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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ReviewFieldSpec field in widget.fields) ...<Widget>[
            AppTextField(
              label: field.label,
              hint: field.hint,
              controller: _controllers[field.id],
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppButton(
            label: 'Save review',
            expand: true,
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    final Map<String, String?> values = <String, String?>{
                      for (final MapEntry<String, TextEditingController>
                          entry in _controllers.entries)
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
      ),
    );
  }
}
