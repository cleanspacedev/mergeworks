import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device currently has *any* network connectivity.
///
/// Note: This indicates network connectivity type, not guaranteed internet reachability.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _hasNetwork = true;
  bool get hasNetwork => _hasNetwork;

  Future<void> init() async {
    // Prime initial state.
    try {
      final results = await _connectivity.checkConnectivity();
      _setFromResults(results);
    } catch (e) {
      debugPrint('ConnectivityService init failed: $e');
      // Assume network is available so we don't incorrectly push users offline.
      _hasNetwork = true;
    }

    // Keep updated.
    try {
      _sub?.cancel();
      _sub = _connectivity.onConnectivityChanged.listen(_setFromResults);
    } catch (e) {
      debugPrint('ConnectivityService subscription failed: $e');
    }
  }

  void _setFromResults(List<ConnectivityResult> results) {
    final nextHasNetwork = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (nextHasNetwork == _hasNetwork) return;
    _hasNetwork = nextHasNetwork;
    notifyListeners();
  }

  @override
  void dispose() {
    try {
      _sub?.cancel();
    } catch (_) {}
    super.dispose();
  }
}
