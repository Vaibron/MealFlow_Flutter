import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:logger/logger.dart';

class AddIngredientDialog extends StatefulWidget {
  final List<dynamic> availableIngredients;

  const AddIngredientDialog({super.key, required this.availableIngredients});

  @override
  State<AddIngredientDialog> createState() => _AddIngredientDialogState();
}

class _AddIngredientDialogState extends State<AddIngredientDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedIngredientId;
  final _amountController = TextEditingController();
  final Logger _logger = Logger();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Добавить ингредиент',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                value: _selectedIngredientId,
                decoration: InputDecoration(
                  labelText: 'Ингредиент',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: widget.availableIngredients
                    .map((ing) => DropdownMenuItem<int>(
                  value: ing['id'] as int,
                  child: Text(ing['ingredient_name'] as String),
                ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedIngredientId = value),
                validator: (value) => value == null ? 'Выбери ингредиент' : null,
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Количество',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value!.isEmpty) return 'Введи количество';
                  if (double.tryParse(value) == null) return 'Введи корректное число';
                  return null;
                },
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Отмена', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final ingredient = widget.availableIngredients
                            .firstWhere((ing) => ing['id'] == _selectedIngredientId);
                        final result = {
                          'ingredient_id': _selectedIngredientId,
                          'amount': double.parse(_amountController.text),
                          'ingredient_name': ingredient['ingredient_name'] as String,
                          'unit': ingredient['unit'] as String,
                        };
                        _logger.d('Добавлен ингредиент: $result');
                        Navigator.pop(context, result);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C73F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Добавить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
