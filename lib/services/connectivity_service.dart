import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_service.dart';

// ──────────────────────────────────────────────
// Connectivity service — monitors network & triggers sync
// ──────────────────────────────────────────────

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  late final StreamController<bool> _controller;
  late final Stream<bool> onlineStatus;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  void init() {
    _controller = StreamController<bool>.broadcast();
    onlineStatus = _controller.stream;

    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(online);
        if (online) _syncPending();
      }
    });

    // Check initial state.
    _connectivity.checkConnectivity().then((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      _controller.add(_isOnline);
    });
  }

  Future<void> _syncPending() async {
    try {
      await OfflineService.instance.syncPendingChanges();
    } catch (e) {
      debugPrint('ConnectivityService: sync failed: $e');
    }
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

// ──────────────────────────────────────────────
// Riverpod provider
// ──────────────────────────────────────────────

final connectivityProvider = StreamProvider<bool>((ref) {
  final service = ConnectivityService.instance;
  return service.onlineStatus;
});
