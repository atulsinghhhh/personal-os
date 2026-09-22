import 'package:flutter/widgets.dart';

/// Design tokens from design/luma-design.html `<script id="luma-tokens">`.
abstract final class LumaColors {
  // color.light
  static const Color ground = Color(0xFFF5F3EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color sunken = Color(0xFFEAE7E0);
  static const Color hairline = Color(0xFFE1DDD4);
  static const Color ink = Color(0xFF1B1B19);
  static const Color ink2 = Color(0xFF57544D);
  static const Color ink3 = Color(0xFF6F6B62);
  static const Color accent = Color(0xFF2F4F8F);
  static const Color accentSoft = Color(0xFFE3E8F2);

  // color.dark
  static const Color darkGround = Color(0xFF121211);
  static const Color darkSurface = Color(0xFF1C1C1A);
  static const Color darkHairline = Color(0xFF2B2A27);
  static const Color darkInk = Color(0xFFEEECE6);
  static const Color darkInk2 = Color(0xFFA9A69D);
  static const Color darkAccent = Color(0xFF94ABDD);

  // color.semantic
  static const Color positive = Color(0xFF2E7250);
  static const Color negative = Color(0xFFA33F2B);
  static const Color neutral = Color(0xFF57544D);
  static const Color warning = Color(0xFF8E6210);
}

abstract final class LumaFonts {
  static const String serif = 'Instrument Serif';
  static const String sans = 'Geist';
}

abstract final class LumaType {
  static const double metric = 60;
  static const double title = 44;
  static const double heroTask = 30;
  static const double reflection = 22;
  static const double row = 15;
  static const double body = 15;
  static const double meta = 12.5;
  static const double eyebrow = 11;
}

abstract final class LumaSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s28 = 28;
  static const double s40 = 40;

  static const double screenMargin = 20;
  static const double sectionGap = 28;
}

abstract final class LumaRadius {
  static const double chip = 9;
  static const double button = 14;
  static const double surface = 22;
  static const double sheet = 28;
}

abstract final class LumaMotion {
  static const Duration sheet = Duration(milliseconds: 280);
  static const Curve sheetCurve = Curves.easeOut;
  static const Duration complete = Duration(milliseconds: 180);
}

const double lumaTouchMin = 44;

/// Base text style: Geist with tabular numbers (design uses
/// font-variant-numeric: tabular-nums on every screen root).
TextStyle lumaSans({
  double size = LumaType.body,
  FontWeight weight = FontWeight.w400,
  Color color = LumaColors.ink,
  double? height,
  double? letterSpacing,
}) =>
    TextStyle(
      fontFamily: LumaFonts.sans,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Display style: Instrument Serif 400, used for titles and big numbers.
TextStyle lumaSerif({
  double size = LumaType.title,
  Color color = LumaColors.ink,
  double? height,
  FontStyle style = FontStyle.normal,
  double letterSpacing = -0.01,
}) =>
    TextStyle(
      fontFamily: LumaFonts.serif,
      fontSize: size,
      fontWeight: FontWeight.w400,
      fontStyle: style,
      color: color,
      height: height,
      // design uses em-based letter-spacing (-0.01em)
      letterSpacing: size * letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Eyebrow label: 11px uppercase, 0.08em tracking, ink3, weight 500.
TextStyle lumaEyebrow({Color color = LumaColors.ink3, double size = LumaType.eyebrow}) =>
    lumaSans(size: size, weight: FontWeight.w500, color: color, letterSpacing: size * 0.08);
