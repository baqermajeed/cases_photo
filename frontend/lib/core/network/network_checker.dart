import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';

class NetworkChecker {
  NetworkChecker._internal();
  static final NetworkChecker instance = NetworkChecker._internal();

  // Consider connection weak if checks exceed this duration
  static const Duration _maxAcceptableLatency = Duration(milliseconds: 1500);

  Future<bool> isConnected() async {
    // 1) Quick connectivity state
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.isEmpty || connectivity.every((r) => r == ConnectivityResult.none)) {
      return false;
    }

    final Stopwatch sw = Stopwatch()..start();
    // 2) DNS resolution
    try {
      final res = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
      if (res.isEmpty) return false;
    } catch (_) {
      return false;
    }

    // 3) Reachability to our backend (fast health endpoint)
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 3),
        sendTimeout: const Duration(seconds: 3),
        validateStatus: (s) => s != null && s >= 200 && s < 300,
        headers: const {'Connection': 'close'},
      ));
      await dio.get('/health');
    } catch (_) {
      return false;
    }

    sw.stop();
    if (sw.elapsed > _maxAcceptableLatency) {
      // Connection exists but too weak
      return false;
    }
    return true;
  }
}


