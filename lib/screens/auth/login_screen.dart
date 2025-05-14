import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../services/api_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  String? _errorMessage;
  bool _isLoading = false;
  final Logger _logger = Logger();

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        await ApiAuth.login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        _logger.i('Успешный вход: ${_emailController.text}');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        _logger.e('Ошибка входа: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Email или пароль введены неверно';
          });
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<bool> _onWillPop() async {
    Navigator.pushReplacementNamed(context, '/welcome');
    return false;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth * 0.04;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
              Navigator.pushReplacementNamed(context, '/welcome');
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
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: padding * 2),
                            Image.asset(
                              'assets/book_logo.png',
                              height: 300,
                              width: 300,
                              fit: BoxFit.contain,
                            ),
                            SizedBox(height: padding * 2),
                            const Text(
                              'Вход в MealFlow',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: padding),
                            if (_errorMessage != null)
                              Padding(
                                padding: EdgeInsets.only(bottom: padding),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 14),
                                ),
                              ),
                            SizedBox(
                              width: screenWidth * 0.9 > 400 ? 400 : screenWidth * 0.9,
                              child: TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(padding),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(padding),
                                    borderSide: const BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(padding),
                                    borderSide: const BorderSide(color: Color(0xFF9890F7)),
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  value = value?.trim() ?? '';
                                  if (value.isEmpty) return 'Введите email';
                                  final emailPattern = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                  if (!emailPattern.hasMatch(value)) return 'Введите корректный email';
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(height: padding),
                            SizedBox(
                              width: screenWidth * 0.9 > 400 ? 400 : screenWidth * 0.9,
                              child: TextFormField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: 'Пароль',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(padding),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(padding),
                                    borderSide: const BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(padding),
                                    borderSide: const BorderSide(color: Color(0xFF9890F7)),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: !_isPasswordVisible,
                                validator: (value) {
                                  value = value?.trim() ?? '';
                                  if (value.isEmpty) return 'Введите пароль';
                                  if (value.length < 8) return 'Пароль должен быть минимум 8 символов';
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(height: padding),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // TODO: Добавить логику восстановления пароля
                                },
                                child: const Text(
                                  'Забыли пароль?',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                            SizedBox(height: padding * 2),
                            SizedBox(
                              width: screenWidth * 0.75 > 300 ? 300 : screenWidth * 0.75,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9890F7),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: padding),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(padding * 2),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                                    : const Text('Войти', style: TextStyle(fontSize: 18)),
                              ),
                            ),
                            SizedBox(height: padding),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                              child: const Text(
                                'Нет аккаунта? Зарегистрироваться',
                                style: TextStyle(color: Color(0xFF9890F7)),
                              ),
                            ),
                          ],
                        ),
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
