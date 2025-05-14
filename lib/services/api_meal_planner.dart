import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_utils.dart';

class ApiMealPlanner {
  static const String mealPlanCacheKey = 'cached_meal_plan';
  static const String excludedIngredientsCacheKey = 'cached_excluded_ingredients';
  static final Logger _logger = Logger();

  static Future<Map<String, dynamic>?> getMealPlan({bool forceRefresh = false}) async {
    final isOnline = await ApiUtils.isOnline();
    final cachedMealPlan = await ApiUtils.getCachedData(mealPlanCacheKey);

    if (!forceRefresh && cachedMealPlan != null && (isOnline || cachedMealPlan['data']!.isNotEmpty)) {
      _logger.d('Returning cached meal plan, version: ${cachedMealPlan['version']}');
      return jsonDecode(cachedMealPlan['data']) as Map<String, dynamic>;
    }

    if (!isOnline && cachedMealPlan != null) {
      _logger.d('Offline: Returning cached meal plan');
      return jsonDecode(cachedMealPlan['data']) as Map<String, dynamic>;
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().get(
          '${ApiUtils.baseUrl}/meal-planner/current',
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
        _logger.e('Failed to load meal plan: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось загрузить план меню: ${response.statusCode}');
      }

      final mealPlanData = response.data;
      if (mealPlanData['id'] == null) {
        _logger.i('No meal plan exists yet');
        return null;
      }

      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        mealPlanCacheKey,
        jsonEncode(mealPlanData),
        ttlSeconds: ApiUtils.recipesTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Meal plan loaded and cached, version: $serverVersion');
      return mealPlanData;
    } catch (e) {
      _logger.e('Error loading meal plan: $e');
      if (cachedMealPlan != null) {
        return jsonDecode(cachedMealPlan['data']) as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> generateMealPlan({
    required DateTime startDate,
    required int days,
    required int persons,
    List<int>? excludedIngredients,
    String recipeSource = 'both',
  }) async {
    if (!await ApiUtils.isOnline()) {
      throw Exception('Для генерации меню требуется интернет');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().post(
          '${ApiUtils.baseUrl}/meal-planner/generate',
          data: jsonEncode({
            'start_date': startDate.toIso8601String(),
            'days': days,
            'persons': persons,
            'excluded_ingredients': excludedIngredients ?? [],
            'recipe_source': recipeSource,
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
        _logger.e('Failed to generate meal plan: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось сгенерировать меню: ${response.statusCode}');
      }

      final mealPlanData = response.data;
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        mealPlanCacheKey,
        jsonEncode(mealPlanData),
        ttlSeconds: ApiUtils.recipesTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Meal plan generated and cached, version: $serverVersion');
      return mealPlanData;
    } catch (e) {
      _logger.e('Error generating meal plan: $e');
      rethrow;
    }
  }

  static Future<List<dynamic>> getExcludedIngredients({bool forceRefresh = false}) async {
    final isOnline = await ApiUtils.isOnline();
    final cachedExcluded = await ApiUtils.getCachedData(excludedIngredientsCacheKey);

    if (!forceRefresh && cachedExcluded != null && (isOnline || cachedExcluded['data']!.isNotEmpty)) {
      _logger.d('Returning cached excluded ingredients, version: ${cachedExcluded['version']}');
      return jsonDecode(cachedExcluded['data']) as List<dynamic>;
    }

    if (!isOnline && cachedExcluded != null) {
      _logger.d('Offline: Returning cached excluded ingredients');
      return jsonDecode(cachedExcluded['data']) as List<dynamic>;
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().get(
          '${ApiUtils.baseUrl}/meal-planner/excluded-ingredients',
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
        _logger.e('Failed to load excluded ingredients: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось загрузить исключенные ингредиенты: ${response.statusCode}');
      }

      final excludedData = response.data;
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        excludedIngredientsCacheKey,
        jsonEncode(excludedData),
        ttlSeconds: ApiUtils.ingredientsTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Excluded ingredients loaded and cached, version: $serverVersion');
      return excludedData;
    } catch (e) {
      _logger.e('Error loading excluded ingredients: $e');
      if (cachedExcluded != null) {
        return jsonDecode(cachedExcluded['data']) as List<dynamic>;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> replaceRecipe({
    required String date,
    required int mealTypeId,
    int? newRecipeId,
  }) async {
    if (!await ApiUtils.isOnline()) {
      throw Exception('Для замены рецепта требуется интернет');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().post(
          '${ApiUtils.baseUrl}/meal-planner/replace-recipe',
          data: jsonEncode({
            'date': date,
            'meal_type_id': mealTypeId,
            'new_recipe_id': newRecipeId,
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
        _logger.e('Failed to replace recipe: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось заменить рецепт: ${response.statusCode}');
      }

      final mealPlanData = response.data;
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();

      // Принудительно очищаем старый кэш
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(mealPlanCacheKey);

      // Сохраняем новый кэш
      await ApiUtils.saveCachedData(
        mealPlanCacheKey,
        jsonEncode(mealPlanData),
        ttlSeconds: ApiUtils.recipesTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Recipe replaced and meal plan cached, version: $serverVersion');
      return mealPlanData;
    } catch (e) {
      _logger.e('Error replacing recipe: $e');
      rethrow;
    }
  }
}
