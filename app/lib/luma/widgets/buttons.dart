import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 54px black pill — the design's primary CTA.
class LumaPrimaryButton extends StatelessWidget {
  const LumaPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 54,
    this.leading,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return _Tappable(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: LumaColors.ink,
          borderRadius: BorderRadius.circular(LumaRadius.button),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Text(label,
                style: lumaSans(
                    size: 16, weight: FontWeight.w600, color: LumaColors.surface)),
          ],
        ),
      ),
    );
  }
}

/// 50px white outlined button (Continue with Apple/Google, Details…).
class LumaSecondaryButton extends StatelessWidget {
  const LumaSecondaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.leading,
    this.height = 50,
    this.background = LumaColors.surface,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w500,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? leading;
  final double height;
  final Color background;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return _Tappable(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: LumaColors.hairline),
          borderRadius: BorderRadius.circular(LumaRadius.button),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Text(label,
                style: lumaSans(
                    size: fontSize, weight: fontWeight, color: LumaColors.ink)),
          ],
        ),
      ),
    );
  }
}

/// Plain text button (Skip for now, I already have an account…).
class LumaTextButton extends StatelessWidget {
  const LumaTextButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 48,
    this.color = LumaColors.ink,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w500,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return _Tappable(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Center(
          child: Text(label,
              style: lumaSans(size: fontSize, weight: fontWeight, color: color)),
        ),
      ),
    );
  }
}

/// 38px selectable pill chip (life areas, years, segments…).
class LumaChip extends StatelessWidget {
  const LumaChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.height = 38,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _Tappable(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: selected ? LumaColors.ink : Colors.transparent,
          border: Border.all(
              color: selected ? LumaColors.ink : LumaColors.hairline),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: lumaSans(
                size: 14,
                weight: FontWeight.w500,
                color: selected ? LumaColors.surface : LumaColors.ink2)),
      ),
    );
  }
}

class _Tappable extends StatelessWidget {
  const _Tappable({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
}
