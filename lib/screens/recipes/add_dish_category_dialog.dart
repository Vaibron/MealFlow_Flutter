import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class AddDishCategoryDialog extends StatefulWidget {
  final List<dynamic> availableDishCategories;

  const AddDishCategoryDialog({super.key, required this.availableDishCategories});

  @override
  State<AddDishCategoryDialog> createState() => _AddDishCategoryDialogState();
}

class _AddDishCategoryDialogState extends State<AddDishCategoryDialog> {
  int? selectedCategoryId;
  final Logger _logger = Logger();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Выберите категорию блюда',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.availableDishCategories.map((category) {
            final categoryId = category['id'] as int;
            final categoryName = category['name'] as String;
            return RadioListTile<int>(
              title: Text(categoryName, style: const TextStyle(fontSize: 16)),
              value: categoryId,
              groupValue: selectedCategoryId,
              activeColor: const Color(0xFF7C73F1),
              onChanged: (value) {
                setState(() {
                  selectedCategoryId = value;
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: selectedCategoryId == null
              ? null
              : () {
            final selectedCategory = widget.availableDishCategories.firstWhere(
                  (cat) => cat['id'] == selectedCategoryId,
              orElse: () => null,
            );
            if (selectedCategory != null) {
              _logger.d('Выбрана категория: ${selectedCategory['name']}');
              Navigator.pop(context, {
                'dish_category_id': selectedCategory['id'],
                'name': selectedCategory['name'],
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C73F1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}