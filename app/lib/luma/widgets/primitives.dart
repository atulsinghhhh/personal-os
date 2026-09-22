import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// 11px uppercase 0.08em label.
class LumaEyebrow extends StatelessWidget {
  const LumaEyebrow(this.text, {super.key, this.color = LumaColors.ink3});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: lumaEyebrow(color: color));
}

/// 4px progress line on a sunken track.
class LumaProgressLine extends StatelessWidget {
  const LumaProgressLine({
    super.key,
    required this.value,
    this.color = LumaColors.accent,
    this.height = 4,
    this.track = LumaColors.sunken,
  });

  final double value;
  final Color color;
  final double height;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Circular 20px task checkbox with a 44px touch target.
class LumaCheckbox extends StatelessWidget {
  const LumaCheckbox({
    super.key,
    this.checked = false,
    this.onTap,
    this.semanticLabel,
  });

  final bool checked;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                // Design motion token: complete = 180ms check + light haptic.
                HapticFeedback.lightImpact();
                onTap!();
              },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: lumaTouchMin,
          height: lumaTouchMin,
          child: Center(
            child: AnimatedContainer(
              duration: LumaMotion.complete,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: checked ? LumaColors.ink : Colors.transparent,
                border: Border.all(color: LumaColors.ink, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 13, color: LumaColors.surface)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 48×30 switch matching the design's role="switch" toggles.
class LumaToggle extends StatelessWidget {
  const LumaToggle({super.key, required this.on, this.onChanged, this.label});

  final bool on;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      toggled: on,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!on),
        child: AnimatedContainer(
          duration: LumaMotion.complete,
          width: 48,
          height: 30,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: on ? LumaColors.accent : LumaColors.sunken,
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: LumaColors.surface,
              borderRadius: BorderRadius.circular(13),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x401B1B19),
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White surface card: radius 22, 20px padding, hairline drop shadow.
class LumaCard extends StatelessWidget {
  const LumaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = LumaColors.surface,
    this.radius = LumaRadius.surface,
    this.hairlineShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final bool hairlineShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: hairlineShadow
            ? const [
                BoxShadow(color: LumaColors.hairline, offset: Offset(0, 1)),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// 1px hairline divider.
class LumaHairline extends StatelessWidget {
  const LumaHairline({super.key});
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: LumaColors.hairline);
}
