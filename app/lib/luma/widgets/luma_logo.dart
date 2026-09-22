import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens.dart';

/// Brand mark from the design's Brand section: a small light rising over the
/// horizon. Ink strokes + accent sun, parameterized for dark surfaces.
class LumaLogo extends StatelessWidget {
  const LumaLogo({
    super.key,
    this.size = 28,
    this.stroke = LumaColors.ink,
    this.sun = LumaColors.accent,
  });

  final double size;
  final Color stroke;
  final Color sun;

  String get _svg {
    final s = _hex(stroke);
    final a = _hex(sun);
    return '<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">'
        '<circle cx="32" cy="32" r="28.5" fill="none" stroke="$s" stroke-width="2"/>'
        '<path d="M20 41 a12 12 0 0 1 24 0 z" fill="$a"/>'
        '<path d="M9.5 41 H54.5" stroke="$s" stroke-width="2" stroke-linecap="round"/>'
        '<path d="M24 48 H40" stroke="$s" stroke-width="2" stroke-linecap="round" opacity="0.45"/>'
        '</svg>';
  }

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) =>
      SvgPicture.string(_svg, width: size, height: size);
}
