import 'package:connectivity_plus/connectivity_plus.dart';

/// Online/offline signal. Wraps `connectivity_plus`, collapsing its list of
/// interfaces into a single boolean the app reasons about.
///
/// Connectivity here means "has a network interface", not "the server is
/// reachable" — the outbox handles the case where we think we're online but a
/// call still fails.
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return _online(result);
  }

  Stream<bool> onlineChanges() =>
      _connectivity.onConnectivityChanged.map(_online);

  bool _online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
