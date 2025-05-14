import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'package:mealflow_app/screens/recipes/edit_recipe_sheet.dart';
import 'package:mealflow_app/services/api_recipes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:mealflow_app/models/meal_type.dart';
import '../../services/api_utils.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final String? cachedImagePath;

  const RecipeDetailScreen({super.key, required this.recipe, this.cachedImagePath});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late List<Map<String, dynamic>> steps;
  String? currentUserId;
  bool isLoading = false;
  final Logger _logger = Logger();
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    steps = List<Map<String, dynamic>>.from(widget.recipe['steps'] ?? []);
    _imagePath = widget.cachedImagePath;
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserId = prefs.getString('user_id');
    });
  }

  Future<void> _deleteRecipe() async {
    if (!await ApiUtils.isOnline()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Отсутствует подключение к интернету'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      setState(() => isLoading = true);
      await ApiRecipes.deleteRecipe(widget.recipe['id']);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Рецепт удалён'),
            backgroundColor: Color(0xFF7C73F1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.redAccent),
        );
      }
      _logger.e('Ошибка удаления рецепта: $e');
    }
  }

  void _showEditRecipeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditRecipeSheet(recipe: widget.recipe),
    ).then((value) {
      if (value == true) {
        _refreshRecipeData();
      }
    });
  }

  Future<void> _refreshRecipeData() async {
    setState(() => isLoading = true);
    try {
      final updatedRecipe = await ApiRecipes.getRecipeById(widget.recipe['id'], forceRefresh: true);
      final updatedImagePath = await ApiRecipes.getRecipeImageUrl(widget.recipe['id'], forceRefresh: true);
      setState(() {
        steps = List<Map<String, dynamic>>.from(updatedRecipe['steps'] ?? []);
        widget.recipe
          ..clear()
          ..addAll(updatedRecipe);
        _imagePath = updatedImagePath;
      });
    } catch (e) {
      _logger.e('Ошибка обновления рецепта: $e');
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isUserRecipe = widget.recipe['user_id'] != null &&
        widget.recipe['id'] is int &&
        widget.recipe['id'] > 0 &&
        widget.recipe['user_id'].toString() == currentUserId;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshRecipeData,
        color: const Color(0xFF7C73F1),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300.0,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF7C73F1),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.recipe['title'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : _buildRecipeImage(),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: isUserRecipe
                  ? [
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  onPressed: _showEditRecipeSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded, color: Colors.white),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Удалить рецепт?'),
                        content: const Text('Вы уверены, что хотите удалить этот рецепт?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteRecipe();
                            },
                            child: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ]
                  : null,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.recipe['total_time'] != null || widget.recipe['servings'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Информация',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ).animate().fadeIn(duration: 400.ms),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (widget.recipe['total_time'] != null)
                                Chip(
                                  label: Text('${widget.recipe['total_time']} мин'),
                                  backgroundColor: const Color(0xFF7C73F1).withOpacity(0.1),
                                  labelStyle: const TextStyle(color: Color(0xFF7C73F1)),
                                ),
                              if (widget.recipe['servings'] != null)
                                Chip(
                                  label: Text('${widget.recipe['servings']} порции'),
                                  backgroundColor: const Color(0xFF7C73F1).withOpacity(0.1),
                                  labelStyle: const TextStyle(color: Color(0xFF7C73F1)),
                                ),
                            ],
                          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                          const SizedBox(height: 24),
                        ],
                      ),
                    if (widget.recipe['calories'] != null ||
                        widget.recipe['proteins'] != null ||
                        widget.recipe['fats'] != null ||
                        widget.recipe['carbohydrates'] != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Пищевая ценность',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ).animate().fadeIn(duration: 400.ms),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (widget.recipe['calories'] != null)
                                Chip(
                                  label: Text('${widget.recipe['calories']} ккал'),
                                  backgroundColor: const Color(0xFF7C73F1).withOpacity(0.1),
                                  labelStyle: const TextStyle(color: Color(0xFF7C73F1)),
                                ),
                              if (widget.recipe['proteins'] != null)
                                Chip(
                                  label: Text('${widget.recipe['proteins']} г белков'),
                                  backgroundColor: const Color(0xFF7C73F1).withOpacity(0.1),
                                  labelStyle: const TextStyle(color: Color(0xFF7C73F1)),
                                ),
                              if (widget.recipe['fats'] != null)
                                Chip(
                                  label: Text('${widget.recipe['fats']} г жиров'),
                                  backgroundColor: const Color(0xFF7C73F1).withOpacity(0.1),
                                  labelStyle: const TextStyle(color: Color(0xFF7C73F1)),
                                ),
                              if (widget.recipe['carbohydrates'] != null)
                                Chip(
                                  label: Text('${widget.recipe['carbohydrates']} г углеводов'),
                                  backgroundColor: const Color(0xFF7C73F1).withOpacity(0.1),
                                  labelStyle: const TextStyle(color: Color(0xFF7C73F1)),
                                ),
                            ],
                          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                          const SizedBox(height: 24),
                        ],
                      ),
                    if (widget.recipe['dish_categories'] != null &&
                        (widget.recipe['dish_categories'] as List).isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Категории блюд',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ).animate().fadeIn(duration: 400.ms),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: (widget.recipe['dish_categories'] as List).map((category) {
                              final categoryName = category['dish_category']?['name'] ?? '';
                              return Chip(
                                label: Text(categoryName),
                                backgroundColor: const Color(0xFF7C73F1).withOpacity(0.1),
                                labelStyle: const TextStyle(color: Color(0xFF7C73F1)),
                              );
                            }).toList(),
                          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                          const SizedBox(height: 24),
                        ],
                      ),
                    if (widget.recipe['tags'] != null && (widget.recipe['tags'] as List).isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Теги',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ).animate().fadeIn(duration: 400.ms),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: (widget.recipe['tags'] as List).map((tag) {
                              final tagName = tag['tag']?['name'] ?? '';
                              return Chip(
                                label: Text(tagName),
                                backgroundColor: const Color(0xFF7C73F1).withOpacity(0.1),
                                labelStyle: const TextStyle(color: Color(0xFF7C73F1)),
                              );
                            }).toList(),
                          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                          const SizedBox(height: 24),
                        ],
                      ),
                    if (widget.recipe['meal_types'] != null && (widget.recipe['meal_types'] as List).isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Типы блюд',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ).animate().fadeIn(duration: 400.ms),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: (widget.recipe['meal_types'] as List).map((mt) {
                              final mealType = MealType.fromJson(mt['meal_type'] ?? {});
                              return Chip(
                                label: Text(mealType.displayName),
                                backgroundColor: const Color(0xFF7C73F1).withOpacity(0.1),
                                labelStyle: const TextStyle(color: Color(0xFF7C73F1)),
                              );
                            }).toList(),
                          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                          const SizedBox(height: 24),
                        ],
                      ),
                    if (widget.recipe['description'] != null && widget.recipe['description'].isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Описание',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ).animate().fadeIn(duration: 400.ms),
                          const SizedBox(height: 8),
                          Text(
                            widget.recipe['description'],
                            style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                          const SizedBox(height: 24),
                        ],
                      ),
                    const Text(
                      'Ингредиенты',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 8),
                    ..._buildIngredientsList().animate().slideX(begin: 0.2, duration: 400.ms),
                    const SizedBox(height: 24),
                    const Text(
                      'Шаги',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 8),
                    ..._buildStepsList().animate().slideX(begin: 0.2, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeImage() {
    Widget imageWidget;
    if (_imagePath == null || _imagePath!.isEmpty) {
      imageWidget = _buildPlaceholderImage();
    } else if (_imagePath!.startsWith('http')) {
      imageWidget = Image.network(
        _imagePath!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    } else {
      imageWidget = Image.file(
        File(_imagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    }

    return Stack(
      children: [
        imageWidget,
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.1),
                Colors.black.withOpacity(0.5),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.white, size: 80),
      ),
    );
  }

  List<Widget> _buildIngredientsList() {
    final ingredients = widget.recipe['ingredients'] as List<dynamic>? ?? [];
    return ingredients.map((ingredient) {
      final ing = ingredient as Map<String, dynamic>;
      final name = ing['ingredient']?['ingredient_name'] ?? '';
      final unit = ing['ingredient']?['unit'] ?? '';
      final amount = ing['amount']?.toString() ?? '';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF7C73F1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$name ($amount $unit)',
                style: const TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildStepsList() {
    return steps.asMap().entries.map((entry) {
      final index = entry.key;
      final step = entry.value;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF7C73F1),
              child: Text(
                '${step['step_number'] ?? index + 1}',
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step['description'] ?? '',
                    style: const TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
                  ),
                  if (step['duration'] != null && step['duration'].toString().isNotEmpty)
                    Text(
                      '(${step['duration']})',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
