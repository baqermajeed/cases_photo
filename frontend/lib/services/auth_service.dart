import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/api_constants.dart';
import '../models/user.dart';

class AuthService {
  final storage = const FlutterSecureStorage();
  static const String tokenKey = 'auth_token';
  static const Duration _timeout = Duration(seconds: 12);

  // Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        // Save token
        final token = data['access_token'] as String;
        await storage.write(key: tokenKey, value: token);
        
        // Parse user
        final user = User.fromJson(data['user']);
        
        return {
          'success': true,
          'user': user,
          'token': token,
        };
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'message': error['detail'] ?? 'حدث خطأ في تسجيل الدخول',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'انتهت مهلة الاتصال. تحقق من الشبكة.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'تعذر الاتصال بالخادم. تحقق من اتصال الإنترنت.',
      };
    }
  }

  // Get current user
  Future<User?> getCurrentUser() async {
    try {
      final token = await storage.read(key: tokenKey);
      if (token == null) return null;

      final response = await http
          .get(
            Uri.parse('${ApiConstants.baseUrl}${ApiConstants.me}'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return User.fromJson(data['user']);
      }
      return null;
    } on TimeoutException {
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get token
  Future<String?> getToken() async {
    return await storage.read(key: tokenKey);
  }

  // Logout
  Future<void> logout() async {
    await storage.delete(key: tokenKey);
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await storage.read(key: tokenKey);
    return token != null;
  }
}
