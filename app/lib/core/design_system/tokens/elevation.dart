import 'package:flutter/material.dart';

/// Elevation levels. Material 3 tonal elevation (surface-color shifts) is
/// the primary mechanism app-wide; shadows are reserved for floating
/// elements (FAB, dialogs, expanded sheets) per level3+.
abstract final class AppElevation {
  static const List<BoxShadow> level0 = <BoxShadow>[];
  static const List<BoxShadow> level1 = <BoxShadow>[];

  static const List<BoxShadow> level2 = <BoxShadow>[
    BoxShadow(color: Color(0x0F000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  static const List<BoxShadow> level3 = <BoxShadow>[
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 2), blurRadius: 6),
  ];

  static const List<BoxShadow> level4 = <BoxShadow>[
    BoxShadow(color: Color(0x24000000), offset: Offset(0, 4), blurRadius: 12),
  ];

  static const List<BoxShadow> level5 = <BoxShadow>[
    BoxShadow(color: Color(0x2E000000), offset: Offset(0, 8), blurRadius: 24),
  ];

  /// Dark-theme shadows read differently on dark surfaces: same offsets,
  /// higher opacity, lean on the lighter surface-container tint as the
  /// primary cue and treat these as secondary.
  static const List<BoxShadow> level2Dark = <BoxShadow>[
    BoxShadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  static const List<BoxShadow> level3Dark = <BoxShadow>[
    BoxShadow(color: Color(0x7A000000), offset: Offset(0, 2), blurRadius: 6),
  ];

  static const List<BoxShadow> level4Dark = <BoxShadow>[
    BoxShadow(color: Color(0x8F000000), offset: Offset(0, 4), blurRadius: 12),
  ];

  static const List<BoxShadow> level5Dark = <BoxShadow>[
    BoxShadow(color: Color(0x99000000), offset: Offset(0, 8), blurRadius: 24),
  ];
}
