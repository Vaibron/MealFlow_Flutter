import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'package:mealflow_app/services/api_news.dart';
import 'package:mealflow_app/screens/news/news_detail_screen.dart';
import 'package:logger/logger.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<Map<String, dynamic>> newsList = [];
  Map<int, String?> imagePaths = {};
  bool isLoading = true;
  String? errorMessage;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    fetchNews();
  }

  Future<void> fetchNews({bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final news = await ApiNews.getNews(forceRefresh: forceRefresh);
      setState(() {
        newsList = news;
        isLoading = false;
      });
      _logger.i('Новости загружены: ${news.length} элементов');
      for (var news in newsList) {
        if (!imagePaths.containsKey(news['id'])) {
          _preloadImage(news['id']);
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Не удалось загрузить новости: $e';
      });
      _logger.e('Ошибка загрузки новостей: $e');
    }
  }

  Future<void> _preloadImage(int newsId) async {
    final path = await ApiNews.getNewsImageUrl(newsId);
    if (path != null && mounted) {
      setState(() {
        imagePaths[newsId] = path;
      });
      _logger.d('Изображение предзагружено для новости $newsId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () => fetchNews(forceRefresh: true),
        color: const Color(0xFF7C73F1),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 160.0,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF7C73F1), Color(0xFF9B93F7)],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.newspaper, size: 50, color: Colors.white)
                            .animate()
                            .scale(duration: 600.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 8),
                        const Text(
                          'Статьи',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
                        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            isLoading && newsList.isEmpty
                ? SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C73F1)),
                ).animate().scale(duration: 600.ms),
              ),
            )
                : errorMessage != null && newsList.isEmpty
                ? SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off,
                      size: 50,
                      color: Colors.grey,
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => fetchNews(forceRefresh: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C73F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Попробовать снова'),
                    ).animate().scale(duration: 600.ms),
                  ],
                ),
              ),
            )
                : newsList.isEmpty
                ? SliverFillRemaining(
              child: Center(
                child: const Text(
                  'Новостей пока нет',
                  style: TextStyle(fontSize: 16, color: Color(0xFF2D2D2D)),
                ).animate().fadeIn(duration: 400.ms),
              ),
            )
                : SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final news = newsList[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NewsDetailScreen(news: news),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (imagePaths[news['id']] != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(imagePaths[news['id']]!),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        _logger.e('Error loading image: $error');
                                        return _buildPlaceholderImage();
                                      },
                                    ),
                                  )
                                else
                                  FutureBuilder<String?>(
                                    future: ApiNews.getNewsImageUrl(news['id']),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C73F1)),
                                            ),
                                          ),
                                        );
                                      }
                                      if (snapshot.hasData && snapshot.data != null) {
                                        imagePaths[news['id']] = snapshot.data;
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            File(snapshot.data!),
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              _logger.e('Error loading image: $error');
                                              return _buildPlaceholderImage();
                                            },
                                          ),
                                        );
                                      }
                                      return _buildPlaceholderImage();
                                    },
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        news['title'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2D2D2D),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        news['content'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Опубликовано: ${DateTime.parse(news['created_at']).toLocal().toString().split('.')[0]}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: newsList.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
}
