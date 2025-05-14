import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'package:mealflow_app/screens/recipes/create_recipe_sheet.dart';
import 'package:mealflow_app/screens/recipes/recipe_detail_screen.dart';
import 'package:mealflow_app/services/api_recipes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:logger/logger.dart';
import 'package:mealflow_app/models/meal_type.dart';
import '../../services/api_utils.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> with SingleTickerProviderStateMixin {
  List<dynamic> userRecipes = [];
  List<dynamic> mealflowRecipes = [];
  List<int> favoriteMealflowIds = [];
  List<dynamic> availableIngredients = [];
  List<dynamic> availableMealTypes = [];
  List<dynamic> availableDishCategories = [];
  List<dynamic> availableTags = [];
  bool isLoadingUser = false;
  bool isLoadingMealflow = false;
  String? errorMessageUser;
  String? errorMessageMealflow;
  int currentPageUser = 0;
  int currentPageMealflow = 0;
  final int recipesPerPage = 10;
  String searchQueryUser = '';
  String searchQueryMealflow = '';
  Timer? _debounceTimer;
  late TabController _tabController;
  String? currentUserId;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPreferencesAndData();
  }

  Future<void> _loadPreferencesAndData({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString('user_id');
    await _loadData(forceRefresh: forceRefresh);
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;

    try {
      setState(() {
        isLoadingUser = true;
        isLoadingMealflow = true;
      });

      // Загрузка личных рецептов
      int skipUser = currentPageUser * recipesPerPage;
      userRecipes = await ApiRecipes.getRecipes(
        showMealflow: false,
        search: searchQueryUser.trim(),
        skip: skipUser,
        limit: recipesPerPage,
        forceRefresh: forceRefresh || searchQueryUser.isNotEmpty,
      );

      // Загрузка избранных
      favoriteMealflowIds = await ApiRecipes.getFavoriteRecipeIds(forceRefresh: forceRefresh);

      // Добавляем избранные рецепты в userRecipes
      if (favoriteMealflowIds.isNotEmpty) {
        final favoriteRecipes = await ApiRecipes.getRecipes(
          showMealflow: true,
          search: '',
          skip: 0,
          limit: favoriteMealflowIds.length,
          forceRefresh: forceRefresh,
        );
        final favorites = favoriteRecipes.where((recipe) => favoriteMealflowIds.contains(recipe['id'])).toList();
        userRecipes.addAll(favorites.where((recipe) => !userRecipes.any((ur) => ur['id'] == recipe['id'])));
      }

      // Загрузка публичных рецептов
      int skipMealflow = currentPageMealflow * recipesPerPage;
      mealflowRecipes = await ApiRecipes.getRecipes(
        showMealflow: true,
        search: searchQueryMealflow.trim(),
        skip: skipMealflow,
        limit: recipesPerPage,
        forceRefresh: forceRefresh || searchQueryMealflow.isNotEmpty,
      );

      // Фильтруем публичные рецепты, исключая свои
      mealflowRecipes = mealflowRecipes.where((recipe) {
        final recipeUserId = recipe['user_id']?.toString();
        final isPublic = recipe['is_public'] ?? false;
        return isPublic && recipeUserId != currentUserId;
      }).toList();

      if (mounted) {
        setState(() {
          isLoadingUser = false;
          isLoadingMealflow = false;
          errorMessageUser = null;
          errorMessageMealflow = null;
        });
      }

      // Загрузка дополнительных данных
      availableIngredients = await ApiRecipes.getAvailableIngredients(forceRefresh: forceRefresh);
      availableMealTypes = await ApiRecipes.getAvailableMealTypes(forceRefresh: forceRefresh);
      availableDishCategories = await ApiRecipes.getAvailableDishCategories(forceRefresh: forceRefresh);
      availableTags = await ApiRecipes.getAvailableTags(forceRefresh: forceRefresh);
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessageUser = e.toString();
          errorMessageMealflow = e.toString();
          isLoadingUser = false;
          isLoadingMealflow = false;
        });

        // Загрузка из кеша
        final prefs = await SharedPreferences.getInstance();
        final cachedUserRecipes = await ApiUtils.getCachedData(ApiRecipes.userRecipesCacheKey);
        userRecipes = cachedUserRecipes != null ? jsonDecode(cachedUserRecipes['data']) : [];
        final cachedMealflowRecipes = await ApiUtils.getCachedData(ApiRecipes.mealflowRecipesCacheKey);
        mealflowRecipes = cachedMealflowRecipes != null ? jsonDecode(cachedMealflowRecipes['data']) : [];
        final cachedFavorites = await ApiUtils.getCachedData(ApiRecipes.favoritesCacheKey);
        favoriteMealflowIds = cachedFavorites != null ? List<int>.from(jsonDecode(cachedFavorites['data'])) : [];
        final cachedIngredients = await ApiUtils.getCachedData(ApiRecipes.ingredientsCacheKey);
        availableIngredients = cachedIngredients != null ? jsonDecode(cachedIngredients['data']) : [];
        final cachedMealTypes = await ApiUtils.getCachedData(ApiRecipes.mealTypesCacheKey);
        availableMealTypes = cachedMealTypes != null ? jsonDecode(cachedMealTypes['data']) : [];
        final cachedDishCategories = await ApiUtils.getCachedData(ApiRecipes.dishCategoriesCacheKey);
        availableDishCategories = cachedDishCategories != null ? jsonDecode(cachedDishCategories['data']) : [];
        final cachedTags = await ApiUtils.getCachedData(ApiRecipes.tagsCacheKey);
        availableTags = cachedTags != null ? jsonDecode(cachedTags['data']) : [];
      }
      _logger.e('Ошибка загрузки данных: $e');
    }
  }

  Future<void> _toggleFavorite(int recipeId) async {
    if (!await ApiUtils.isOnline()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Отсутствует подключение к интернету'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final isFavorite = favoriteMealflowIds.contains(recipeId);
    try {
      await ApiRecipes.toggleFavoriteRecipe(recipeId, !isFavorite);
      if (mounted) {
        setState(() {
          if (!isFavorite) {
            // Добавление в избранное
            favoriteMealflowIds.add(recipeId);
            // Проверяем, есть ли рецепт в mealflowRecipes
            final recipe = mealflowRecipes.firstWhere((r) => r['id'] == recipeId, orElse: () => null);
            if (recipe != null && !userRecipes.any((ur) => ur['id'] == recipeId)) {
              userRecipes.add(recipe);
            }
          } else {
            // Удаление из избранного
            favoriteMealflowIds.remove(recipeId);
            userRecipes.removeWhere((r) => r['id'] == recipeId);
            // Рецепт остается в mealflowRecipes, так как он публичный
          }
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFavorite ? 'Удалено из избранного' : 'Добавлено в избранное'),
          backgroundColor: const Color(0xFF7C73F1),
        ),
      );
    } catch (e) {
      _logger.e('Ошибка переключения избранного: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _onSearchChanged(String query, bool isUserTab) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          if (isUserTab) {
            searchQueryUser = query.trim();
            currentPageUser = 0;
            isLoadingUser = true;
          } else {
            searchQueryMealflow = query.trim();
            currentPageMealflow = 0;
            isLoadingMealflow = true;
          }
        });
        _loadData(forceRefresh: true);
      }
    });
  }

  List<dynamic> _getPaginatedRecipes(bool isUserTab) {
    final recipes = isUserTab ? userRecipes : mealflowRecipes;
    final currentPage = isUserTab ? currentPageUser : currentPageMealflow;
    final start = currentPage * recipesPerPage;
    final end = (currentPage + 1) * recipesPerPage;
    return recipes.sublist(start, end > recipes.length ? recipes.length : end);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 160.0,
              floating: true, // Включаем плавающий AppBar
              pinned: false,  // Отключаем закрепление
              snap: true,    // (Опционально) AppBar полностью появляется/скрывается
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7C73F1), Color(0xFF9B93F7)],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_dining_rounded, size: 50, color: Colors.white)
                            .animate()
                            .scale(duration: 600.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 8),
                        const Text(
                          'Рецепты',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
                        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                      ],
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Личные рецепты'),
                  Tab(text: 'Рецепты MealFlow'),
                ],
                labelColor: const Color(0xFF7C73F1),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF7C73F1),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              // Вкладка "Личные рецепты"
              _buildRecipeList(
                isUserTab: true,
                recipes: _getPaginatedRecipes(true),
                isLoading: isLoadingUser,
                errorMessage: errorMessageUser,
                currentPage: currentPageUser,
                onPageChange: (increment) {
                  setState(() {
                    currentPageUser += increment;
                    isLoadingUser = true;
                  });
                  _loadData();
                },
                onSearch: (query) => _onSearchChanged(query, true),
              ),
              // Вкладка "Рецепты MealFlow"
              _buildRecipeList(
                isUserTab: false,
                recipes: _getPaginatedRecipes(false),
                isLoading: isLoadingMealflow,
                errorMessage: errorMessageMealflow,
                currentPage: currentPageMealflow,
                onPageChange: (increment) {
                  setState(() {
                    currentPageMealflow += increment;
                    isLoadingMealflow = true;
                  });
                  _loadData();
                },
                onSearch: (query) => _onSearchChanged(query, false),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreateRecipeSheet,
          backgroundColor: const Color(0xFF7C73F1),
          child: const Icon(Icons.add, color: Colors.white),
        ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
      ),
    );
  }

  Widget _buildRecipeList({
    required bool isUserTab,
    required List<dynamic> recipes,
    required bool isLoading,
    required String? errorMessage,
    required int currentPage,
    required Function(int) onPageChange,
    required Function(String) onSearch,
  }) {
    return RefreshIndicator(
      onRefresh: () => _loadPreferencesAndData(forceRefresh: true),
      color: const Color(0xFF7C73F1),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: onSearch,
                decoration: InputDecoration(
                  hintText: 'Поиск рецептов...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7C73F1), width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF7C73F1)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ).animate().fadeIn(duration: 400.ms),
            ),
          ),
          isLoading
              ? SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C73F1)),
              ).animate().scale(duration: 600.ms),
            ),
          )
              : errorMessage != null && recipes.isEmpty
              ? SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.wifi_off,
                    size: 50,
                    color: Colors.grey,
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 16),
                  Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _loadData(forceRefresh: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C73F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Попробовать снова'),
                  ).animate().scale(duration: 600.ms),
                ],
              ),
            ),
          )
              : recipes.isEmpty
              ? SliverFillRemaining(
            child: Center(
              child: const Text(
                'Рецептов нет',
                style: TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
              ).animate().fadeIn(duration: 400.ms),
            ),
          )
              : SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final recipe = recipes[index];
                  final isMealflowRecipe = !isUserTab || favoriteMealflowIds.contains(recipe['id']);
                  final isFavorite = favoriteMealflowIds.contains(recipe['id']);

                  return FutureBuilder<String>(
                    future: ApiRecipes.getRecipeImageUrl(recipe['id'], forceRefresh: false),
                    builder: (context, snapshot) {
                      String? imagePath = snapshot.data;

                      return GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipeDetailScreen(
                                recipe: recipe,
                                cachedImagePath: imagePath,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadData();
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                                child: _buildRecipeImage(recipe, cachedImagePath: imagePath),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        recipe['title'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2D2D2D),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (recipe['meal_types'] != null &&
                                          (recipe['meal_types'] as List).isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Wrap(
                                            spacing: 4,
                                            children: (recipe['meal_types'] as List).map((mt) {
                                              final mealType = MealType.fromJson(mt['meal_type'] ?? {});
                                              return Text(
                                                mealType.displayName,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      if (recipe['dish_categories'] != null &&
                                          (recipe['dish_categories'] as List).isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Wrap(
                                            spacing: 4,
                                            children: (recipe['dish_categories'] as List).map((cat) {
                                              final categoryName = cat['dish_category']?['name'] ?? '';
                                              return Text(
                                                categoryName,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isMealflowRecipe)
                                IconButton(
                                  icon: Icon(
                                    isFavorite ? Icons.favorite : Icons.favorite_border,
                                    color: isFavorite ? Colors.redAccent : Colors.grey,
                                  ),
                                  onPressed: () => _toggleFavorite(recipe['id']),
                                ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: (100 * index).ms, duration: 400.ms);
                    },
                  );
                },
                childCount: recipes.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: currentPage > 0 ? const Color(0xFF7C73F1) : Colors.grey),
                    onPressed: currentPage > 0
                        ? () => onPageChange(-1)
                        : null,
                  ),
                  Text(
                    'Страница ${currentPage + 1}',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF2D2D2D)),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right,
                        color: recipes.length == recipesPerPage ? const Color(0xFF7C73F1) : Colors.grey),
                    onPressed: recipes.length == recipesPerPage
                        ? () => onPageChange(1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeImage(Map<String, dynamic> recipe, {required String? cachedImagePath}) {
    const double imageWidth = 100;
    const double imageHeight = 100;

    if (cachedImagePath == null || cachedImagePath.isEmpty) {
      return _buildPlaceholderImage();
    }

    if (cachedImagePath.startsWith('http')) {
      return Image.network(
        cachedImagePath,
        width: imageWidth,
        height: imageHeight,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    } else {
      return Image.file(
        File(cachedImagePath),
        width: imageWidth,
        height: imageHeight,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 100,
      height: 100,
      color: Colors.grey[200],
      child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
    );
  }

  void _showCreateRecipeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateRecipeSheet(
        availableIngredients: availableIngredients,
        availableMealTypes: availableMealTypes,
        availableDishCategories: availableDishCategories,
        availableTags: availableTags,
      ),
    ).then((value) {
      if (value == true) _loadData();
    });
  }
}
