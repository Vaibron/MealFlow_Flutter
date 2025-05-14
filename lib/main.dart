import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Добавляем для анимаций
import 'package:mealflow_app/screens/auth/login_screen.dart';
import 'package:mealflow_app/screens/auth/register_screen.dart';
import 'package:mealflow_app/screens/home/home_screen.dart';
import 'package:mealflow_app/screens/auth/welcome_screen.dart';
import 'package:mealflow_app/services/api_auth.dart'; // Используем ApiAuth вместо ApiService

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mealflow App',
      theme: ThemeData(
        primaryColor: const Color(0xFF7C73F1),
        // Обновляем основной цвет в стиле RecipesScreen
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: createMaterialColor(const Color(0xFF7C73F1)),
          accentColor: const Color(0xFF9B93F7),
          backgroundColor: Colors.white,
          errorColor: Colors.redAccent,
        ).copyWith(
          surface: const Color(0xFFF5F5F5),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C73F1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: const Color(0xFF7C73F1).withOpacity(0.4),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2D2D),
          ),
          bodyMedium: TextStyle(
            fontSize: 16,
            color: Color(0xFF2D2D2D),
          ),
          labelMedium: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ru', 'RU'),
      home: const AuthCheck(),
      routes: {
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/welcome': (context) => const WelcomeScreen(),
      },
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  _AuthCheckState createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final isAuthenticated =
          await ApiAuth.isAuthenticated(); // Используем ApiAuth
      setState(() {
        _isAuthenticated = isAuthenticated;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка в AuthCheck: $e');
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF5F5F5), Colors.white],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF7C73F1)),
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 16),
                const Text(
                  'Загрузка...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D2D2D),
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      );
    }

    return _isAuthenticated ? const HomeScreen() : const WelcomeScreen();
  }
}

// Вспомогательная функция для создания MaterialColor из Color
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}
