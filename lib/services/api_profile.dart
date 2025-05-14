import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'api_utils.dart';

class ApiProfile {
  static const String cacheKey = 'cached_protected_data';
  static final Logger _logger = Logger();

  static Future<Map<String, dynamic>> getProtectedData({bool forceRefresh = false}) async {
    final isOnline = await ApiUtils.isOnline();
    final cachedData = await ApiUtils.getCachedData(cacheKey);

    if (!forceRefresh && cachedData != null && (isOnline || cachedData['data']!.isNotEmpty)) {
      _logger.d('Returning cached profile data, version: ${cachedData['version']}');
      return jsonDecode(cachedData['data']) as Map<String, dynamic>;
    }

    if (!isOnline) {
      if (cachedData != null) {
        _logger.d('Offline: Returning cached profile data');
        return jsonDecode(cachedData['data']) as Map<String, dynamic>;
      }
      _logger.w('Offline and no cached profile data available');
      return {'message': 'Добро пожаловать в MealFlow (оффлайн)'};
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

      if (response.statusCode != 200) {
        _logger.e('Failed to load profile data: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось загрузить данные пользователя');
      }

      final data = response.data as Map<String, dynamic>;
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();
      _logger.i('Server response: $data');
      await ApiUtils.saveCachedData(
        cacheKey,
        jsonEncode(data),
        ttlSeconds: ApiUtils.profileTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Profile data loaded and cached, version: $serverVersion');
      return data;
    } catch (e) {
      _logger.e('Error loading profile data: $e');
      if (cachedData != null && !forceRefresh) {
        return jsonDecode(cachedData['data']) as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  static Future<void> deleteUser() async {
    if (!await ApiUtils.isOnline()) {
      throw Exception('Для удаления пользователя требуется интернет');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().delete(
          '${ApiUtils.baseUrl}/auth/delete',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
            },
          ),
        );
      });

      if (response.statusCode != 204) {
        _logger.e('Failed to delete user: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось удалить пользователя: ${response.data}');
      }

      await ApiUtils.clearCache();
      _logger.i('User deleted and cache cleared');
    } catch (e) {
      _logger.e('Error deleting user: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? email,
    String? gender,
    bool? notificationsEnabled,
  }) async {
    if (!await ApiUtils.isOnline()) {
      throw Exception('Для обновления профиля требуется интернет');
    }

    final body = <String, dynamic>{};
    if (email != null) body['email'] = email.toLowerCase().trim();
    if (gender != null && ['Мужской', 'Женский', 'Не указан'].contains(gender)) {
      body['gender'] = gender;
    }
    if (notificationsEnabled != null) body['notifications_enabled'] = notificationsEnabled;

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().put(
          '${ApiUtils.baseUrl}/auth/update',
          data: jsonEncode(body),
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
            },
          ),
        );
      });

      if (response.statusCode != 200) {
        _logger.e('Failed to update profile: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось обновить профиль: ${response.data['detail']}');
      }

      final data = response.data;
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        cacheKey,
        jsonEncode(data),
        ttlSeconds: ApiUtils.profileTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Profile updated and cached, version: $serverVersion');
      return data;
    } catch (e) {
      _logger.e('Error updating profile: $e');
      rethrow;
    }
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    if (!await ApiUtils.isOnline()) {
      throw Exception('Для смены пароля требуется интернет');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().put(
          '${ApiUtils.baseUrl}/auth/change-password',
          data: jsonEncode({
            'current_password': currentPassword.trim(),
            'new_password': newPassword.trim(),
            'new_password_confirm': newPasswordConfirm.trim(),
          }),
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
            },
          ),
        );
      });

      if (response.statusCode != 200) {
        _logger.e('Failed to change password: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось сменить пароль: ${response.data['detail']}');
      }
      _logger.i('Password changed successfully');
    } catch (e) {
      _logger.e('Error changing password: $e');
      rethrow;
    }
  }

  static Future<void> resendVerificationEmail() async {
    if (!await ApiUtils.isOnline()) {
      throw Exception('Для отправки письма подтверждения требуется интернет');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().post(
          '${ApiUtils.baseUrl}/auth/resend-verification',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json; charset=utf-8',
            },
          ),
        );
      });

      if (response.statusCode != 200) {
        _logger.e('Failed to resend verification email: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось отправить письмо подтверждения: ${response.data['detail']}');
      }
      _logger.i('Verification email resent successfully');
    } catch (e) {
      _logger.e('Error resending verification email: $e');
      rethrow;
    }
  }
}
