import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_utils.dart';

class ApiAuth {
  static final Logger _logger = Logger();

  static Future<bool> isAuthenticated() async {
    final token = await ApiUtils.getToken();
    if (token == null) {
      _logger.w('No token, user not authenticated');
      return false;
    }

    if (!await ApiUtils.isOnline()) {
      _logger.d('Offline mode, assuming authenticated');
      return true;
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().get(
          '${ApiUtils.baseUrl}/auth/me',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
            },
          ),
        );
      });
      _logger.i('User authenticated: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Authentication check failed: $e');
      return false;
    }
  }

  static Future<void> refreshToken() async {
    final refreshToken = await ApiUtils.getRefreshToken();
    if (refreshToken == null) {
      _logger.e('No refresh token available');
      throw Exception('Refresh token отсутствует');
    }

    try {
      final response = await Dio().post(
        '${ApiUtils.baseUrl}/auth/refresh',
        options: Options(
          headers: {
            'Authorization': 'Bearer $refreshToken',
            'Content-Type': 'application/json; charset=utf-8',
          },
        ),
      );

      if (response.statusCode != 200) {
        _logger.e('Failed to refresh token: ${response.statusCode} - ${response.data}');
        await logout();
        throw Exception('Не удалось обновить токен: ${response.data}');
      }

      final data = response.data;
      if (data['access_token'] == null || data['refresh_token'] == null) {
        _logger.e('Invalid token refresh response: $data');
        await logout();
        throw Exception('Неверный формат ответа сервера при обновлении токена');
      }

      await ApiUtils.saveToken(data['access_token'], data['refresh_token']);
      _logger.i('Token refreshed successfully: access_token=${data['access_token']}');
    } catch (e) {
      _logger.e('Error refreshing token: $e, Response: ${e is DioException ? e.response : 'No response'}');
      rethrow;
    }
  }

  static Future<void> logout() async {
    await ApiUtils.clearCache();
    _logger.i('User logged out');
  }

  static Future<Map<String, dynamic>> checkEmail(String email) async {
    try {
      final response = await Dio().post(
        '${ApiUtils.baseUrl}/auth/check-email',
        data: jsonEncode({'email': email.toLowerCase().trim()}),
        options: Options(
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json; charset=utf-8',
          },
        ),
      );

      if (response.statusCode != 200) {
        _logger.e('Failed to check email: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось проверить email: ${response.data['detail']}');
      }
      _logger.i('Email checked: ${response.data}');
      return response.data;
    } catch (e) {
      _logger.e('Error in checkEmail: $e');
      rethrow;
    }
  }

  static Future<void> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    String? birthDate,
    String? gender,
    bool? notificationsEnabled,
  }) async {
    try {
      final response = await Dio().post(
        '${ApiUtils.baseUrl}/auth/register',
        data: jsonEncode({
          'username': username.trim(),
          'email': email.toLowerCase().trim(),
          'password': password.trim(),
          'password_confirm': passwordConfirm.trim(),
          'birth_date': birthDate?.trim(),
          'gender': gender,
          'notifications_enabled': notificationsEnabled ?? false,
        }),
        options: Options(
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json; charset=utf-8',
          },
        ),
      );

      if (response.statusCode != 200) {
        _logger.e('Failed to register: ${response.statusCode} - ${response.data}');
        throw Exception(response.data['detail']);
      }

      final data = response.data;
      await ApiUtils.saveToken(data['access_token'], data['refresh_token']);
      final prefs = await SharedPreferences.getInstance();
      if (data['user_id'] != null) {
        await prefs.setString('user_id', data['user_id'].toString());
        _logger.i('Registered: user_id = ${data['user_id']}');
      }
    } catch (e) {
      _logger.e('Error registering: $e');
      rethrow;
    }
  }

  static Future<void> login(String email, String password) async {
    try {
      final response = await Dio().post(
        '${ApiUtils.baseUrl}/auth/login',
        data: jsonEncode({
          'email': email.toLowerCase().trim(),
          'password': password.trim(),
        }),
        options: Options(
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json; charset=utf-8',
          },
        ),
      );

      if (response.statusCode != 200) {
        _logger.e('Failed to login: ${response.statusCode} - ${response.data}');
        throw Exception(response.data['detail']);
      }

      final data = response.data;
      await ApiUtils.saveToken(data['access_token'], data['refresh_token']);
      final prefs = await SharedPreferences.getInstance();
      if (data['user_id'] != null) {
        await prefs.setString('user_id', data['user_id'].toString());
        _logger.i('Logged in: user_id = ${data['user_id']}');
      }
    } catch (e) {
      _logger.e('Error logging in: $e');
      rethrow;
    }
  }
}
