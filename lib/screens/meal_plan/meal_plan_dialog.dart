import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mealflow_app/services/api_meal_planner.dart';
import 'package:mealflow_app/services/api_recipes.dart';

class MealPlanDialog extends StatefulWidget {
  final Function(int, int, List<int>, String, DateTime) onGenerate;

  const MealPlanDialog({required this.onGenerate, super.key});

  @override
  State<MealPlanDialog> createState() => _MealPlanDialogState();
}

class _MealPlanDialogState extends State<MealPlanDialog> {
  int days = 1;
  int persons = 1;
  DateTime startDate = DateTime.now();
  List<int> excludedIngredients = [];
  List<dynamic> availableIngredients = [];
  String recipeSource = 'both';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    availableIngredients = await ApiRecipes.getAvailableIngredients();
    excludedIngredients = (await ApiMealPlanner.getExcludedIngredients())
        .map((e) => e['ingredient_id'] as int)
        .toList();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Сгенерировать меню'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Дата начала'),
                readOnly: true,
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime.now(), // Нельзя выбрать дату раньше текущей
                    lastDate: DateTime.now().add(const Duration(days: 14)), // Максимум +14 дней
                  );
                  if (pickedDate != null) {
                    setState(() {
                      startDate = pickedDate;
                      // Ограничиваем количество дней, если выбранная дата близка к последней доступной
                      final maxDays = (14 - (pickedDate.difference(DateTime.now()).inDays)).clamp(1, 7);
                      if (days > maxDays) {
                        days = maxDays;
                      }
                    });
                  }
                },
                controller: TextEditingController(text: DateFormat('dd MMM yyyy').format(startDate)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: days,
                decoration: const InputDecoration(labelText: 'Дней'),
                items: List.generate(
                  // Ограничиваем максимальное количество дней: не более 7 и не более, чем позволяет дата
                  (14 - (startDate.difference(DateTime.now()).inDays)).clamp(1, 7),
                      (index) => index + 1,
                ).map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                onChanged: (value) => setState(() => days = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: persons,
                decoration: const InputDecoration(labelText: 'Персон'),
                items: List.generate(10, (index) => index + 1)
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                    .toList(),
                onChanged: (value) => setState(() => persons = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: recipeSource,
                decoration: const InputDecoration(labelText: 'Источник рецептов'),
                items: const [
                  DropdownMenuItem(value: 'mine', child: Text('Только мои')),
                  DropdownMenuItem(value: 'mealflow', child: Text('Только MealFlow')),
                  DropdownMenuItem(value: 'both', child: Text('Оба')),
                ],
                onChanged: (value) => setState(() => recipeSource = value!),
              ),
              const SizedBox(height: 16),
              const Text('Исключить ингредиенты:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: availableIngredients.length,
                  itemBuilder: (context, index) {
                    final ingredient = availableIngredients[index];
                    final isExcluded = excludedIngredients.contains(ingredient['id']);
                    return CheckboxListTile(
                      title: Text(ingredient['ingredient_name']),
                      value: isExcluded,
                      onChanged: (value) {
                        setState(() {
                          if (value!) {
                            excludedIngredients.add(ingredient['id']);
                          } else {
                            excludedIngredients.remove(ingredient['id']);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onGenerate(days, persons, excludedIngredients, recipeSource, startDate);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C73F1),
            foregroundColor: Colors.white,
          ),
          child: const Text('Сгенерировать'),
        ),
      ],
    );
  }
}
