import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class AddTagDialog extends StatefulWidget {
  final List<dynamic> availableTags;

  const AddTagDialog({super.key, required this.availableTags});

  @override
  State<AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<AddTagDialog> {
  int? selectedTagId;
  final Logger _logger = Logger();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Выберите тег',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.availableTags.map((tag) {
            final tagId = tag['id'] as int;
            final tagName = tag['name'] as String;
            return RadioListTile<int>(
              title: Text(tagName, style: const TextStyle(fontSize: 16)),
              value: tagId,
              groupValue: selectedTagId,
              activeColor: const Color(0xFF7C73F1),
              onChanged: (value) {
                setState(() {
                  selectedTagId = value;
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
          onPressed: selectedTagId == null
              ? null
              : () {
            final selectedTag = widget.availableTags.firstWhere(
                  (t) => t['id'] == selectedTagId,
              orElse: () => null,
            );
            if (selectedTag != null) {
              _logger.d('Выбран тег: ${selectedTag['name']}');
              Navigator.pop(context, {
                'tag_id': selectedTag['id'],
                'name': selectedTag['name'],
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