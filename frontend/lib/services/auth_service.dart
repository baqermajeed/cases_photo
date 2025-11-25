import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/api_constants.dart';
import '../models/user.dart';
import 'dio_client.dart';
import 'network_checker.dart';

class AuthService {
  final storage = const FlutterSecureStorage();
  static const tokenKey = 'auth_token';

  Future<String?> getToken() async {
    return await storage.read(key: tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await storage.read(key: tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await storage.delete(key: tokenKey);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      // Check internet first
      if (!await NetworkChecker.hasInternet()) {
        return {'success': false, 'message': 'لا يوجد اتصال بالإنترنت'};
      }

      final response = await DioClient.dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.login}',
        data: {
          'username': username,
          'password': password,
        },
      );

      final data = response.data;
      final token = data['access_token'];

      await storage.write(key: tokenKey, value: token);

      final user = User.fromJson(data['user']);

      return {
        'success': true,
        'user': user,
        'token': token,
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return {'success': false, 'message': 'اسم المستخدم أو كلمة المرور غير صحيحة'};
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.unknown) {
        return {'success': false, 'message': 'تعذر الاتصال بالخادم. تحقق من الإنترنت ثم أعد المحاولة'};
      }
      final serverMessage = (e.response?.data is Map<String, dynamic>)
          ? (e.response?.data['detail']?.toString())
          : null;
      return {'success': false, 'message': serverMessage ?? 'حدث خطأ غير متوقع'};
    } catch (_) {
      return {'success': false, 'message': 'حدث خطأ غير متوقع'};
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final token = await storage.read(key: tokenKey);
      if (token == null) return null;

      final response = await DioClient.dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.me}',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      return User.fromJson(response.data['user']);
    } catch (_) {
      return null;
    }
  }
}
