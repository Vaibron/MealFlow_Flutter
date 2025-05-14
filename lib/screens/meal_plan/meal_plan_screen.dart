import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:mealflow_app/services/api_meal_planner.dart';
import 'package:mealflow_app/services/api_recipes.dart';
import 'package:mealflow_app/screens/meal_plan/meal_plan_dialog.dart';
import 'package:mealflow_app/screens/meal_plan/replace_recipe_dialog.dart';
import 'package:mealflow_app/screens/recipes/recipe_detail_screen.dart';
import 'package:mealflow_app/screens/meal_plan/meal_plan_calendar_screen.dart';


class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  Map<String, dynamic>? mealPlan;
  bool isLoading = false;
  String? errorMessage;
  DateTime selectedDate = DateTime.now();
  final Logger _logger = Logger();
  final ScrollController _dateScrollController = ScrollController();
  final GlobalKey _dateItemKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadMealPlan();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentDate();
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMealPlan({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      mealPlan = await ApiMealPlanner.getMealPlan(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = null;
        });
      }
      _logger.i('Meal plan loaded successfully');
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
          mealPlan = null;
        });
      }
      _logger.e('Error loading meal plan: $e');
    }
  }

  Future<void> _generateMealPlan(int days, int persons, List<int> excludedIngredients, String recipeSource, DateTime startDate) async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      mealPlan = await ApiMealPlanner.generateMealPlan(
        startDate: startDate,
        days: days,
        persons: persons,
        excludedIngredients: excludedIngredients,
        recipeSource: recipeSource,
      );
      if (mounted) {
        setState(() {
          selectedDate = startDate;
          isLoading = false;
          errorMessage = null;
        });
      }
      _logger.i('Meal plan generated successfully');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentDate();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
      _logger.e('Error generating meal plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _replaceRecipe(String date, int mealTypeId, int? newRecipeId) async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final updatedMealPlan = await ApiMealPlanner.replaceRecipe(
        date: date,
        mealTypeId: mealTypeId,
        newRecipeId: newRecipeId,
      );
      if (mounted) {
        setState(() {
          mealPlan = updatedMealPlan;
          isLoading = false;
          errorMessage = null;
        });
      }
      _logger.i('Recipe replaced successfully for date: $date, mealTypeId: $mealTypeId, newRecipeId: $newRecipeId');
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
      _logger.e('Error replacing recipe: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка замены рецепта: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  List<DateTime> _getDateList() {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 14));
    final end = today.add(const Duration(days: 14));
    return List.generate(29, (index) => start.add(Duration(days: index)));
  }

  List<Map<String, dynamic>> _getSortedMealTypes() {
    if (mealPlan == null || mealPlan!['meal_types'] == null) {
      return [];
    }
    final mealTypes = (mealPlan!['meal_types'] as List<dynamic>).cast<Map<String, dynamic>>();
    return mealTypes..sort((a, b) => a['order'].compareTo(b['order']));
  }

  Widget _buildRecipeImage(String imagePath) {
    if (imagePath.isEmpty) {
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 80,
          height: 80,
          color: Colors.grey[200],
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    } else {
      return Image.file(
        File(imagePath),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 80,
          height: 80,
          color: Colors.grey[200],
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }
  }

  double _getItemWidth() {
    final RenderBox? renderBox = _dateItemKey.currentContext?.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 76.0;
    _logger.i('Item width: $width');
    return width;
  }

  void _scrollToCurrentDate() {
    final dates = _getDateList();
    final currentDateIndex = dates.indexWhere((date) =>
    date.day == selectedDate.day &&
        date.month == selectedDate.month &&
        date.year == selectedDate.year);
    if (currentDateIndex != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final itemWidth = _getItemWidth();
        final screenWidth = MediaQuery.of(context).size.width;
        final offset = (currentDateIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
        _logger.i('Scrolling to offset: $offset, index: $currentDateIndex, itemWidth: $itemWidth, screenWidth: $screenWidth');
        _dateScrollController.animateTo(
          offset.clamp(0.0, _dateScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dates = _getDateList();
    final sortedMealTypes = _getSortedMealTypes();

    Intl.defaultLocale = 'ru_RU';

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () => _loadMealPlan(forceRefresh: true),
        color: const Color(0xFF7C73F1),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 160.0,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MealPlanCalendarScreen(
                          mealPlan: mealPlan,
                          onDateSelected: (date) {
                            setState(() {
                              selectedDate = date;
                            });
                            _scrollToCurrentDate();
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
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
                        const Icon(Icons.restaurant_menu, size: 50, color: Colors.white)
                            .animate()
                            .scale(duration: 600.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 8),
                        const Text(
                          'МЕНЮ',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
                        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        controller: _dateScrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: dates.length,
                        itemBuilder: (context, index) {
                          final date = dates[index];
                          final isSelected = date.day == selectedDate.day &&
                              date.month == selectedDate.month &&
                              date.year == selectedDate.year;
                          return GestureDetector(
                            onTap: () {
                              if (mounted) {
                                setState(() => selectedDate = date);
                              }
                            },
                            child: Container(
                              key: index == 0 ? _dateItemKey : null,
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF7C73F1) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? Colors.transparent : Colors.grey[300]!,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    DateFormat('dd MMM').format(date),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected ? Colors.white : const Color(0xFF2D2D2D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('EEEE').format(date).substring(0, 3).toLowerCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected ? Colors.white70 : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ).animate().fadeIn(duration: 400.ms),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
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
                : errorMessage != null && mealPlan == null
                ? SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 50, color: Colors.grey)
                        .animate()
                        .fadeIn(duration: 400.ms),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _loadMealPlan(forceRefresh: true),
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
                : mealPlan == null
                ? SliverFillRemaining(
              child: Center(
                child: const Text(
                  'Меню еще не создано',
                  style: TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
                ).animate().fadeIn(duration: 400.ms),
              ),
            )
                : SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final mealType = sortedMealTypes[index];
                    final mealTypeId = mealType['id'].toString();
                    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
                    final dayPlan = mealPlan!['plan'][dateKey] as Map<String, dynamic>?;

                    if (dayPlan == null || !dayPlan.containsKey(mealTypeId)) {
                      return const SizedBox.shrink();
                    }

                    final recipeId = dayPlan[mealTypeId].toString();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (index == 0 || mealType['order'] != sortedMealTypes[index - 1]['order'])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              mealType['name'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                          ),
                        FutureBuilder<Map<String, dynamic>>(
                          future: ApiRecipes.getRecipeById(int.parse(recipeId)),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(
                                height: 100,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C73F1)),
                                  ),
                                ),
                              );
                            }
                            if (snapshot.hasError || !snapshot.hasData) {
                              _logger.e('Recipe $recipeId not found: ${snapshot.error}');
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.delete, color: Colors.grey),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Рецепт удалён',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2D2D2D),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Тип блюда: ${mealType['name']}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.swap_horiz, color: Color(0xFF7C73F1)),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => ReplaceRecipeDialog(
                                              date: dateKey,
                                              mealTypeId: int.parse(mealTypeId),
                                              mealTypeName: mealType['name'],
                                              onReplace: _replaceRecipe,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn(
                                delay: (100 * index).ms,
                                duration: 400.ms,
                              );
                            }
                            final recipe = snapshot.data!;
                            return FutureBuilder<String>(
                              future: ApiRecipes.getRecipeImageUrl(recipe['id']),
                              builder: (context, imageSnapshot) {
                                final imagePath = imageSnapshot.data ?? '';
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
                                    if (result == true && mounted) {
                                      _loadMealPlan();
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: _buildRecipeImage(imagePath),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  recipe['title'],
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF2D2D2D),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Тип блюда: ${mealType['name']}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.swap_horiz, color: Color(0xFF7C73F1)),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => ReplaceRecipeDialog(
                                                  date: dateKey,
                                                  mealTypeId: int.parse(mealTypeId),
                                                  mealTypeName: mealType['name'],
                                                  onReplace: _replaceRecipe,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ).animate().fadeIn(
                                  delay: (100 * index).ms,
                                  duration: 400.ms,
                                );
                              },
                            );
                          },
                        ),
                      ],
                    );
                  },
                  childCount: sortedMealTypes.length,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => MealPlanDialog(
              onGenerate: _generateMealPlan,
            ),
          );
        },
        backgroundColor: const Color(0xFF7C73F1),
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: const Text('Сгенерировать', style: TextStyle(color: Colors.white)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
    );
  }
}
