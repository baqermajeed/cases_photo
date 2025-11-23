import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  final ValueNotifier<bool> online = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    // initial check (v6 returns a list of results)
    Connectivity().checkConnectivity().then((results) {
      online.value = _isOnlineList(results);
    });
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      online.value = _isOnlineList(results);
    });
  }

  bool _isOnline(ConnectivityResult result) => result != ConnectivityResult.none;

  bool _isOnlineList(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => _isOnline(r));
  }

  Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return _isOnlineList(results);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}


