import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import '../core/network/error_handler.dart';
import '../core/network/token_store.dart';
import '../models/user.dart';

class AuthService {
  static const String tokenKey = 'auth_token';

  // Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await DioClient.instance.post<Map<String, dynamic>>(
        '/auth/login',
        headers: {'Content-Type': 'application/json'},
        data: {'username': username, 'password': password},
      );
      final data = res.data!;
      final token = data['access_token'] as String;
      await saveToken(token);
      await attachTokenToDio();
      final user = User.fromJson(data['user']);
      return {'success': true, 'user': user, 'token': token};
    } on DioException catch (e) {
      return {'success': false, 'message': e.message ?? 'حدث خطأ في تسجيل الدخول'};
    } catch (e) {
      return {'success': false, 'message': ErrorHandler.toMessage(e)};
    }
  }

  // Get current user
  Future<User?> getCurrentUser() async {
    try {
      await attachTokenToDio();
      final res = await DioClient.instance.get<Map<String, dynamic>>('/auth/me');
      return User.fromJson(res.data!['user']);
    } catch (_) {
      return null;
    }
  }

  // Get token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    TokenStore.setToken(null);
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    return token != null;
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    TokenStore.setToken(token);
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    TokenStore.setToken(token);
  }

  Future<void> attachTokenToDio() async {
    if (TokenStore.token == null) {
      await loadToken();
    }
    // TokenInterceptor سيضيف الـ header تلقائياً من TokenStore
  }
}
