import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<bool> _onWillPop(BuildContext context) async {
    return true; // Разрешаем закрытие приложения на WelcomeScreen
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth * 0.04;

    return WillPopScope(
      onWillPop: () => _onWillPop(context),
      child: Scaffold(
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
              // На WelcomeScreen свайп влево ничего не делает
            }
          },
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFF5F5F5)],
              ),
            ),
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: padding * 2),
                          Image.asset(
                            'assets/book_logo.png',
                            height: 300,
                            width: 300,
                            fit: BoxFit.contain,
                          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                          SizedBox(height: padding * 2),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'Идеальный рацион начинается с умного планирования',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.black),
                            ),
                          ).animate().fadeIn(duration: 400.ms),
                          SizedBox(height: padding * 3),
                          SizedBox(
                            width: screenWidth * 0.75 > 350 ? 350 : screenWidth * 0.75,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(context, '/login');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9890F7),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: padding),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(padding * 2),
                                ),
                              ),
                              child: const Text('Войти', style: TextStyle(fontSize: 18)),
                            ),
                          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                          SizedBox(height: padding),
                          SizedBox(
                            width: screenWidth * 0.75 > 350 ? 350 : screenWidth * 0.75,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(context, '/register');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9890F7),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: padding),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(padding * 2),
                                ),
                              ),
                              child: const Text('Зарегистрироваться', style: TextStyle(fontSize: 18)),
                            ),
                          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                          SizedBox(height: padding * 2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
