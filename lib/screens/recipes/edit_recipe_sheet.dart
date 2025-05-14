import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mealflow_app/services/api_recipes.dart';
import '../../services/api_utils.dart';
import 'add_ingredient_dialog.dart';
import 'add_step_dialog.dart';
import 'add_dish_category_dialog.dart';
import 'add_tag_dialog.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:mealflow_app/models/meal_type.dart';

class EditRecipeSheet extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const EditRecipeSheet({super.key, required this.recipe});

  @override
  State<EditRecipeSheet> createState() => _EditRecipeSheetState();
}

class _EditRecipeSheetState extends State<EditRecipeSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _totalTimeController;
  late TextEditingController _servingsController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinsController;
  late TextEditingController _fatsController;
  late TextEditingController _carbohydratesController;
  List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> _steps = [];
  List<Map<String, dynamic>> _dishCategories = [];
  List<Map<String, dynamic>> _tags = [];
  List<dynamic>? availableIngredients;
  List<dynamic>? availableMealTypes;
  List<dynamic>? availableDishCategories;
  List<dynamic>? availableTags;
  File? _selectedImage;
  bool _deleteImage = false;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isDataLoading = true;
  final Logger _logger = Logger();
  List<int> _selectedMealTypeIds = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recipe['title']);
    _descriptionController = TextEditingController(text: widget.recipe['description'] ?? '');
    _totalTimeController = TextEditingController(text: widget.recipe['total_time']?.toString() ?? '');
    _servingsController = TextEditingController(text: widget.recipe['servings']?.toString() ?? '');
    _caloriesController = TextEditingController(text: widget.recipe['calories']?.toString() ?? '');
    _proteinsController = TextEditingController(text: widget.recipe['proteins']?.toString() ?? '');
    _fatsController = TextEditingController(text: widget.recipe['fats']?.toString() ?? '');
    _carbohydratesController = TextEditingController(text: widget.recipe['carbohydrates']?.toString() ?? '');
    _steps = List<Map<String, dynamic>>.from(widget.recipe['steps']);
    _ingredients = (widget.recipe['ingredients'] as List<dynamic>)
        .map((ing) => {
      'ingredient_id': ing['ingredient']['id'],
      'amount': ing['amount'],
      'ingredient_name': ing['ingredient']['ingredient_name'],
      'unit': ing['ingredient']['unit'],
    })
        .toList();
    _selectedMealTypeIds = (widget.recipe['meal_types'] as List<dynamic>)
        .map((mt) => mt['meal_type']['id'] as int)
        .toList();
    _dishCategories = (widget.recipe['dish_categories'] as List<dynamic>)
        .map((cat) => {
      'dish_category_id': cat['dish_category']['id'],
      'name': cat['dish_category']['name'],
    })
        .toList();
    _tags = (widget.recipe['tags'] as List<dynamic>)
        .map((tag) => {
      'tag_id': tag['tag']['id'],
      'name': tag['tag']['name'],
    })
        .toList();
    _loadAvailableData();
  }

  Future<void> _loadAvailableData() async {
    setState(() => _isDataLoading = true);
    try {
      availableIngredients = await ApiRecipes.getAvailableIngredients();
      availableMealTypes = await ApiRecipes.getAvailableMealTypes();
      availableDishCategories = await ApiRecipes.getAvailableDishCategories();
      availableTags = await ApiRecipes.getAvailableTags();
    } catch (e) {
      _logger.e('Ошибка загрузки данных: $e');
      final cachedIngredients = await ApiUtils.getCachedData(ApiRecipes.ingredientsCacheKey);
      availableIngredients = cachedIngredients != null ? jsonDecode(cachedIngredients['data']) : [];
      final cachedMealTypes = await ApiUtils.getCachedData(ApiRecipes.mealTypesCacheKey);
      availableMealTypes = cachedMealTypes != null ? jsonDecode(cachedMealTypes['data']) : [];
      final cachedDishCategories = await ApiUtils.getCachedData(ApiRecipes.dishCategoriesCacheKey);
      availableDishCategories = cachedDishCategories != null ? jsonDecode(cachedDishCategories['data']) : [];
      final cachedTags = await ApiUtils.getCachedData(ApiRecipes.tagsCacheKey);
      availableTags = cachedTags != null ? jsonDecode(cachedTags['data']) : [];
    }
    if (mounted) {
      setState(() => _isDataLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _deleteImage = false;
      });
      _logger.d('Выбрано новое изображение: ${pickedFile.path}');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _deleteImage = true;
    });
    _logger.d('Изображение отмечено для удаления');
  }

  void _addIngredient() async {
    if (availableIngredients == null || availableIngredients!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ингредиенты ещё не загружены')),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddIngredientDialog(availableIngredients: availableIngredients!),
    );
    if (result != null) {
      setState(() => _ingredients.add(result));
      _logger.d('Добавлен ингредиент: $result');
    }
  }

  void _addStep() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddStepDialog(),
    );
    if (result != null) {
      setState(() {
        _steps.add({
          'step_number': _steps.length + 1,
          'description': result['description'],
          'duration': result['duration'],
        });
      });
      _logger.d('Добавлен шаг: $result');
    }
  }

  void _addDishCategory() async {
    if (availableDishCategories == null || availableDishCategories!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Категории блюд ещё не загружены')),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddDishCategoryDialog(availableDishCategories: availableDishCategories!),
    );
    if (result != null) {
      setState(() {
        if (!_dishCategories.any((cat) => cat['dish_category_id'] == result['dish_category_id'])) {
          _dishCategories.add(result);
        }
      });
      _logger.d('Добавлена категория блюда: $result');
    }
  }

  void _addTag() async {
    if (availableTags == null || availableTags!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Теги ещё не загружены')),
      );
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddTagDialog(availableTags: availableTags!),
    );
    if (result != null) {
      setState(() {
        if (!_tags.any((tag) => tag['tag_id'] == result['tag_id'])) {
          _tags.add(result);
        }
      });
      _logger.d('Добавлен тег: $result');
    }
  }

  Future<void> _updateRecipe() async {
    if (!_formKey.currentState!.validate() || _ingredients.isEmpty || _steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполни все обязательные поля и добавь ингредиенты с шагами'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!await ApiUtils.isOnline()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Отсутствует подключение к интернету'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiRecipes.updateRecipe(
        recipeId: widget.recipe['id'],
        title: _titleController.text.trim(),
        steps: _steps,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        ingredients: _ingredients
            .map((ing) => {
          'ingredient_id': ing['ingredient_id'],
          'amount': ing['amount'],
        })
            .toList(),
        image: _selectedImage,
        isPublic: widget.recipe['is_public'] ?? false,
        mealTypeIds: _selectedMealTypeIds,
        dishCategoryIds: _dishCategories.map((cat) => cat['dish_category_id'] as int).toList(),
        tagIds: _tags.map((tag) => tag['tag_id'] as int).toList(),
        totalTime: _totalTimeController.text.trim().isEmpty ? null : int.parse(_totalTimeController.text.trim()),
        servings: _servingsController.text.trim().isEmpty ? null : int.parse(_servingsController.text.trim()),
        calories: _caloriesController.text.trim().isEmpty ? null : double.parse(_caloriesController.text.trim()),
        proteins: _proteinsController.text.trim().isEmpty ? null : double.parse(_proteinsController.text.trim()),
        fats: _fatsController.text.trim().isEmpty ? null : double.parse(_fatsController.text.trim()),
        carbohydrates: _carbohydratesController.text.trim().isEmpty ? null : double.parse(_carbohydratesController.text.trim()),
      );
      _logger.i('Рецепт ${_titleController.text} успешно обновлён');
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Рецепт успешно обновлен'),
            backgroundColor: Color(0xFF7C73F1),
          ),
        );
      }
    } catch (e) {
      _logger.e('Ошибка обновления рецепта: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        if (e.toString().contains('Не удалось обновить токен')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка авторизации. Пожалуйста, попробуйте снова или войдите заново.'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDataLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C73F1)),
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
        ),
        child: Stack(
          children: [
            Scaffold(
              resizeToAvoidBottomInset: true,
              body: SingleChildScrollView(
                controller: controller,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 24,
                    left: 24,
                    right: 24,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Редактировать Рецепт',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D2D2D),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: Colors.grey[600]),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ).animate().fadeIn(duration: 400.ms),
                        const SizedBox(height: 20),
                        _buildImagePicker(),
                        const SizedBox(height: 20),
                        _buildTextField(
                          _titleController,
                          'Название рецепта',
                          validator: (v) => v!.isEmpty ? 'Введите название' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(_descriptionController, 'Описание (опционально)', maxLines: 3),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _totalTimeController,
                          'Общее время приготовления (минуты)',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v!.isNotEmpty && (int.tryParse(v) == null || int.parse(v) <= 0)) {
                              return 'Введите корректное число';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _servingsController,
                          'Количество порций',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v!.isNotEmpty && (int.tryParse(v) == null || int.parse(v) <= 0)) {
                              return 'Введите корректное число';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _caloriesController,
                          'Калории (ккал, опционально)',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v!.isNotEmpty && double.tryParse(v) == null) return 'Введите корректное число';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _proteinsController,
                          'Белки (г, опционально)',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v!.isNotEmpty && double.tryParse(v) == null) return 'Введите корректное число';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _fatsController,
                          'Жиры (г, опционально)',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v!.isNotEmpty && double.tryParse(v) == null) return 'Введите корректное число';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _carbohydratesController,
                          'Углеводы (г, опционально)',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v!.isNotEmpty && double.tryParse(v) == null) return 'Введите корректное число';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildMealTypeSelector(),
                        const SizedBox(height: 16),
                        _buildSectionHeader('Категории блюд', _addDishCategory),
                        if (_dishCategories.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Добавь категории блюд',
                              style: TextStyle(color: Colors.grey[500], fontSize: 16),
                            ),
                          )
                        else
                          ..._dishCategories.map((cat) => _buildCategoryItem(cat)).toList(),
                        const SizedBox(height: 16),
                        _buildSectionHeader('Теги', _addTag),
                        if (_tags.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Добавь теги',
                              style: TextStyle(color: Colors.grey[500], fontSize: 16),
                            ),
                          )
                        else
                          ..._tags.map((tag) => _buildTagItem(tag)).toList(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Ингредиенты', _addIngredient),
                        if (_ingredients.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Добавь ингредиенты',
                              style: TextStyle(color: Colors.grey[500], fontSize: 16),
                            ),
                          )
                        else
                          ..._ingredients.map((ing) => _buildIngredientItem(ing)).toList(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Шаги', _addStep),
                        if (_steps.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Добавь шаги',
                              style: TextStyle(color: Colors.grey[500], fontSize: 16),
                            ),
                          )
                        else
                          ..._steps.asMap().entries.map((entry) => _buildStepItem(entry.key, entry.value)).toList(),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _updateRecipe,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C73F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Text(
                            'Сохранить',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.2),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C73F1)),
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().slideY(begin: 0.5, duration: 600.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: _selectedImage != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 150,
              ),
            )
                : _deleteImage
                ? _buildImagePlaceholder()
                : _buildRecipeImage(widget.recipe),
          ),
        ).animate().fadeIn(duration: 400.ms),
        if (_selectedImage != null || (!_deleteImage && widget.recipe['image_path'] != null))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: _removeImage,
              icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              label: const Text(
                'Удалить фото',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecipeImage(Map<String, dynamic> recipe) {
    return FutureBuilder<String>(
      future: ApiRecipes.getRecipeImageUrl(widget.recipe['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C73F1)),
            ),
          );
        }
        if (snapshot.hasData) {
          final imageUrl = snapshot.data!;
          if (imageUrl.startsWith('http')) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 150,
                errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
              ),
            );
          } else {
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(imageUrl),
                fit: BoxFit.cover,
                width: double.infinity,
                height: 150,
                errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
              ),
            );
          }
        }
        return _buildImagePlaceholder();
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 40, color: Colors.grey[600]),
        const SizedBox(height: 8),
        Text(
          'Добавить или изменить фото',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label, {
        int maxLines = 1,
        String? Function(String?)? validator,
        TextInputType? keyboardType,
      }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator,
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildMealTypeSelector() {
    if (availableMealTypes == null || availableMealTypes!.isEmpty) {
      return const Text(
        'Типы блюд ещё не загружены',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Типы блюд',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableMealTypes!.map((type) {
            final mealType = MealType.fromJson(type);
            final isSelected = _selectedMealTypeIds.contains(mealType.id);
            return FilterChip(
              label: Text(mealType.displayName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedMealTypeIds.add(mealType.id);
                  } else {
                    _selectedMealTypeIds.remove(mealType.id);
                  }
                });
              },
              selectedColor: const Color(0xFF7C73F1).withOpacity(0.2),
              checkmarkColor: const Color(0xFF7C73F1),
              labelStyle: TextStyle(color: isSelected ? const Color(0xFF7C73F1) : Colors.grey[800]),
            );
          }).toList(),
        ).animate().fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
        ).animate().fadeIn(duration: 400.ms),
        IconButton(
          icon: const Icon(Icons.add_circle, color: Color(0xFF7C73F1)),
          onPressed: onAdd,
        ).animate().scale(duration: 400.ms),
      ],
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    return Dismissible(
      key: Key(category['dish_category_id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        setState(() => _dishCategories.remove(category));
        _logger.d('Удалена категория: ${category['name']}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
                category['name'],
                style: const TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildTagItem(Map<String, dynamic> tag) {
    return Dismissible(
      key: Key(tag['tag_id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        setState(() => _tags.remove(tag));
        _logger.d('Удалён тег: ${tag['name']}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
                tag['name'],
                style: const TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildIngredientItem(Map<String, dynamic> ingredient) {
    return Dismissible(
      key: Key(ingredient['ingredient_id'].toString() + ingredient['amount'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        setState(() => _ingredients.remove(ingredient));
        _logger.d('Удалён ингредиент: ${ingredient['ingredient_name']}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
                '${ingredient['ingredient_name']} (${ingredient['amount']} ${ingredient['unit']})',
                style: const TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildStepItem(int index, Map<String, dynamic> step) {
    return Dismissible(
      key: Key(step['step_number'].toString() + step['description']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        setState(() {
          _steps.removeAt(index);
          for (int i = 0; i < _steps.length; i++) {
            _steps[i]['step_number'] = i + 1;
          }
        });
        _logger.d('Удалён шаг: ${step['description']}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFF7C73F1),
              child: Text(
                '${step['step_number']}',
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step['description'],
                    style: const TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
                  ),
                  if (step['duration'] != null && step['duration'].isNotEmpty)
                    Text(
                      '(${step['duration']})',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _totalTimeController.dispose();
    _servingsController.dispose();
    _caloriesController.dispose();
    _proteinsController.dispose();
    _fatsController.dispose();
    _carbohydratesController.dispose();
    super.dispose();
  }
}
