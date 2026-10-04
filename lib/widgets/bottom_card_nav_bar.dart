import 'package:flutter/material.dart';
import '../models/card_config.dart';

class BottomCardNavBar extends StatelessWidget {
  final List<CardConfig> cards;
  final VoidCallback onOpenManager;
  final VoidCallback onQuickAdd;
  final VoidCallback onOpenSettings;
  final Function(CardConfig card) onToggleVisibility;
  final List<String> leftItems;
  final List<String> rightItems;

  const BottomCardNavBar({
    super.key,
    required this.cards,
    required this.onOpenManager,
    required this.onQuickAdd,
    required this.onOpenSettings,
    required this.onToggleVisibility,
    this.leftItems = const ['settings', 'metrics', 'budget'],
    this.rightItems = const ['history', 'calendar', 'manager'],
  });

  void _scrollToCard(BuildContext context, GlobalKey key, String cardId) {
    final cardConfig = cards.firstWhere((c) => c.id == cardId, orElse: () => cards.first);
    
    if (!cardConfig.isVisible) {
      onToggleVisibility(cardConfig);
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = key.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Widget _buildNavItem(BuildContext context, String itemKey) {
    if (itemKey == 'manager') {
      return IconButton(
        icon: const Icon(Icons.layers_outlined, color: Colors.white70, size: 22),
        onPressed: onOpenManager,
        tooltip: 'Cards Stack Manager',
      );
    }
    if (itemKey == 'settings') {
      return IconButton(
        icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 22),
        onPressed: onOpenSettings,
        tooltip: 'Settings',
      );
    }

    final cardConfig = cards.firstWhere(
      (c) => c.id == itemKey,
      orElse: () => cards.first,
    );

    IconData iconData;
    Color iconColor = Colors.white70;
    String tooltip = cardConfig.id.toUpperCase();

    switch (cardConfig.id) {
      case 'metrics':
        iconData = Icons.dashboard_outlined;
        tooltip = 'Metrics Overview';
        break;
      case 'future_metrics':
        iconData = Icons.trending_up_outlined;
        tooltip = 'Future Metrics';
        break;
      case 'budget':
        iconData = Icons.pie_chart_outline;
        tooltip = 'Budget Progress';
        break;
      case 'history':
        iconData = Icons.receipt_long_outlined;
        tooltip = 'Transaction History';
        break;
      case 'calendar':
        iconData = Icons.calendar_month_outlined;
        tooltip = 'Calendar';
        break;
      case 'labels_analytics':
        iconData = Icons.bar_chart_outlined;
        tooltip = 'Label Analytics';
        break;
      case 'liquid_trend':
        iconData = Icons.show_chart_outlined;
        tooltip = 'Liquid Trend';
        break;
      case 'transfer':
        iconData = Icons.swap_horiz_outlined;
        tooltip = 'Transfer Funds';
        break;
      default:
        iconData = Icons.widgets_outlined;
        break;
    }

    return IconButton(
      icon: Icon(iconData, color: iconColor, size: 22),
      onPressed: () => _scrollToCard(context, cardConfig.key, cardConfig.id),
      tooltip: tooltip,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Enforce locked items: Settings is strictly leftmost (leftItems[0]), Manager is strictly rightmost (rightItems[2])
    final effectiveLeft = [
      'settings',
      if (leftItems.length > 1 && leftItems[1] != 'settings' && leftItems[1] != 'manager') leftItems[1] else 'metrics',
      if (leftItems.length > 2 && leftItems[2] != 'settings' && leftItems[2] != 'manager') leftItems[2] else 'budget',
    ];

    final effectiveRight = [
      if (rightItems.isNotEmpty && rightItems[0] != 'manager' && rightItems[0] != 'settings') rightItems[0] else 'history',
      if (rightItems.length > 1 && rightItems[1] != 'manager' && rightItems[1] != 'settings') rightItems[1] else 'calendar',
      'manager',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1333).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Left Slots (3 items)
          _buildNavItem(context, effectiveLeft[0]), // Locked Settings
          const SizedBox(width: 2),
          _buildNavItem(context, effectiveLeft[1]),
          const SizedBox(width: 2),
          _buildNavItem(context, effectiveLeft[2]),
          const SizedBox(width: 6),

          // Center Icon: New Zaznam logo
          GestureDetector(
            onTap: onQuickAdd,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/ZaznamityLogoFULL.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Right Slots (3 items)
          _buildNavItem(context, effectiveRight[0]),
          const SizedBox(width: 2),
          _buildNavItem(context, effectiveRight[1]),
          const SizedBox(width: 2),
          _buildNavItem(context, effectiveRight[2]), // Locked Manager
        ],
      ),
    );
  }
}