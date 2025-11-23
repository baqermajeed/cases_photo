import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../constants/api_constants.dart';
import 'network_checker.dart';
import 'retry_interceptor.dart';
import 'error_handler.dart';
import 'token_interceptor.dart';

class DioClient {
  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {'Connection': 'close'},
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );
    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);
      client.idleTimeout = const Duration(seconds: 0); // minimize keep-alive
      return client;
    };
    _dio.httpClientAdapter = adapter;
    _dio.interceptors.addAll([
      TokenInterceptor(),
      RetryInterceptor(maxRetries: 3, delay: const Duration(seconds: 2)),
    ]);
  }

  static final DioClient instance = DioClient._internal();

  late final Dio _dio;

  Dio get raw => _dio;

  Future<Response<T>> _safeRequest<T>(
    Future<Response<T>> Function() call,
  ) async {
    final ok = await NetworkChecker.instance.isConnected();
    if (!ok) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
        error: const SocketException('No internet'),
      );
    }
    try {
      final res = await call();
      return res;
    } on DioException catch (e) {
      final friendly = ErrorHandler.toMessage(e);
      throw DioException(
        requestOptions: e.requestOptions,
        response: e.response,
        error: e.error,
        type: e.type,
        message: friendly,
        stackTrace: e.stackTrace,
      );
    } catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.unknown,
        error: e,
        message: ErrorHandler.toMessage(e),
      );
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    return _safeRequest<T>(() {
      return _dio.get<T>(
        path,
        queryParameters: query,
        options: Options(headers: headers, extra: {'dio': _dio}),
      );
    });
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, String>? headers,
    String? contentType,
  }) async {
    return _safeRequest<T>(() {
      return _dio.post<T>(
        path,
        data: data,
        options: Options(headers: headers, contentType: contentType, extra: {'dio': _dio}),
      );
    });
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    return _safeRequest<T>(() {
      return _dio.patch<T>(
        path,
        data: data,
        options: Options(headers: headers, extra: {'dio': _dio}),
      );
    });
  }

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
  }) async {
    return _safeRequest<T>(() {
      return _dio.delete<T>(
        path,
        options: Options(headers: headers, extra: {'dio': _dio}),
      );
    });
  }
}


