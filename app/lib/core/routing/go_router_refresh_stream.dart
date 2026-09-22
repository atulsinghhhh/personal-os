import 'dart:async';

import 'package:flutter/foundation.dart';

/// Turns any [Stream] into a [Listenable] go_router can use as
/// `refreshListenable` — every stream event re-runs the router's `redirect`
/// callback. Used to re-evaluate auth-based redirects whenever Supabase's
/// auth state stream emits (sign-in, sign-out, token refresh).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<Object?> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (Object? _) => notifyListeners(),
    );
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
