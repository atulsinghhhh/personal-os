import 'package:flutter/widgets.dart';

import '../../core/design_system/tokens/colors.dart';

export '../../core/design_system/tokens/colors.dart' show AppColors;

/// Design tokens from design/luma-design.html `<script id="luma-tokens">`.
/// Color values are canonical in [AppColors]; these aliases keep call sites
/// readable with the design's own names.
abstract final class LumaColors {
  // color.light
  static const Color ground = AppColors.ground;
  static const Color surface = AppColors.surface;
  static const Color sunken = AppColors.sunken;
  static const Color hairline = AppColors.hairline;
  static const Color ink = AppColors.ink;
  static const Color ink2 = AppColors.ink2;
  static const Color ink3 = AppColors.ink3;
  static const Color accent = AppColors.accent;
  static const Color accentSoft = AppColors.accentSoft;

  // color.dark
  static const Color darkGround = AppColors.darkGround;
  static const Color darkSurface = AppColors.darkSurface;
  static const Color darkHairline = AppColors.darkHairline;
  static const Color darkInk = AppColors.darkInk;
  static const Color darkInk2 = AppColors.darkInk2;
  static const Color darkAccent = AppColors.darkAccent;

  // color.semantic
  static const Color positive = AppColors.incomeLight;
  static const Color negative = AppColors.expenseLight;
  static const Color neutral = AppColors.ink2;
  static const Color warning = AppColors.warningLight;
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
