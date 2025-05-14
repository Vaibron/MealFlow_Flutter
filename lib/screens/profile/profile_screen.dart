import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:logger/logger.dart';
import '../../services/api_auth.dart';
import '../../services/api_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? errorMessage;
  bool isEditing = false;
  bool notificationsEnabled = false;
  String? selectedGender;
  bool _isResendingEmail = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _newPasswordConfirmController = TextEditingController();

  final List<String> genderOptions = ['Мужской', 'Женский', 'Не указан'];
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUserData(forceRefresh: true); // Обновляем при возвращении
    }
  }

  Future<void> _fetchUserData({bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final data = await ApiProfile.getProtectedData(forceRefresh: forceRefresh);
      setState(() {
        userData = data;
        _emailController.text = userData?['email'] ?? '';
        selectedGender = userData?['gender'] ?? 'Не указан';
        notificationsEnabled = userData?['notifications_enabled'] ?? false;
        isLoading = false;
      });
      _logger.i('Данные пользователя загружены: ${userData?['username']} - is_verified: ${userData?['is_verified']}');
    } catch (e) {
      _logger.e('Ошибка загрузки данных: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Ошибка загрузки данных';
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => isLoading = true);
    try {
      final updatedData = await ApiProfile.updateProfile(
        email: _emailController.text,
        gender: selectedGender,
        notificationsEnabled: notificationsEnabled,
      );
      setState(() {
        userData = updatedData;
        isEditing = false;
        isLoading = false;
      });
      _logger.i('Профиль обновлен: ${_emailController.text}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Профиль обновлен'),
          backgroundColor: Color(0xFF7C73F1),
        ),
      );
    } catch (e) {
      _logger.e('Ошибка обновления профиля: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _changePassword() async {
    setState(() => isLoading = true);
    try {
      await ApiProfile.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        newPasswordConfirm: _newPasswordConfirmController.text,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _newPasswordConfirmController.clear();
      setState(() => isLoading = false);
      _logger.i('Пароль успешно изменен');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароль изменен'),
          backgroundColor: Color(0xFF7C73F1),
        ),
      );
    } catch (e) {
      _logger.e('Ошибка смены пароля: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isResendingEmail = true);
    try {
      await ApiProfile.resendVerificationEmail();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Письмо с подтверждением отправлено'),
          backgroundColor: Color(0xFF7C73F1),
        ),
      );
      _fetchUserData(forceRefresh: true);
    } catch (e) {
      String errorMessage = 'Ошибка: $e';
      if (e.toString().contains('status code of 400')) {
        errorMessage = 'Email уже подтвержден или запрос некорректен';
        _fetchUserData(forceRefresh: true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isResendingEmail = false);
    }
  }

  void _logout(BuildContext context) {
    ApiAuth.logout();
    Navigator.pushReplacementNamed(context, '/login');
    _logger.i('Пользователь вышел из системы');
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить аккаунт'),
        content: const Text('Вы уверены? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() => isLoading = true);
      try {
        await ApiProfile.deleteUser();
        Navigator.pushReplacementNamed(context, '/login');
        _logger.i('Аккаунт удален');
      } catch (e) {
        _logger.e('Ошибка удаления аккаунта: $e');
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _newPasswordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C73F1)),
          ),
        ).animate().scale(duration: 600.ms)
            : errorMessage != null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 16))
                  .animate()
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _fetchUserData(forceRefresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C73F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Повторить'),
              ).animate().scale(duration: 600.ms),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: () async {
            await _fetchUserData(forceRefresh: true);
          },
          color: const Color(0xFF7C73F1), // Цвет индикатора
          backgroundColor: Colors.white, // Фон индикатора
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF7C73F1),
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
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: Text(
                              userData?['username']?.substring(0, 1).toUpperCase() ?? 'U',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C73F1),
                              ),
                            ),
                          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                          const SizedBox(height: 12),
                          Text(
                            userData?['username'] ?? 'Пользователь',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileCard(),
                      const SizedBox(height: 16),
                      _buildPasswordChangeCard(),
                      const SizedBox(height: 16),
                      _buildActionButtons(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final isVerified = userData?['is_verified'] ?? false;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Личные данные',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              enabled: isEditing,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isVerified ? 'Email подтверждён' : 'Email не подтверждён',
                  style: TextStyle(
                    color: isVerified ? Colors.green : Colors.redAccent,
                    fontSize: 14,
                  ),
                ),
                if (!isVerified)
                  TextButton(
                    onPressed: _isResendingEmail ? null : _resendVerificationEmail,
                    child: _isResendingEmail
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C73F1)),
                    )
                        : const Text('Отправить снова', style: TextStyle(color: Color(0xFF7C73F1))),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              value: selectedGender,
              items: genderOptions,
              label: 'Пол',
              onChanged: isEditing ? (value) => setState(() => selectedGender = value) : null,
            ),
            const SizedBox(height: 12),
            _buildSwitchTile(
              title: 'Уведомления',
              value: notificationsEnabled,
              onChanged: isEditing ? (value) => setState(() => notificationsEnabled = value) : null,
            ),
            const SizedBox(height: 16),
            _buildButton(
              text: isEditing ? 'Сохранить' : 'Изменить',
              onPressed: isEditing ? _updateProfile : () => setState(() => isEditing = true),
              color: const Color(0xFF7C73F1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordChangeCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Смена пароля',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _currentPasswordController,
              label: 'Текущий пароль',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _newPasswordController,
              label: 'Новый пароль',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _newPasswordConfirmController,
              label: 'Подтвердите пароль',
              obscureText: true,
            ),
            const SizedBox(height: 16),
            _buildButton(
              text: 'Сменить пароль',
              onPressed: _changePassword,
              color: const Color(0xFF7C73F1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _buildButton(
          text: 'Выйти',
          onPressed: () => _logout(context),
          color: Colors.grey[800] ?? Colors.grey,
        ),
        const SizedBox(height: 12),
        _buildButton(
          text: 'Удалить аккаунт',
          onPressed: () => _deleteAccount(context),
          color: Colors.redAccent,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7C73F1), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required void Function(String?)? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7C73F1), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required void Function(bool)? onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, color: Color(0xFF2D2D2D))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF7C73F1),
          activeTrackColor: const Color(0xFF9B93F7).withOpacity(0.5),
          inactiveThumbColor: Colors.grey[400],
          inactiveTrackColor: Colors.grey[200],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack);
  }
}
