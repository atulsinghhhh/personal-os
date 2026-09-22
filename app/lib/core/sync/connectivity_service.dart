import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True when the device reports any network transport. Drives the offline
/// banner and gates/triggers sync passes on connectivity changes.
final StreamProvider<bool> isOnlineProvider = StreamProvider<bool>((
  Ref ref,
) async* {
  final Connectivity connectivity = Connectivity();
  final List<ConnectivityResult> initial =
      await connectivity.checkConnectivity();
  yield _hasTransport(initial);

  await for (final List<ConnectivityResult> results
      in connectivity.onConnectivityChanged) {
    yield _hasTransport(results);
  }
});

bool _hasTransport(List<ConnectivityResult> results) {
  return results.any(
    (ConnectivityResult r) => r != ConnectivityResult.none,
  );
}
