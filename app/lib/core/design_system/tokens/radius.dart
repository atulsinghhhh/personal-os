import 'package:flutter/widgets.dart';

/// Luma corner radius scale: chip 9, button 14, surface 22, sheet 28.
abstract final class AppRadius {
  static const double none = 0;
  static const double sm = 9;
  static const double md = 14;
  static const double lg = 22;
  static const double xl = 28;
  static const double full = 999;

  /// Named aliases matching the design tokens.
  static const double chip = sm;
  static const double button = md;
  static const double surface = lg;
  static const double sheet = xl;

  static BorderRadius asBorderRadius(double value) =>
      BorderRadius.all(Radius.circular(value));
}
