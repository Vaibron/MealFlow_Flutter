import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:logger/logger.dart';
import '../../services/api_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageController = PageController();
  final _scrollController = ScrollController();
  int _currentPage = 0;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _birthDateController = TextEditingController();
  String? _selectedGender;
  bool _notificationsEnabled = false;

  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _passwordConfirmError;
  String? _birthDateError;

  bool _isCheckingEmail = false;
  bool _isLoading = false;

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _passwordConfirmFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _birthDateFocus = FocusNode();

  final Logger _logger = Logger();

  Future<bool> _checkEmail(String email) async {
    if (_isCheckingEmail) {
      _logger.d('Проверка email уже выполняется, пропускаем: $email');
      return false;
    }

    setState(() {
      _isCheckingEmail = true;
      _emailError = null;
    });

    try {
      if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
        setState(() {
          _emailError = 'Введите корректный email';
        });
        return false;
      }

      final result = await ApiAuth.checkEmail(email);
      if (result['exists'] == true) {
        setState(() {
          _emailError = result['message'];
        });
        return false;
      } else {
        setState(() {
          _emailError = null;
        });
        return true;
      }
    } catch (e) {
      _logger.e('Ошибка проверки email: $e');
      setState(() {
        _emailError = 'Ошибка проверки email';
      });
      return false;
    } finally {
      setState(() {
        _isCheckingEmail = false;
      });
    }
  }

  Future<bool> _validateFirstStep() async {
    bool isValid = true;
    setState(() {
      _emailError = null;
      _passwordError = null;
      _passwordConfirmError = null;

      final emailPattern = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailPattern.hasMatch(_emailController.text.trim())) {
        _emailError = 'Введите корректный email';
        isValid = false;
      }

      if (_passwordController.text.trim().length < 8) {
        _passwordError = 'Пароль должен быть минимум 8 символов';
        isValid = false;
      }

      if (_passwordConfirmController.text.trim() != _passwordController.text.trim()) {
        _passwordConfirmError = 'Пароли не совпадают';
        isValid = false;
      }
    });

    if (isValid) {
      isValid = await _checkEmail(_emailController.text.trim());
    }

    return isValid;
  }

  bool _validateSecondStep() {
    bool isValid = true;
    setState(() {
      _usernameError = null;
      _birthDateError = null;

      if (_usernameController.text.trim().length < 3) {
        _usernameError = 'Имя пользователя должно содержать минимум 3 символа';
        isValid = false;
      }

      if (_birthDateController.text.trim().isEmpty) {
        _birthDateError = 'Введите дату рождения';
        isValid = false;
      } else {
        try {
          final date = DateFormat('dd.MM.yyyy').parseStrict(_birthDateController.text.trim());
          if (date.isAfter(DateTime.now())) {
            _birthDateError = 'Дата рождения не может быть в будущем';
            isValid = false;
          }
          if (date.isBefore(DateTime(1900))) {
            _birthDateError = 'Дата рождения не может быть раньше 1900 года';
            isValid = false;
          }
        } catch (e) {
          _birthDateError = 'Введите дату в формате дд.мм.гггг';
          isValid = false;
        }
      }
    });
    return isValid;
  }

  Future<void> _nextPage() async {
    FocusScope.of(context).unfocus();

    if (_currentPage == 0) {
      bool isValid = await _validateFirstStep();
      if (!isValid) return;
    }
    if (_currentPage == 1 && !_validateSecondStep()) return;

    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _register();
    }
  }

  void _previousPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _register() async {
    setState(() => _isLoading = true);
    try {
      String? genderToSend = _selectedGender == 'male'
          ? 'Мужской'
          : _selectedGender == 'female'
          ? 'Женский'
          : 'Не указан';

      await ApiAuth.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        passwordConfirm: _passwordConfirmController.text.trim(),
        birthDate: _birthDateController.text.trim(),
        gender: genderToSend,
        notificationsEnabled: _notificationsEnabled,
      );
      _logger.i('Успешная регистрация: ${_emailController.text}');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _logger.e('Ошибка регистрации: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка регистрации: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
        _pageController.jumpToPage(0);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ru', 'RU'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7C73F1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  void _scrollToField(FocusNode focusNode) {
    if (focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        Scrollable.ensureVisible(
          focusNode.context!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _birthDateController.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _passwordConfirmFocus.dispose();
    _usernameFocus.dispose();
    _birthDateFocus.dispose();
    super.dispose();
  }

  Widget _buildWelcomeText(double fontSize) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Добро пожаловать\n',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D2D2D),
            ),
          ),
          TextSpan(
            text: 'в Meal',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D2D2D),
            ),
          ),
          TextSpan(
            text: 'Flow',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF7C73F1),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Future<bool> _onWillPop() async {
    if (_currentPage > 0) {
      _previousPage();
      return false;
    } else {
      Navigator.pushReplacementNamed(context, '/welcome');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth * 0.04;
    final maxTextFieldWidth = 400.0;
    final maxButtonWidth = 300.0;
    final maxLogoWidth = 300.0;
    final maxTextWidth = 500.0;
    final iconSize = screenWidth * 0.1;

    final logoSize = screenWidth < maxLogoWidth ? screenWidth * 0.6 : maxLogoWidth;
    final textSize = screenWidth * 0.09 > 36.0 ? 36.0 : screenWidth * 0.09;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF5F5F5), Colors.white],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: padding),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: padding / 2),
                          width: _currentPage == index ? padding * 3 : padding,
                          height: padding / 2,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? const Color(0xFF7C73F1) : Colors.grey[300],
                            borderRadius: BorderRadius.circular(padding / 2),
                          ),
                        ).animate().scale(duration: 400.ms, curve: Curves.easeInOut);
                      }),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      children: [
                        // First Page (Email и пароль)
                        SingleChildScrollView(
                          controller: _scrollController,
                          child: Padding(
                            padding: EdgeInsets.all(padding * 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(height: padding * 2),
                                Image.asset(
                                  'assets/book_logo.png',
                                  height: logoSize,
                                  width: logoSize,
                                  fit: BoxFit.contain,
                                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                                SizedBox(height: padding * 3),
                                const Text(
                                  'Введите ваш email и пароль',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                  textAlign: TextAlign.center,
                                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                                SizedBox(height: padding * 2),
                                SizedBox(
                                  width: screenWidth * 0.9 > maxTextFieldWidth
                                      ? maxTextFieldWidth
                                      : screenWidth * 0.9,
                                  child: TextField(
                                    controller: _emailController,
                                    focusNode: _emailFocus,
                                    decoration: InputDecoration(
                                      labelText: 'Введите ваш email',
                                      labelStyle: TextStyle(color: Colors.grey[600]),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      errorText: _emailError,
                                      suffixIcon: _isCheckingEmail
                                          ? Padding(
                                        padding: EdgeInsets.all(padding / 2),
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C73F1)),
                                        ),
                                      )
                                          : null,
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    onChanged: (value) => _checkEmail(value.trim()),
                                    onTap: () => _scrollToField(_emailFocus),
                                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                                ),
                                SizedBox(height: padding),
                                SizedBox(
                                  width: screenWidth * 0.9 > maxTextFieldWidth
                                      ? maxTextFieldWidth
                                      : screenWidth * 0.9,
                                  child: TextField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocus,
                                    decoration: InputDecoration(
                                      labelText: 'Введите пароль',
                                      labelStyle: TextStyle(color: Colors.grey[600]),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      errorText: _passwordError,
                                    ),
                                    obscureText: true,
                                    onTap: () => _scrollToField(_passwordFocus),
                                  ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                                ),
                                SizedBox(height: padding),
                                SizedBox(
                                  width: screenWidth * 0.9 > maxTextFieldWidth
                                      ? maxTextFieldWidth
                                      : screenWidth * 0.9,
                                  child: TextField(
                                    controller: _passwordConfirmController,
                                    focusNode: _passwordConfirmFocus,
                                    decoration: InputDecoration(
                                      labelText: 'Подтвердите пароль',
                                      labelStyle: TextStyle(color: Colors.grey[600]),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      errorText: _passwordConfirmError,
                                    ),
                                    obscureText: true,
                                    onTap: () => _scrollToField(_passwordConfirmFocus),
                                  ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                                ),
                                SizedBox(height: padding * 3),
                                SizedBox(
                                  width: screenWidth * 0.75 > maxButtonWidth
                                      ? maxButtonWidth
                                      : screenWidth * 0.75,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _nextPage,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7C73F1),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 4,
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
                                        : const Text(
                                      'Далее',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                              ],
                            ),
                          ),
                        ),
                        // Second Page (Имя и дата рождения)
                        SingleChildScrollView(
                          controller: _scrollController,
                          child: Padding(
                            padding: EdgeInsets.all(padding * 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(height: padding * 2),
                                Container(
                                  constraints: BoxConstraints(maxWidth: maxTextWidth),
                                  child: _buildWelcomeText(textSize),
                                ),
                                SizedBox(height: padding * 2),
                                const Text(
                                  'Укажите ваше имя и дату рождения',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                  textAlign: TextAlign.center,
                                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                                SizedBox(height: padding * 2),
                                SizedBox(
                                  width: screenWidth * 0.9 > maxTextFieldWidth
                                      ? maxTextFieldWidth
                                      : screenWidth * 0.9,
                                  child: TextField(
                                    controller: _usernameController,
                                    focusNode: _usernameFocus,
                                    decoration: InputDecoration(
                                      labelText: 'Введите ваше имя пользователя',
                                      labelStyle: TextStyle(color: Colors.grey[600]),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      errorText: _usernameError,
                                    ),
                                    onTap: () => _scrollToField(_usernameFocus),
                                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                                ),
                                SizedBox(height: padding),
                                SizedBox(
                                  width: screenWidth * 0.9 > maxTextFieldWidth
                                      ? maxTextFieldWidth
                                      : screenWidth * 0.9,
                                  child: TextField(
                                    controller: _birthDateController,
                                    focusNode: _birthDateFocus,
                                    decoration: InputDecoration(
                                      labelText: 'Введите дату рождения (дд.мм.гггг)',
                                      labelStyle: TextStyle(color: Colors.grey[600]),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      errorText: _birthDateError,
                                      suffixIcon: IconButton(
                                        icon: Icon(Icons.calendar_today, size: iconSize, color: Colors.grey[600]),
                                        onPressed: () => _selectDate(context),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(10),
                                      DateInputFormatter(),
                                    ],
                                    onTap: () => _scrollToField(_birthDateFocus),
                                  ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                                ),
                                SizedBox(height: padding * 3),
                                SizedBox(
                                  width: screenWidth * 0.75 > maxButtonWidth
                                      ? maxButtonWidth
                                      : screenWidth * 0.75,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _nextPage,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7C73F1),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 4,
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
                                        : const Text(
                                      'Далее',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                              ],
                            ),
                          ),
                        ),
                        // Third Page (Пол с картинками)
                        SingleChildScrollView(
                          controller: _scrollController,
                          child: Padding(
                            padding: EdgeInsets.all(padding * 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(height: padding * 2),
                                Container(
                                  constraints: BoxConstraints(maxWidth: maxTextWidth),
                                  child: _buildWelcomeText(textSize),
                                ),
                                SizedBox(height: padding * 2),
                                const Text(
                                  'Укажите ваш пол',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                  textAlign: TextAlign.center,
                                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                                SizedBox(height: padding * 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedGender = 'male';
                                          });
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: _selectedGender == 'male'
                                                  ? const Color(0xFF7C73F1)
                                                  : Colors.grey[300]!,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              if (_selectedGender == 'male')
                                                BoxShadow(
                                                  color: const Color(0xFF7C73F1).withOpacity(0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(14),
                                            child: Image.asset(
                                              _selectedGender == 'male'
                                                  ? 'assets/male_active.png'
                                                  : 'assets/male_inactive.png',
                                              width: double.infinity,
                                              height: ((screenWidth - padding * 5) / 2) * 1.8 * (4 / 3),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ).animate().scale(delay: 300.ms, duration: 400.ms),
                                    ),
                                    SizedBox(width: padding),
                                    Expanded(
                                      flex: 1,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedGender = 'female';
                                          });
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: _selectedGender == 'female'
                                                  ? const Color(0xFF7C73F1)
                                                  : Colors.grey[300]!,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              if (_selectedGender == 'female')
                                                BoxShadow(
                                                  color: const Color(0xFF7C73F1).withOpacity(0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(14),
                                            child: Image.asset(
                                              _selectedGender == 'female'
                                                  ? 'assets/female_active.png'
                                                  : 'assets/female_inactive.png',
                                              width: double.infinity,
                                              height: ((screenWidth - padding * 5) / 2) * 1.8 * (4 / 3),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ).animate().scale(delay: 400.ms, duration: 400.ms),
                                    ),
                                  ],
                                ),
                                SizedBox(height: padding * 2),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedGender = null;
                                    });
                                    _nextPage();
                                  },
                                  child: Text(
                                    'Не хочу указывать',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                                SizedBox(height: padding * 2),
                                SizedBox(
                                  width: screenWidth * 0.75 > maxButtonWidth
                                      ? maxButtonWidth
                                      : screenWidth * 0.75,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _nextPage,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7C73F1),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 4,
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
                                        : const Text(
                                      'Далее',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                              ],
                            ),
                          ),
                        ),
                        // Fourth Page (Уведомления)
                        SingleChildScrollView(
                          controller: _scrollController,
                          child: Padding(
                            padding: EdgeInsets.all(padding * 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(height: padding * 2),
                                Container(
                                  constraints: BoxConstraints(maxWidth: maxTextWidth),
                                  child: _buildWelcomeText(textSize),
                                ),
                                SizedBox(height: padding * 2),
                                const Text(
                                  'Включите уведомления, чтобы не пропустить ничего важного',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                  textAlign: TextAlign.center,
                                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                                SizedBox(height: padding * 2),
                                Icon(
                                  Icons.notifications,
                                  size: iconSize * 1.5,
                                  color: _notificationsEnabled ? const Color(0xFF7C73F1) : Colors.grey[400],
                                ).animate().scale(delay: 300.ms, duration: 400.ms),
                                SizedBox(height: padding * 3),
                                SizedBox(
                                  width: screenWidth * 0.75 > maxButtonWidth
                                      ? maxButtonWidth
                                      : screenWidth * 0.75,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                      setState(() {
                                        _notificationsEnabled = true;
                                      });
                                      _register();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7C73F1),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 4,
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
                                        : const Text(
                                      'Разрешить',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ).animate().scale(delay: 400.ms, duration: 600.ms, curve: Curves.easeOutBack),
                                SizedBox(height: padding),
                                TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                    setState(() {
                                      _notificationsEnabled = false;
                                    });
                                    _register();
                                  },
                                  child: Text(
                                    'Не хочу указывать',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                              ],
                            ),
                          ),
                        ),
                      ],
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

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String newText = '';
    int selectionIndex = newValue.selection.start;

    if (text.length >= 1) {
      newText += text.substring(0, text.length >= 2 ? 2 : text.length);
      if (text.length >= 2) newText += '.';
    }
    if (text.length >= 3) {
      newText += text.substring(2, text.length >= 4 ? 4 : text.length);
      if (text.length >= 4) newText += '.';
    }
    if (text.length >= 5) {
      newText += text.substring(4, text.length >= 8 ? 8 : text.length);
    }

    if (newValue.text.length > oldValue.text.length) {
      if (newText.length == 3 || newText.length == 6) selectionIndex++;
    } else if (newValue.text.length < oldValue.text.length) {
      if (newText.length == 2 || newText.length == 5) selectionIndex--;
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}
