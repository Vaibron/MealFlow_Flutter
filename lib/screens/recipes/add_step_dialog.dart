import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:logger/logger.dart';

class AddStepDialog extends StatefulWidget {
  const AddStepDialog({super.key});

  @override
  State<AddStepDialog> createState() => _AddStepDialogState();
}

class _AddStepDialogState extends State<AddStepDialog> {
  final _formKey = GlobalKey<FormState>();
  final _stepController = TextEditingController();
  final _durationController = TextEditingController();
  final Logger _logger = Logger();

  @override
  void dispose() {
    _stepController.dispose();
    _durationController.dispose();
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
                'Добавить шаг',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 20),
              TextFormField(
                controller: _stepController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Описание шага',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) => value!.trim().isEmpty ? 'Введи описание шага' : null,
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                decoration: InputDecoration(
                  labelText: 'Длительность (опционально)',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty && !RegExp(r'^\d+$').hasMatch(value)) {
                    return 'Введи корректное число (минуты)';
                  }
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
                        final step = {
                          'description': _stepController.text.trim(),
                          'duration': _durationController.text.trim().isEmpty
                              ? null
                              : _durationController.text.trim(),
                        };
                        _logger.d('Добавлен шаг: $step');
                        Navigator.pop(context, step);
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
