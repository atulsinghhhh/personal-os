import 'package:flutter/widgets.dart';

/// Corner radius scale. Use [asRadius]/[asBorderRadius] to avoid repeating
/// `Radius.circular(...)` at call sites.
abstract final class AppRadius {
  static const double none = 0;
  static const double sm = 6;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;

  static BorderRadius asBorderRadius(double value) =>
      BorderRadius.all(Radius.circular(value));
}
