import 'dart:io';
import 'dart:async' as async;
import 'package:dio/dio.dart';

class ErrorHandler {
  static String toMessage(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'انتهت مهلة الاتصال';
        case DioExceptionType.connectionError:
          if (error.error is SocketException) {
            return 'تعذّر الوصول إلى السيرفر';
          }
          return 'تعذّر الوصول إلى السيرفر';
        case DioExceptionType.badResponse:
          return 'تعذّر الوصول إلى السيرفر';
        case DioExceptionType.cancel:
          return 'تم إلغاء الطلب';
        case DioExceptionType.badCertificate:
          return 'مشكلة في الشهادة الأمنية';
        case DioExceptionType.unknown:
        default:
          return 'الاتصال بالإنترنت ضعيف جداً';
      }
    }
    if (error is SocketException) {
      return 'تعذّر الوصول إلى السيرفر';
    }
    if (error is async.TimeoutException) {
      return 'انتهت مهلة الاتصال';
    }
    return 'حدث خطأ غير متوقع';
  }
}


