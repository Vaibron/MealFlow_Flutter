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

class CreateRecipeSheet extends StatefulWidget {
  final List<dynamic> availableIngredients;
  final List<dynamic> availableMealTypes;
  final List<dynamic> availableDishCategories;
  final List<dynamic> availableTags;

  const CreateRecipeSheet({
    super.key,
    required this.availableIngredients,
    required this.availableMealTypes,
    required this.availableDishCategories,
    required this.availableTags,
  });

  @override
  State<CreateRecipeSheet> createState() => _CreateRecipeSheetState();
}

class _CreateRecipeSheetState extends State<CreateRecipeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalTimeController = TextEditingController();
  final _servingsController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinsController = TextEditingController();
  final _fatsController = TextEditingController();
  final _carbohydratesController = TextEditingController();
  List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> _steps = [];
  List<Map<String, dynamic>> _dishCategories = [];
  List<Map<String, dynamic>> _tags = [];
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  final Logger _logger = Logger();
  List<int> _selectedMealTypeIds = [];

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

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      _logger.d('Выбрано изображение: ${pickedFile.path}');
    }
  }

  void _addIngredient() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddIngredientDialog(availableIngredients: widget.availableIngredients),
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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddDishCategoryDialog(availableDishCategories: widget.availableDishCategories),
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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddTagDialog(availableTags: widget.availableTags),
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

  Future<void> _submitRecipe() async {
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
      await ApiRecipes.createRecipe(
        title: _titleController.text.trim(),
        steps: _steps,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        ingredients: _ingredients,
        image: _selectedImage,
        mealTypeIds: _selectedMealTypeIds,
        dishCategoryIds: _dishCategories.map((cat) => cat['dish_category_id'] as int).toList(),
        tagIds: _tags.map((tag) => tag['tag_id'] as int).toList(),
        totalTime: int.parse(_totalTimeController.text.trim()),
        servings: int.parse(_servingsController.text.trim()),
        calories: _caloriesController.text.trim().isEmpty ? null : double.parse(_caloriesController.text.trim()),
        proteins: _proteinsController.text.trim().isEmpty ? null : double.parse(_proteinsController.text.trim()),
        fats: _fatsController.text.trim().isEmpty ? null : double.parse(_fatsController.text.trim()),
        carbohydrates: _carbohydratesController.text.trim().isEmpty ? null : double.parse(_carbohydratesController.text.trim()),
      );
      _logger.i('Рецепт ${_titleController.text} успешно создан');
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context, true);
        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Рецепт успешно создан'),
            backgroundColor: Color(0xFF7C73F1),
          ),
        );
      }
    } catch (e) {
      _logger.e('Ошибка создания рецепта: $e');
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

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _totalTimeController.clear();
    _servingsController.clear();
    _caloriesController.clear();
    _proteinsController.clear();
    _fatsController.clear();
    _carbohydratesController.clear();
    setState(() {
      _ingredients.clear();
      _steps.clear();
      _dishCategories.clear();
      _tags.clear();
      _selectedImage = null;
      _selectedMealTypeIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                            const Text(
                              'Создай Рецепт',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D2D2D),
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
                            if (v!.isEmpty) return 'Введите время';
                            if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Введите корректное число';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _servingsController,
                          'Количество порций',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v!.isEmpty) return 'Введите количество порций';
                            if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Введите корректное число';
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
                          onPressed: _isLoading ? null : _submitRecipe,
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
                            'Создать',
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
    return GestureDetector(
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
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 40, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              'Добавить фото рецепта',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
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
          children: widget.availableMealTypes.map((type) {
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
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSectionHeader(String title, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF7C73F1), size: 28),
          onPressed: onAdd,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
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
                category['name'],
                style: const TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
              ),
            ),
          ],
        ),
      ),
    ).animate().slideX(begin: 0.2, duration: 400.ms);
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
                tag['name'],
                style: const TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
              ),
            ),
          ],
        ),
      ),
    ).animate().slideX(begin: 0.2, duration: 400.ms);
  }

  Widget _buildIngredientItem(Map<String, dynamic> ing) {
    return Dismissible(
      key: Key(ing['ingredient_id'].toString() + ing['amount'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        setState(() => _ingredients.remove(ing));
        _logger.d('Удалён ингредиент: ${ing['ingredient_name']}');
      },
      child: Padding(
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
                '${ing['ingredient_name']} (${ing['amount']} ${ing['unit']})',
                style: const TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
              ),
            ),
          ],
        ),
      ),
    ).animate().slideX(begin: 0.2, duration: 400.ms);
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
              radius: 14,
              backgroundColor: const Color(0xFF7C73F1),
              child: Text('${step['step_number']}', style: const TextStyle(fontSize: 14, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step['description'], style: const TextStyle(fontSize: 16, color: Color(0xFF2D2D2D))),
                  if (step['duration'] != null)
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
    ).animate().slideX(begin: 0.2, duration: 400.ms);
  }
}
