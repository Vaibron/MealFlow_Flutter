import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'api_utils.dart';

class ApiNews {
  static const String cacheKey = 'cached_news';
  static final Logger _logger = Logger();

  static Future<List<Map<String, dynamic>>> getNews({
    int skip = 0,
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    // Оставляем без изменений, так как работает корректно
    final isOnline = await ApiUtils.isOnline();
    final cachedNews = await ApiUtils.getCachedData(cacheKey);

    if (!forceRefresh && cachedNews != null && (isOnline || cachedNews['data']!.isNotEmpty)) {
      _logger.d('Returning cached news, version: ${cachedNews['version']}');
      return List<Map<String, dynamic>>.from(jsonDecode(cachedNews['data']));
    }

    if (!isOnline) {
      if (cachedNews != null) {
        _logger.d('Offline: Returning cached news');
        return List<Map<String, dynamic>>.from(jsonDecode(cachedNews['data']));
      }
      _logger.w('Offline and no cached news available');
      throw Exception('Нет интернета и кэшированных данных');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().get(
          '${ApiUtils.baseUrl}/news/',
          queryParameters: {'skip': skip, 'limit': limit},
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
        _logger.e('Failed to load news: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось загрузить новости: ${response.data['detail']}');
      }

      final newsData = response.data as List;
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        cacheKey,
        jsonEncode(newsData),
        ttlSeconds: ApiUtils.newsTtlSeconds,
        version: serverVersion,
      );
      _logger.i('News loaded and cached, version: $serverVersion');
      return newsData.cast<Map<String, dynamic>>();
    } catch (e) {
      _logger.e('Error loading news: $e');
      if (cachedNews != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(cachedNews['data']));
      }
      rethrow;
    }
  }

  static Future<String?> getNewsImageUrl(int newsId, {bool forceRefresh = false}) async {
    final baseImageUrl = '${ApiUtils.baseUrl}/news/image/$newsId';
    final imageUrl = forceRefresh ? '$baseImageUrl?ts=${DateTime.now().millisecondsSinceEpoch}' : baseImageUrl;

    final cachedPath = await ApiUtils.getCachedImagePath(newsId, 'news');
    final cachedFile = File(cachedPath);

    if (!forceRefresh && await cachedFile.exists()) {
      _logger.d('Returning cached image: $cachedPath');
      return cachedPath; // Возвращаем путь, если файл существует
    }

    if (!await ApiUtils.isOnline()) {
      _logger.w('Offline and no cached image available for newsId: $newsId');
      return await cachedFile.exists() ? cachedPath : null;
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().get(
          imageUrl,
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            responseType: ResponseType.json, // Ожидаем JSON с image_url
          ),
        );
      });

      if (response.statusCode != 200 || response.data['image_url'] == null) {
        _logger.w('Failed to get image URL: ${response.statusCode}');
        return await cachedFile.exists() ? cachedPath : null;
      }

      final serverImageUrl = response.data['image_url'] as String;
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();

      final imagePath = await ApiUtils.downloadImage(newsId, 'news', imageUrl, serverVersion: serverVersion);
      if (imagePath != null) {
        _logger.i('Image downloaded successfully: $imagePath');
        return imagePath;
      } else {
        _logger.w('Image download returned null, falling back to cached path');
        return await cachedFile.exists() ? cachedPath : null;
      }
    } catch (e) {
      _logger.e('Error fetching news image: $e');
      return await cachedFile.exists() ? cachedPath : null;
    }
  }
}
