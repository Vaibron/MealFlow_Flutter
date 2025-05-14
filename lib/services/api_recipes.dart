import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_utils.dart';

class ApiRecipes {
  static const String userRecipesCacheKey = 'cached_user_recipes';
  static const String mealflowRecipesCacheKey = 'cached_mealflow_recipes';
  static const String ingredientsCacheKey = 'cached_ingredients';
  static const String favoritesCacheKey = 'cached_saved_mealflow_ids';
  static const String mealTypesCacheKey = 'cached_meal_types';
  static const String dishCategoriesCacheKey = 'cached_dish_categories';
  static const String tagsCacheKey = 'cached_tags';
  static final Logger _logger = Logger();

  static Future<List<dynamic>> getRecipes({
    bool showMealflow = false,
    String? search,
    int skip = 0,
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    final cacheKey = showMealflow ? mealflowRecipesCacheKey : userRecipesCacheKey;
    final isOnline = await ApiUtils.isOnline();
    final cachedRecipes = await ApiUtils.getCachedData('$cacheKey${search ?? ''}'); // Уникальный ключ для поиска

    if (!forceRefresh && cachedRecipes != null && search == null && (isOnline || cachedRecipes['data']!.isNotEmpty)) {
      _logger.d('Returning cached recipes from $cacheKey, version: ${cachedRecipes['version']}');
      return jsonDecode(cachedRecipes['data']) as List<dynamic>;
    }

    if (!isOnline) {
      if (cachedRecipes != null) {
        _logger.d('Offline: Returning cached recipes from $cacheKey');
        return jsonDecode(cachedRecipes['data']) as List<dynamic>;
      }
      _logger.w('Offline and no cached recipes available');
      throw Exception('Нет интернета и кэшированных рецептов');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().get(
          '${ApiUtils.baseUrl}/recipes/',
          queryParameters: {
            'show_mealflow': showMealflow,
            if (search != null && search.isNotEmpty) 'search': search,
            'skip': skip,
            'limit': limit,
          },
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
        _logger.e('Failed to load recipes: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось загрузить рецепты: ${response.data}');
      }

      final recipesData = response.data;
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        '$cacheKey${search ?? ''}', // Сохраняем с учетом поискового запроса
        jsonEncode(recipesData),
        ttlSeconds: ApiUtils.recipesTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Recipes loaded and cached, version: $serverVersion');
      return recipesData;
    } catch (e) {
      _logger.e('Error loading recipes: $e');
      if (cachedRecipes != null && search == null) {
        return jsonDecode(cachedRecipes['data']) as List<dynamic>;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getRecipeById(int recipeId, {bool forceRefresh = false}) async {
    final cacheKey = 'cached_recipe_$recipeId';
    final isOnline = await ApiUtils.isOnline();
    final cachedRecipe = await ApiUtils.getCachedData(cacheKey);

    if (!forceRefresh && cachedRecipe != null && (isOnline || cachedRecipe['data']!.isNotEmpty)) {
      _logger.d('Returning cached recipe for ID $recipeId, version: ${cachedRecipe['version']}');
      return jsonDecode(cachedRecipe['data']) as Map<String, dynamic>;
    }

    if (!isOnline) {
      if (cachedRecipe != null) {
        _logger.d('Offline: Returning cached recipe for ID $recipeId');
        return jsonDecode(cachedRecipe['data']) as Map<String, dynamic>;
      }
      _logger.w('Offline and no cached recipe available for ID $recipeId');
      throw Exception('Нет интернета и кэшированного рецепта');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().get(
          '${ApiUtils.baseUrl}/recipes/$recipeId',
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
        _logger.e('Failed to load recipe $recipeId: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось загрузить рецепт: ${response.data}');
      }

      final recipeData = response.data;
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        cacheKey,
        jsonEncode(recipeData),
        ttlSeconds: ApiUtils.recipesTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Recipe $recipeId loaded and cached, version: $serverVersion');
      return recipeData;
    } catch (e) {
      _logger.e('Error loading recipe $recipeId: $e');
      if (cachedRecipe != null) {
        return jsonDecode(cachedRecipe['data']) as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  static Future<String> getRecipeImageUrl(int recipeId, {bool forceRefresh = false}) async {
    final cachedPath = await ApiUtils.getCachedImagePath(recipeId, 'recipe');
    final cachedFile = File(cachedPath);
    final prefs = await SharedPreferences.getInstance();
    final cachedVersion = prefs.getString('recipe_image_${recipeId}_version');
    final ttl = prefs.getInt('recipe_image_${recipeId}_ttl');

    if (!forceRefresh && await cachedFile.exists() && ttl != null && DateTime.now().millisecondsSinceEpoch < ttl) {
      _logger.d('Returning cached image path: $cachedPath');
      return cachedPath;
    }

    if (!await ApiUtils.isOnline() && await cachedFile.exists()) {
      _logger.d('Offline: Returning cached image: $cachedPath');
      return cachedPath;
    }

    try {
      final recipeData = await getRecipeById(recipeId, forceRefresh: forceRefresh);
      final serverVersion = recipeData['image_version'].toString();
      final baseImageUrl = '${ApiUtils.baseUrl}/recipes/image/$recipeId';
      final imagePath = await ApiUtils.downloadImage(recipeId, 'recipe', baseImageUrl, serverVersion: serverVersion);
      return imagePath ?? baseImageUrl;
    } catch (e) {
      _logger.e('Error fetching image URL: $e');
      return await cachedFile.exists() ? cachedPath : '';
    }
  }

  static Future<List<dynamic>> getAvailableIngredients({bool forceRefresh = false}) async {
    final isOnline = await ApiUtils.isOnline();
    final cachedIngredients = await ApiUtils.getCachedData(ingredientsCacheKey);

    if (!forceRefresh && cachedIngredients != null && (isOnline || cachedIngredients['data']!.isNotEmpty)) {
      _logger.d('Returning cached ingredients, version: ${cachedIngredients['version']}');
      return jsonDecode(cachedIngredients['data']) as List<dynamic>;
    }

    if (!isOnline) {
      if (cachedIngredients != null) {
        return jsonDecode(cachedIngredients['data']) as List<dynamic>;
      }
      _logger.w('Offline and no cached ingredients available');
      throw Exception('Нет интернета и кэшированных ингредиентов');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().get(
          '${ApiUtils.baseUrl}/recipes/ingredients/',
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
        _logger.e('Failed to load ingredients: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось загрузить ингредиенты: ${response.data}');
      }

      final ingredientsData = response.data;
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        ingredientsCacheKey,
        jsonEncode(ingredientsData),
        ttlSeconds: ApiUtils.ingredientsTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Ingredients loaded and cached, version: $serverVersion');
      return ingredientsData;
    } catch (e) {
      _logger.e('Error loading ingredients: $e');
      if (cachedIngredients != null) {
        return jsonDecode(cachedIngredients['data']) as List<dynamic>;
      }
      rethrow;
    }
  }

  static Future<List<dynamic>> getAvailableMealTypes({bool forceRefresh = false}) async {
    final isOnline = await ApiUtils.isOnline();
    final cachedMealTypes = await ApiUtils.getCachedData(mealTypesCacheKey);

    if (!forceRefresh && cachedMealTypes != null && (isOnline || cachedMealTypes['data']!.isNotEmpty)) {
      _logger.d('Returning cached meal types, version: ${cachedMealTypes['version']}');
      return jsonDecode(cachedMealTypes['data']) as List<dynamic>;
    }

    if (!isOnline) {
      if (cachedMealTypes != null) {
        return jsonDecode(cachedMealTypes['data']) as List<dynamic>;
      }
      _logger.w('Offline and no cached meal types available');
      throw Exception('Нет интернета и кэшированных типов блюд');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().get(
          '${ApiUtils.baseUrl}/recipes/meal-types/',
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
        _logger.e('Failed to load meal types: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось загрузить типы блюд: ${response.data}');
      }

      final mealTypesData = response.data;
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        mealTypesCacheKey,
        jsonEncode(mealTypesData),
        ttlSeconds: ApiUtils.recipesTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Meal types loaded and cached, version: $serverVersion');
      return mealTypesData;
    } catch (e) {
      _logger.e('Error loading meal types: $e');
      if (cachedMealTypes != null) {
        return jsonDecode(cachedMealTypes['data']) as List<dynamic>;
      }
      rethrow;
    }
  }

  static Future<List<dynamic>> getAvailableDishCategories({bool forceRefresh = false}) async {
    final isOnline = await ApiUtils.isOnline();
    final cachedDishCategories = await ApiUtils.getCachedData(dishCategoriesCacheKey);

    if (!forceRefresh && cachedDishCategories != null && (isOnline || cachedDishCategories['data']!.isNotEmpty)) {
      _logger.d('Returning cached dish categories, version: ${cachedDishCategories['version']}');
      return jsonDecode(cachedDishCategories['data']) as List<dynamic>;
    }

    if (!isOnline) {
      if (cachedDishCategories != null) {
        return jsonDecode(cachedDishCategories['data']) as List<dynamic>;
      }
      _logger.w('Offline and no cached dish categories available');
      throw Exception('Нет интернета и кэшированных категорий блюд');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().get(
          '${ApiUtils.baseUrl}/recipes/dish-categories/',
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
        _logger.e('Failed to load dish categories: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось загрузить категории блюд: ${response.data}');
      }

      final dishCategoriesData = response.data;
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        dishCategoriesCacheKey,
        jsonEncode(dishCategoriesData),
        ttlSeconds: ApiUtils.recipesTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Dish categories loaded and cached, version: $serverVersion');
      return dishCategoriesData;
    } catch (e) {
      _logger.e('Error loading dish categories: $e');
      if (cachedDishCategories != null) {
        return jsonDecode(cachedDishCategories['data']) as List<dynamic>;
      }
      rethrow;
    }
  }

  static Future<List<dynamic>> getAvailableTags({bool forceRefresh = false}) async {
    final isOnline = await ApiUtils.isOnline();
    final cachedTags = await ApiUtils.getCachedData(tagsCacheKey);

    if (!forceRefresh && cachedTags != null && (isOnline || cachedTags['data']!.isNotEmpty)) {
      _logger.d('Returning cached tags, version: ${cachedTags['version']}');
      return jsonDecode(cachedTags['data']) as List<dynamic>;
    }

    if (!isOnline) {
      if (cachedTags != null) {
        return jsonDecode(cachedTags['data']) as List<dynamic>;
      }
      _logger.w('Offline and no cached tags available');
      throw Exception('Нет интернета и кэшированных тегов');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().get(
          '${ApiUtils.baseUrl}/recipes/tags/',
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
        _logger.e('Failed to load tags: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось загрузить теги: ${response.data}');
      }

      final tagsData = response.data;
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        tagsCacheKey,
        jsonEncode(tagsData),
        ttlSeconds: ApiUtils.recipesTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Tags loaded and cached, version: $serverVersion');
      return tagsData;
    } catch (e) {
      _logger.e('Error loading tags: $e');
      if (cachedTags != null) {
        return jsonDecode(cachedTags['data']) as List<dynamic>;
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createRecipe({
    required String title,
    required List<Map<String, dynamic>> steps,
    String? description,
    required List<Map<String, dynamic>> ingredients,
    File? image,
    bool isPublic = false,
    List<int>? mealTypeIds,
    List<int>? dishCategoryIds,
    List<int>? tagIds,
    required int totalTime,
    required int servings,
    double? calories,
    double? proteins,
    double? fats,
    double? carbohydrates,
  }) async {
    if (!await ApiUtils.isOnline()) {
      throw Exception('Для создания рецепта требуется интернет');
    }

    try {
      // Передаем функцию, создающую FormData
      final response = await ApiUtils.makeRequest((token) async {
        final formData = FormData.fromMap({
          'title': title.trim(),
          'steps': jsonEncode(steps),
          if (description != null) 'description': description.trim(),
          'ingredients': jsonEncode(ingredients),
          'is_public': isPublic.toString(),
          'meal_type_ids': jsonEncode(mealTypeIds ?? []),
          'dish_category_ids': jsonEncode(dishCategoryIds ?? []),
          'tag_ids': jsonEncode(tagIds ?? []),
          'total_time': totalTime,
          'servings': servings,
          if (calories != null) 'calories': calories,
          if (proteins != null) 'proteins': proteins,
          if (fats != null) 'fats': fats,
          if (carbohydrates != null) 'carbohydrates': carbohydrates,
          if (image != null) 'image': await MultipartFile.fromFile(image.path, filename: 'image.jpg'),
        });

        return await Dio().post(
          '${ApiUtils.baseUrl}/recipes/',
          data: formData,
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json; charset=utf-8',
            },
          ),
        );
      });

      if (response.statusCode != 200) {
        _logger.e('Failed to create recipe: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось создать рецепт: ${response.data}');
      }

      final recipeData = response.data;
      await _updateCachedRecipes(recipeData, cacheKey: userRecipesCacheKey, isAdd: true);
      await getRecipes(forceRefresh: true);
      _logger.i('Recipe created and cache refreshed');
      return recipeData;
    } catch (e) {
      _logger.e('Error creating recipe: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateRecipe({
    required int recipeId,
    String? title,
    List<Map<String, dynamic>>? steps,
    String? description,
    List<Map<String, dynamic>>? ingredients,
    File? image,
    bool? isPublic,
    List<int>? mealTypeIds,
    List<int>? dishCategoryIds,
    List<int>? tagIds,
    int? totalTime,
    int? servings,
    double? calories,
    double? proteins,
    double? fats,
    double? carbohydrates,
  }) async {
    if (!await ApiUtils.isOnline()) {
      throw Exception('Для редактирования рецепта требуется интернет');
    }

    try {
      // Передаем функцию, создающую FormData
      final response = await ApiUtils.makeRequest((token) async {
        final formData = FormData.fromMap({
          if (title != null) 'title': title.trim(),
          if (steps != null) 'steps': jsonEncode(steps),
          if (description != null) 'description': description.trim(),
          if (ingredients != null) 'ingredients': jsonEncode(ingredients),
          if (isPublic != null) 'is_public': isPublic.toString(),
          if (mealTypeIds != null) 'meal_type_ids': jsonEncode(mealTypeIds),
          if (dishCategoryIds != null) 'dish_category_ids': jsonEncode(dishCategoryIds),
          if (tagIds != null) 'tag_ids': jsonEncode(tagIds),
          if (totalTime != null) 'total_time': totalTime,
          if (servings != null) 'servings': servings,
          if (calories != null) 'calories': calories,
          if (proteins != null) 'proteins': proteins,
          if (fats != null) 'fats': fats,
          if (carbohydrates != null) 'carbohydrates': carbohydrates,
          if (image != null) 'image': await MultipartFile.fromFile(image.path),
        });

        return await Dio().put(
          '${ApiUtils.baseUrl}/recipes/$recipeId',
          data: formData,
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json; charset=utf-8',
            },
          ),
        );
      });

      if (response.statusCode != 200) {
        _logger.e('Failed to update recipe: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось обновить рецепт: ${response.data}');
      }

      final updatedRecipe = response.data;
      await _updateCachedRecipes(updatedRecipe, cacheKey: userRecipesCacheKey, isAdd: false);
      await getRecipeImageUrl(recipeId, forceRefresh: true);
      await getRecipes(forceRefresh: true);
      _logger.i('Recipe updated and cache refreshed');
      return updatedRecipe;
    } catch (e) {
      _logger.e('Error updating recipe: $e');
      rethrow;
    }
  }

  static Future<void> deleteRecipe(int recipeId) async {
    if (!await ApiUtils.isOnline()) {
      throw Exception('Для удаления рецепта требуется интернет');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().delete(
          '${ApiUtils.baseUrl}/recipes/$recipeId',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      });

      if (response.statusCode != 204) {
        _logger.e('Failed to delete recipe: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось удалить рецепт: ${response.data}');
      }

      await _updateCachedRecipes({'id': recipeId}, cacheKey: userRecipesCacheKey, isDelete: true);
      await getRecipes(forceRefresh: true);
      _logger.i('Recipe deleted and cache refreshed');
    } catch (e) {
      _logger.e('Error deleting recipe: $e');
      rethrow;
    }
  }

  static Future<void> toggleFavoriteRecipe(int recipeId, bool isFavorite) async {
    if (!await ApiUtils.isOnline()) {
      throw Exception('Для изменения избранного требуется интернет');
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return isFavorite
            ? await Dio().post(
          '${ApiUtils.baseUrl}/recipes/favorites/$recipeId',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        )
            : await Dio().delete(
          '${ApiUtils.baseUrl}/recipes/favorites/$recipeId',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      });

      if (response.statusCode != (isFavorite ? 200 : 204)) {
        _logger.e('Failed to toggle favorite: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось переключить избранное: ${response.data}');
      }

      final cachedFavorites = await ApiUtils.getCachedData(favoritesCacheKey);
      List<int> favoriteIds = cachedFavorites != null ? List<int>.from(jsonDecode(cachedFavorites['data'])) : [];
      if (isFavorite && !favoriteIds.contains(recipeId)) {
        favoriteIds.add(recipeId);
      } else {
        favoriteIds.remove(recipeId);
      }
      final serverVersion = DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        favoritesCacheKey,
        jsonEncode(favoriteIds),
        ttlSeconds: ApiUtils.favoritesTtlSeconds,
        version: serverVersion,
      );
      await getRecipes(forceRefresh: true);
      _logger.i('Favorite toggled: $recipeId - $isFavorite');
    } catch (e) {
      _logger.e('Error toggling favorite: $e');
      rethrow;
    }
  }

  static Future<List<int>> getFavoriteRecipeIds({bool forceRefresh = false}) async {
    final isOnline = await ApiUtils.isOnline();
    final cachedFavorites = await ApiUtils.getCachedData(favoritesCacheKey);

    if (!forceRefresh && cachedFavorites != null && (isOnline || cachedFavorites['data']!.isNotEmpty)) {
      _logger.d('Returning cached favorite IDs, version: ${cachedFavorites['version']}');
      return List<int>.from(jsonDecode(cachedFavorites['data']));
    }

    if (!isOnline) {
      _logger.w('Offline, returning cached or empty favorites');
      return cachedFavorites != null ? List<int>.from(jsonDecode(cachedFavorites['data'])) : [];
    }

    try {
      final response = await ApiUtils.makeRequest((token) async {
        return await Dio().get(
          '${ApiUtils.baseUrl}/recipes/favorites',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      });

      if (response.statusCode != 200) {
        _logger.e('Failed to load favorite IDs: ${response.statusCode} - ${response.data}');
        throw Exception('Не удалось загрузить избранные рецепты: ${response.data}');
      }

      final favoriteIds = (response.data as List).map((id) => id as int).toList();
      final serverVersion = response.headers.value('ETag') ?? DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        favoritesCacheKey,
        jsonEncode(favoriteIds),
        ttlSeconds: ApiUtils.favoritesTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Favorite IDs loaded and cached, version: $serverVersion');
      return favoriteIds;
    } catch (e) {
      _logger.e('Error loading favorite IDs: $e');
      return cachedFavorites != null ? List<int>.from(jsonDecode(cachedFavorites['data'])) : [];
    }
  }

  static Future<void> _updateCachedRecipes(Map<String, dynamic> recipeData, {required String cacheKey, bool isAdd = false, bool isDelete = false}) async {
    final cachedRecipes = await ApiUtils.getCachedData(cacheKey);
    if (cachedRecipes != null) {
      final recipesList = jsonDecode(cachedRecipes['data']) as List<dynamic>;
      final index = recipesList.indexWhere((r) => r['id'] == recipeData['id']);
      if (isDelete) {
        if (index != -1) recipesList.removeAt(index);
      } else if (index != -1) {
        recipesList[index] = recipeData;
      } else if (isAdd) {
        recipesList.add(recipeData);
      }
      final serverVersion = DateTime.now().toIso8601String();
      await ApiUtils.saveCachedData(
        cacheKey,
        jsonEncode(recipesList),
        ttlSeconds: ApiUtils.recipesTtlSeconds,
        version: serverVersion,
      );
      _logger.i('Cached recipes updated for $cacheKey, version: $serverVersion');
    }
  }
}
