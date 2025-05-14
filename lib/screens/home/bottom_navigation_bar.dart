import 'package:flutter/material.dart';

// Модель для элементов навигации
class NavItem {
  final IconData icon;
  final String label;

  NavItem({required this.icon, required this.label});
}

class CustomBottomNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final bool isEmailVerified;

  const CustomBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.isEmailVerified,
  });

  @override
  _CustomBottomNavigationBarState createState() => _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _collapseAnimation;
  late Animation<double> _fadeAnimation;
  int? _previousIndex;

  // Список элементов навигации
  final List<NavItem> _navItems = [
    NavItem(icon: Icons.menu_book, label: 'Меню'),
    NavItem(icon: Icons.book, label: 'Рецепты'),
    NavItem(icon: Icons.home, label: 'Главная'),
    NavItem(icon: Icons.article, label: 'Статьи'),
    NavItem(icon: Icons.settings, label: 'Профиль'),
  ];

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.selectedIndex;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutQuad),
    );
    _collapseAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutQuad),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutQuad),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    if (!widget.isEmailVerified && index != 4) {
      _showVerificationDialog();
      return;
    }
    setState(() {
      _previousIndex = widget.selectedIndex;
      widget.onItemTapped(index);
    });
    _animationController.forward(from: 0.0);
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Подтвердите email'),
        content: const Text('Пожалуйста, подтвердите ваш email, чтобы получить доступ ко всем функциям приложения.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onItemTapped(4); // Переход на профиль
              _animationController.forward(from: 0.0);
            },
            child: const Text('Перейти в профиль', style: TextStyle(color: Color(0xFF7C73F1))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxItemWidth = screenWidth / 5.5;

    return Container(
      height: 80,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_navItems.length, (index) {
          return _buildNavItem(
            icon: _navItems[index].icon,
            label: _navItems[index].label,
            index: index,
            isSelected: widget.selectedIndex == index,
            isPrevious: _previousIndex == index,
            maxItemWidth: maxItemWidth,
          );
        }),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
    required bool isPrevious,
    required double maxItemWidth,
  }) {
    return GestureDetector(
      onTap: () => _handleTap(index),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          double animationValue;

          if (isSelected) {
            animationValue = _expandAnimation.value;
          } else if (isPrevious && _animationController.isAnimating) {
            animationValue = _collapseAnimation.value;
          } else {
            animationValue = 0.0;
          }

          return Container(
            constraints: BoxConstraints(
              maxWidth: maxItemWidth * (0.8 + animationValue),
            ),
            padding: EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 8 + (8 * animationValue),
            ),
            decoration: BoxDecoration(
              color: (isSelected || (isPrevious && _animationController.isAnimating))
                  ? const Color(0xFF9890F7)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: (isSelected || (isPrevious && _animationController.isAnimating))
                      ? Colors.white
                      : Colors.grey,
                  size: 32,
                ),
                if ((isSelected && animationValue > 0) || (isPrevious && animationValue > 0)) ...[
                  SizedBox(width: 4 + (4 * animationValue)),
                  Flexible(
                    child: FadeTransition(
                      opacity: isSelected ? _fadeAnimation : _collapseAnimation,
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
