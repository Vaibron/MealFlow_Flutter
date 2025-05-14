import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mealflow_app/services/api_recipes.dart';

class ReplaceRecipeDialog extends StatefulWidget {
  final String date;
  final int mealTypeId;
  final String mealTypeName;
  final Function(String, int, int?) onReplace;

  const ReplaceRecipeDialog({
    required this.date,
    required this.mealTypeId,
    required this.mealTypeName,
    required this.onReplace,
    super.key,
  });

  @override
  State<ReplaceRecipeDialog> createState() => _ReplaceRecipeDialogState();
}

class _ReplaceRecipeDialogState extends State<ReplaceRecipeDialog> {
  List<dynamic> availableRecipes = [];
  bool isLoading = false;
  String? errorMessage;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _loadAvailableRecipes();
  }

  Future<void> _loadAvailableRecipes() async {
    setState(() => isLoading = true);
    try {
      _logger.i('Loading recipes for mealTypeId: ${widget.mealTypeId}, mealTypeName: ${widget.mealTypeName}');
      final recipes = await ApiRecipes.getRecipes(
        showMealflow: true,
        limit: 100,
        forceRefresh: true,
      );
      _logger.i('Loaded ${recipes.length} recipes: $recipes');

      final filteredRecipes = recipes.where((recipe) {
        final mealTypes = recipe['meal_types'] as List<dynamic>?;
        final mealTypeIds = mealTypes
            ?.map((mt) => mt['meal_type']['id'] as int)
            .toList() ??
            [];
        _logger.d('Recipe: ${recipe['title']}, mealTypeIds: $mealTypeIds');
        return mealTypeIds.contains(widget.mealTypeId);
      }).toList();

      _logger.i('Filtered ${filteredRecipes.length} recipes for mealTypeId: ${widget.mealTypeId}');
      setState(() {
        availableRecipes = filteredRecipes;
        isLoading = false;
      });
    } catch (e) {
      _logger.e('Error loading recipes: $e');
      setState(() {
        errorMessage = 'Не удалось загрузить рецепты: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Заменить блюдо (${widget.mealTypeName})'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(child: Text(errorMessage!))
            : availableRecipes.isEmpty
            ? const Center(child: Text('Нет доступных рецептов для замены'))
            : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: () async {
                try {
                  await widget.onReplace(widget.date, widget.mealTypeId, null);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Рецепт заменен случайно')),
                    );
                  }
                } catch (e) {
                  _logger.e('Error replacing recipe randomly: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка замены рецепта: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C73F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Заменить случайно'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Или выберите рецепт:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableRecipes.length,
                itemBuilder: (context, index) {
                  final recipe = availableRecipes[index];
                  return ListTile(
                    title: Text(recipe['title']),
                    onTap: () async {
                      _logger.i('Selected recipe for replacement: ${recipe['title']} (ID: ${recipe['id']})');
                      try {
                        await widget.onReplace(
                          widget.date,
                          widget.mealTypeId,
                          recipe['id'],
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Рецепт "${recipe['title']}" успешно заменен')),
                          );
                        }
                      } catch (e) {
                        _logger.e('Error replacing recipe: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка замены рецепта: $e')),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}
