import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../recipes/recipes_screen.dart';
import '../profile/profile_screen.dart';
import '../news/news_screen.dart';
import '../meal_plan/meal_plan_screen.dart';
import '../../services/api_profile.dart';
import '../../services/api_meal_planner.dart';
import '../../services/api_recipes.dart';
import 'bottom_navigation_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 2;
  bool _isEmailVerified = false;
  Map<String, dynamic>? _mealPlan;
  bool _isMealPlanLoading = false;
  String? _mealPlanError;
  final Logger _logger = Logger();

  final List<Widget> _pages = [
    const MealPlanScreen(),
    const RecipesScreen(),
    const HomeContent(),
    const NewsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkEmailVerification();
    _loadMealPlan();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkEmailVerification(forceRefresh: true);
      _loadMealPlan(forceRefresh: true);
    }
  }

  Future<void> _checkEmailVerification({bool forceRefresh = false}) async {
    try {
      final data = await ApiProfile.getProtectedData(forceRefresh: forceRefresh);
      setState(() {
        _isEmailVerified = data['is_verified'] ?? false;
      });
      _logger.i('Статус верификации: $_isEmailVerified');
    } catch (e) {
      _logger.e('Ошибка проверки статуса email: $e');
    }
  }

  Future<void> _loadMealPlan({bool forceRefresh = false}) async {
    setState(() {
      _isMealPlanLoading = true;
      _mealPlanError = null;
    });
    try {
      final mealPlanData = await ApiMealPlanner.getMealPlan(forceRefresh: forceRefresh);
      setState(() {
        _mealPlan = mealPlanData;
        _isMealPlanLoading = false;
      });
      _logger.i('Meal plan loaded successfully');
    } catch (e) {
      setState(() {
        _mealPlanError = e.toString();
        _isMealPlanLoading = false;
      });
      _logger.e('Error loading meal plan: $e');
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _checkEmailVerification(forceRefresh: true),
      _loadMealPlan(forceRefresh: true),
    ]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onPopInvokedWithResult(bool didPop, dynamic result) {
    if (didPop) return;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: Scaffold(
        body: _selectedIndex == 2
            ? HomeContent(
          mealPlan: _mealPlan,
          isMealPlanLoading: _isMealPlanLoading,
          mealPlanError: _mealPlanError,
          onRetry: () => _loadMealPlan(forceRefresh: true),
          onRefresh: _onRefresh,
        )
            : _pages[_selectedIndex],
        bottomNavigationBar: CustomBottomNavigationBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
          isEmailVerified: _isEmailVerified,
        ),
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final Map<String, dynamic>? mealPlan;
  final bool isMealPlanLoading;
  final String? mealPlanError;
  final VoidCallback? onRetry;
  final VoidCallback? onRefresh;

  const HomeContent({
    super.key,
    this.mealPlan,
    this.isMealPlanLoading = false,
    this.mealPlanError,
    this.onRetry,
    this.onRefresh,
  });

  List<Map<String, dynamic>> _getSortedMealTypes() {
    if (mealPlan == null || mealPlan!['meal_types'] == null) {
      return [];
    }
    final mealTypes = (mealPlan!['meal_types'] as List<dynamic>).cast<Map<String, dynamic>>();
    return mealTypes..sort((a, b) => a['order'].compareTo(b['order']));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth * 0.05;
    final now = DateTime.now();
    final formattedDate = DateFormat('d MMMM, EEEE', 'ru').format(now);
    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    final sortedMealTypes = _getSortedMealTypes();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8E6F5), Color(0xFFFFFFFF)],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => onRefresh?.call(),
          color: const Color(0xFF5C4DB1),
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 1.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate.toUpperCase(),
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: padding * 1.5),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'МЕНЮ НА СЕГОДНЯ',
                          style: TextStyle(
                            fontSize: screenWidth * 0.07,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D2D2D),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: padding * 1.5),
                        Container(
                          width: screenWidth * 0.95,
                          padding: EdgeInsets.all(padding * 1.2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: isMealPlanLoading
                              ? SizedBox(
                            height: 100,
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5C4DB1)),
                                strokeWidth: 3,
                              ),
                            ),
                          )
                              : mealPlanError != null
                              ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ошибка загрузки меню',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.redAccent[700],
                                  fontSize: screenWidth * 0.045,
                                ),
                              ),
                              SizedBox(height: padding * 0.8),
                              Text(
                                mealPlanError!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: screenWidth * 0.04,
                                ),
                              ),
                              SizedBox(height: padding * 0.8),
                              TextButton(
                                onPressed: onRetry,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Попробовать снова',
                                  style: TextStyle(
                                    color: const Color(0xFF5C4DB1),
                                    fontSize: screenWidth * 0.04,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          )
                              : mealPlan == null || mealPlan!['plan'][dateKey] == null
                              ? Padding(
                            padding: EdgeInsets.symmetric(vertical: padding),
                            child: Text(
                              'Меню на сегодня не задано',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                              : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: sortedMealTypes.map((mealType) {
                              final mealTypeId = mealType['id'].toString();
                              final dayPlan = mealPlan!['plan'][dateKey] as Map<String, dynamic>?;
                              if (dayPlan == null || !dayPlan.containsKey(mealTypeId)) {
                                return const SizedBox.shrink();
                              }
                              final recipeId = dayPlan[mealTypeId].toString();
                              return FutureBuilder<Map<String, dynamic>>(
                                future: ApiRecipes.getRecipeById(int.parse(recipeId)),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return SizedBox(
                                      height: 80,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5C4DB1)),
                                          strokeWidth: 3,
                                        ),
                                      ),
                                    );
                                  }
                                  if (snapshot.hasError || !snapshot.hasData) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${mealType['name']}:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: screenWidth * 0.05,
                                            color: const Color(0xFF2D2D2D),
                                          ),
                                        ),
                                        SizedBox(height: padding * 0.5),
                                        Text(
                                          'Рецепт недоступен',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: screenWidth * 0.045,
                                          ),
                                        ),
                                        SizedBox(height: padding),
                                      ],
                                    );
                                  }
                                  final recipe = snapshot.data!;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${mealType['name']}:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: screenWidth * 0.05,
                                          color: const Color(0xFF2D2D2D),
                                        ),
                                      ),
                                      SizedBox(height: padding * 0.5),
                                      Text(
                                        recipe['title'],
                                        style: TextStyle(
                                          color: const Color(0xFF2D2D2D),
                                          fontSize: screenWidth * 0.045,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: padding),
                                    ],
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: padding * 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: padding),
                      Expanded(
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: padding),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: padding),
                      Expanded(
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}