import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'dio_client.dart';

class RetryInterceptor extends Interceptor {
  RetryInterceptor({this.maxRetries = 3, this.delay = const Duration(seconds: 2)});

  final int maxRetries;
  final Duration delay;

  bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }
    // SocketException in unknown
    if (err.type == DioExceptionType.unknown && err.error is SocketException) {
      return true;
    }
    return false;
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final current = (req.extra['retries'] as int?) ?? 0;
    if (current < maxRetries && _shouldRetry(err)) {
      await Future.delayed(delay);
      final newOptions = Options(
        method: req.method,
        headers: Map<String, dynamic>.from(req.headers),
        responseType: req.responseType,
        contentType: req.contentType,
        followRedirects: req.followRedirects,
        validateStatus: req.validateStatus,
        receiveDataWhenStatusError: req.receiveDataWhenStatusError,
        extra: {...req.extra, 'retries': current + 1},
      );
      try {
        final dio = err.requestOptions.extra['dio'] as Dio? ?? DioClient.instance.raw;
        final response = await dio.request(
          req.path,
          data: req.data,
          queryParameters: Map<String, dynamic>.from(req.queryParameters),
          options: newOptions,
          cancelToken: req.cancelToken,
          onReceiveProgress: req.onReceiveProgress,
          onSendProgress: req.onSendProgress,
        );
        return handler.resolve(response);
      } catch (_) {
        // fallthrough to default handler
      }
    }
    return handler.next(err);
  }
}


