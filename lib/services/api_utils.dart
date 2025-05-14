import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/api_auth.dart';
import 'package:image/image.dart' as img;

class ApiUtils {
  static const String baseUrl = 'http://192.168.1.147:8000';
  static const int defaultTimeoutSeconds = 10;
  static const int newsTtlSeconds = 3600; // 1 час
  static const int recipesTtlSeconds = 3600; // 1 час
  static const int ingredientsTtlSeconds = 86400; // 24 часа
  static const int favoritesTtlSeconds = 86400; // 24 часа
  static const int profileTtlSeconds = 3600; // 1 час
  static const int imageTtlSeconds = 86400; // 24 часа для изображений

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: defaultTimeoutSeconds),
    receiveTimeout: const Duration(seconds: defaultTimeoutSeconds),
  ));
  static final Logger _logger = Logger();

  static Future<void> saveToken(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
    _logger.i('Tokens saved: access_token=$accessToken, refresh_token=$refreshToken');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    _logger.d('Retrieved token: $token');
    return token;
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('refresh_token');
    _logger.d('Retrieved refresh token: $token');
    return token;
  }

  static Future<void> saveCachedData(String key, String data, {required int ttlSeconds, String? version}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, data);
    await prefs.setInt('${key}_ttl', DateTime.now().millisecondsSinceEpoch + ttlSeconds * 1000);
    if (version != null) {
      await prefs.setString('${key}_version', version);
    }
    _logger.i('Cached data saved for key: $key with TTL: $ttlSeconds seconds, version: $version');
  }

  static Future<Map<String, dynamic>?> getCachedData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    if (data != null) {
      final ttl = prefs.getInt('${key}_ttl');
      if (ttl != null && DateTime.now().millisecondsSinceEpoch > ttl) {
        await prefs.remove(key);
        await prefs.remove('${key}_ttl');
        await prefs.remove('${key}_version');
        _logger.w('Cache expired for key: $key');
        return null;
      }
      final version = prefs.getString('${key}_version');
      _logger.d('Retrieved cached data for key: $key, version: $version');
      return {'data': data, 'version': version};
    }
    return null;
  }

  static Future<String> getCachedImagePath(int id, String type) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/${type}_image_$id.jpg';
  }

  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final online = connectivityResult != ConnectivityResult.none;
    _logger.d('Network status: ${online ? 'Online' : 'Offline'}');
    return online;
  }

  static Future<Response> makeRequest(
      Future<Response> Function(String token) requestFunc, {
        bool retryOnAuthFail = true,
        int maxRetries = 1, // Ограничим количество повторных попыток
      }) async {
    String? token = await getToken();
    if (token == null) {
      _logger.e('No token available');
      throw Exception('Пользователь не авторизован');
    }

    try {
      final response = await requestFunc(token);
      _logger.i('Request successful: ${response.requestOptions.uri} - ${response.statusCode}');
      return response;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401 && retryOnAuthFail && maxRetries > 0) {
        _logger.w('Token expired or invalid, attempting to refresh...');
        try {
          await ApiAuth.refreshToken();
          token = await getToken();
          if (token == null) {
            _logger.e('Failed to retrieve new token after refresh');
            throw Exception('Не удалось обновить токен');
          }
          _logger.d('New token retrieved: $token');
          // Повторяем запрос с новым токеном и уменьшаем количество попыток
          return await makeRequest(requestFunc, retryOnAuthFail: true, maxRetries: maxRetries - 1);
        } catch (refreshError) {
          _logger.e('Token refresh failed: $refreshError');
          throw Exception('Не удалось обновить токен: $refreshError');
        }
      }
      _logger.e('Request failed: $e');
      rethrow;
    }
  }

  static Future<String?> downloadImage(int id, String type, String url, {String? serverVersion}) async {
    final imagePath = await getCachedImagePath(id, type);
    final file = File(imagePath);
    final prefs = await SharedPreferences.getInstance();
    final cachedVersion = prefs.getString('${type}_image_${id}_version');

    if (!await isOnline() && await file.exists()) {
      _logger.d('Offline: Returning cached image: $imagePath');
      return imagePath;
    }

    if (await file.exists() && cachedVersion != null && serverVersion != null && cachedVersion == serverVersion) {
      _logger.d('Cached image is up-to-date: $imagePath, version: $cachedVersion');
      return imagePath;
    }

    try {
      final initialResponse = await _dio.get(
        url,
        options: Options(responseType: ResponseType.json),
      );
      if (initialResponse.statusCode != 200 || initialResponse.data['image_url'] == null) {
        _logger.w('Failed to get image URL: ${initialResponse.statusCode}');
        return await file.exists() ? imagePath : null;
      }

      final imageUrl = initialResponse.data['image_url'] as String;
      final imageResponse = await _dio.get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      if (imageResponse.statusCode == 200) {
        await file.writeAsBytes(imageResponse.data);
        if (serverVersion != null) {
          await prefs.setString('${type}_image_${id}_version', serverVersion);
          await prefs.setInt('${type}_image_${id}_ttl', DateTime.now().millisecondsSinceEpoch + imageTtlSeconds * 1000);
        }
        _logger.i('Image downloaded and cached: $imagePath, version: $serverVersion');

        try {
          final decodedImage = img.decodeImage(imageResponse.data);
          if (decodedImage == null) {
            _logger.e('Failed to decode image: null result');
            await file.delete();
            return null;
          }
        } catch (e) {
          _logger.e('Failed to decode image after download: $e');
          await file.delete();
          return null;
        }

        return imagePath;
      }
      _logger.w('Failed to download image: ${imageResponse.statusCode}');
      return await file.exists() ? imagePath : null;
    } catch (e) {
      _logger.e('Error downloading image: $e');
      return await file.exists() ? imagePath : null;
    }
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync();
    for (var file in files) {
      if (file is File && file.path.contains('_image_')) {
        await file.delete();
        _logger.i('Deleted cached image: ${file.path}');
      }
    }
    _logger.i('Cache cleared');
  }

  static Future<bool> isCacheOutdated(String key, String serverVersion) async {
    final cachedData = await getCachedData(key);
    if (cachedData == null) return true;
    final cachedVersion = cachedData['version'];
    return cachedVersion == null || cachedVersion != serverVersion;
  }
}
