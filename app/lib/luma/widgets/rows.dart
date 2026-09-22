import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'luma_icons.dart';
import 'primitives.dart';

/// Eyebrow section header with an optional trailing action.
class LumaSectionHeader extends StatelessWidget {
  const LumaSectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        LumaEyebrow(title),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: lumaSans(
                    size: 13,
                    weight: FontWeight.w500,
                    color: LumaColors.accent)),
          ),
      ],
    );
  }
}

/// "Livqeno / Documentation / Financial independence" breadcrumb with the
/// link icon and hairline separators.
class LumaBreadcrumb extends StatelessWidget {
  const LumaBreadcrumb(this.items, {super.key});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        const LumaIcon(LumaIcons.link, size: 13, color: LumaColors.ink3),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child:
                  Text('/', style: lumaSans(size: 12, color: LumaColors.hairline)),
            ),
          Text(items[i], style: lumaSans(size: 12, color: LumaColors.ink3)),
        ],
      ],
    );
  }
}

/// Anytime/checklist list row: circular checkbox, title, optional trailing.
class LumaTaskRow extends StatelessWidget {
  const LumaTaskRow({
    super.key,
    required this.title,
    this.trailing,
    this.checked = false,
    this.hairlineTop = true,
    this.minHeight = 48,
    this.onToggle,
  });

  final String title;
  final String? trailing;
  final bool checked;
  final bool hairlineTop;
  final double minHeight;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        border: hairlineTop
            ? const Border(top: BorderSide(color: LumaColors.hairline))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: checked
                  ? Container(
                      decoration: const BoxDecoration(
                        color: LumaColors.ink3,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: LumaIcon(LumaIcons.check,
                            size: 13,
                            color: LumaColors.surface,
                            strokeWidth: 2.2),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: LumaColors.ink, width: 1.5),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: checked
                  ? lumaSans(size: 15, color: LumaColors.ink3).copyWith(
                      decoration: TextDecoration.lineThrough,
                      decorationColor: LumaColors.ink3,
                    )
                  : lumaSans(size: 15),
            ),
          ),
          if (trailing != null)
            Text(trailing!, style: lumaSans(size: 12.5, color: LumaColors.ink3)),
        ],
      ),
    );
  }
}

/// Label/value detail row (Project · Livqeno …), 46px min height.
class LumaMetaRow extends StatelessWidget {
  const LumaMetaRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.hairlineTop = true,
    this.onTap,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool hairlineTop;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        decoration: BoxDecoration(
          border: hairlineTop
              ? const Border(top: BorderSide(color: LumaColors.hairline))
              : null,
        ),
        child: Row(
          children: [
            Text(label, style: lumaSans(size: 14, color: LumaColors.ink3)),
            const Spacer(),
            valueWidget ??
                Text(value ?? '',
                    textAlign: TextAlign.right,
                    style: lumaSans(size: 14, weight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// 12px timeline dot: filled / outlined / square / dashed variants.
enum LumaDotStyle { filledAccent, filledMuted, outlined, square, dashed }

class LumaTimelineDot extends StatelessWidget {
  const LumaTimelineDot(this.style, {super.key});
  final LumaDotStyle style;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case LumaDotStyle.filledAccent:
        return Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: LumaColors.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: LumaColors.accentSoft, spreadRadius: 4),
            ],
          ),
        );
      case LumaDotStyle.filledMuted:
        return Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: LumaColors.ink3,
            shape: BoxShape.circle,
          ),
        );
      case LumaDotStyle.outlined:
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: LumaColors.ink, width: 1.5),
          ),
        );
      case LumaDotStyle.square:
        return Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: LumaColors.ink2, width: 1.5),
          ),
        );
      case LumaDotStyle.dashed:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CustomPaint(painter: _DashedCirclePainter()),
        );
    }
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = LumaColors.ink2;
    final r = (size.width - 1.5) / 2;
    final c = Offset(size.width / 2, size.height / 2);
    const segments = 8;
    const sweep = 3.14159 * 2 / segments;
    for (var i = 0; i < segments; i += 2) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), sweep * i,
          sweep * 0.9, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
