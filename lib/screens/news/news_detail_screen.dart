import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../services/api_news.dart';
import 'dart:io';

class NewsDetailScreen extends StatefulWidget {
  final Map<String, dynamic> news;

  const NewsDetailScreen({super.key, required this.news});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  String? imagePath;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final path = await ApiNews.getNewsImageUrl(widget.news['id']);
      if (path != null && mounted) {
        setState(() {
          imagePath = path;
        });
        _logger.i('Изображение загружено для новости ${widget.news['id']}: $path');
      } else {
        _logger.w('Изображение не найдено для новости ${widget.news['id']}');
      }
    } catch (e) {
      _logger.e('Ошибка загрузки изображения для новости ${widget.news['id']}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.news['title'],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF9890F7),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.news['title'],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 16),
            if (imagePath == null)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C73F1)),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(imagePath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200, // Фиксированная высота для консистентности
                  errorBuilder: (context, error, stackTrace) {
                    _logger.e('Ошибка отображения изображения: $error');
                    return Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Text(
                          'Изображение недоступно',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Text(
              widget.news['content'],
              style: const TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
            ),
            const SizedBox(height: 16),
            Text(
              'Опубликовано: ${DateTime.parse(widget.news['created_at']).toLocal().toString().split('.')[0]}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Обновлено: ${DateTime.parse(widget.news['updated_at']).toLocal().toString().split('.')[0]}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
