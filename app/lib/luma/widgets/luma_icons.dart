import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens.dart';

/// Inner markup of the design's inline stroke icons (24×24 viewBox).
/// Kept verbatim from design/luma-design.html so rendering matches exactly.
abstract final class LumaIcons {
  static const String lock =
      '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>';
  static const String chevronLeft = '<path d="m15 6-6 6 6 6"/>';
  static const String chevronRight = '<path d="m9 6 6 6-6 6"/>';
  static const String mail =
      '<rect x="3" y="5.5" width="18" height="13" rx="2.5"/><path d="m4 7 8 6 8-6"/>';
  static const String passkey =
      '<circle cx="8" cy="12" r="4"/><path d="M12 12h9M18 12v3M21 12v2"/>';
  static const String sparkle =
      '<path d="M12 4l1.7 4.3L18 10l-4.3 1.7L12 16l-1.7-4.3L6 10l4.3-1.7z"/><path d="M18.5 15.5l.6 1.4 1.4.6-1.4.6-.6 1.4-.6-1.4-1.4-.6 1.4-.6z"/>';
  static const String search =
      '<circle cx="11" cy="11" r="6.5"/><path d="m16 16 4 4"/>';
  static const String bell =
      '<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>';
  static const String link =
      '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>';
  static const String plus = '<path d="M12 5v14M5 12h14"/>';
  static const String tabToday =
      '<circle cx="12" cy="12" r="4"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6 7 7M17 17l1.4 1.4M5.6 18.4 7 17M17 7l1.4-1.4"/>';
  static const String tabPlan =
      '<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>';
  static const String tabFuture =
      '<circle cx="12" cy="12" r="8.5"/><path d="m15.5 8.5-2 5-5 2 2-5z"/>';
  static const String tabMoney =
      '<rect x="3" y="6" width="18" height="13" rx="2.5"/><path d="M15.5 12.5h2.5M3 9.5h18"/>';
  static const String tabReview =
      '<path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3L4.5 9"/><path d="M4.5 4.5V9H9"/><path d="M12 8.5V12l2.5 1.5"/>';
}

/// Renders one of the design's stroke icons.
class LumaIcon extends StatelessWidget {
  const LumaIcon(
    this.inner, {
    super.key,
    this.size = 22,
    this.color = LumaColors.ink,
    this.strokeWidth = 1.6,
  });

  final String inner;
  final double size;
  final Color color;
  final double strokeWidth;

  static String hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final svg =
        '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="${hex(color)}" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">$inner</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}

/// Filled play triangle used in "Start focus" buttons.
class LumaPlayIcon extends StatelessWidget {
  const LumaPlayIcon({super.key, this.size = 16, this.color = LumaColors.surface});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        '<svg width="24" height="24" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M8 5.5v13l10-6.5z" fill="${LumaIcon.hex(color)}"/></svg>',
        width: size,
        height: size,
      );
}
