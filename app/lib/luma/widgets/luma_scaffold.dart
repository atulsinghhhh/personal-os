import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Screen shell on the ground color. Design screens are drawn at full scroll
/// height, so the body scrolls; the tab bar (when present) comes from the
/// app shell around this screen.
class LumaScreen extends StatelessWidget {
  const LumaScreen({
    super.key,
    required this.child,
    this.fab,
    this.bottomBar,
    this.padding = const EdgeInsets.fromLTRB(20, 52, 20, 40),
    this.scrollable = true,
    this.background = LumaColors.ground,
  });

  final Widget child;
  final Widget? fab;

  /// Pinned bar below the body (e.g. task detail's "Start focus" bar).
  final Widget? bottomBar;
  final EdgeInsetsGeometry padding;
  final bool scrollable;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final resolved = padding.resolve(TextDirection.ltr);
    final effective = EdgeInsets.fromLTRB(
      resolved.left,
      // The design bakes ~52-64px of status-bar space into its top padding;
      // grow it only when the device inset is larger.
      resolved.top > topInset ? resolved.top : topInset + 12,
      resolved.right,
      resolved.bottom,
    );

    final body = scrollable
        ? SingleChildScrollView(padding: effective, child: child)
        : Padding(padding: effective, child: child);

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          Positioned.fill(child: body),
          if (fab != null)
            Positioned(right: 20, bottom: 20, child: fab!),
        ],
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}
