import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Single connectivity signal for ads. Not a guarantee of internet.
class NetworkGuard {
  NetworkGuard({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _onlineController = StreamController<bool>.broadcast();
  bool _online = false;
  VoidCallback? _onOnline;
  VoidCallback? _onOffline;
  Timer? _debounce;

  bool get isOnline => _online;

  /// Emits whenever online/offline flips (after debounce for online).
  Stream<bool> get onStatusChanged => _onlineController.stream;

  Future<void> start({
    VoidCallback? onOnline,
    VoidCallback? onOffline,
  }) async {
    _onOnline = onOnline;
    _onOffline = onOffline;
    try {
      _online = _usable(await _connectivity.checkConnectivity());
    } catch (_) {
      _online = false;
    }
    // Notify listeners of the initial snapshot (AdsService still handles its
    // own first-online path in init — onOnline is only for later restores).
    if (!_onlineController.isClosed) {
      _onlineController.add(_online);
    }
    await _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final next = _usable(results);
      if (next == _online) return;
      _online = next;
      if (!next) {
        _debounce?.cancel();
        if (!_onlineController.isClosed) _onlineController.add(false);
        _onOffline?.call();
        return;
      }
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), () {
        if (!_online) return;
        if (!_onlineController.isClosed) _onlineController.add(true);
        _onOnline?.call();
      });
    });
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await _subscription?.cancel();
    await _onlineController.close();
  }

  static bool _usable(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }
}
