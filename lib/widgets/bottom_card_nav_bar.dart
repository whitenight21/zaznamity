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
    this.leftItems = const ['metrics', 'budget'],
    this.rightItems = const ['history', 'settings'],
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
    // Handle special non-card navigation targets first
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

    // Handle dynamic cards based on their ID
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
      case 'budget':
        iconData = Icons.pie_chart_outline;
        iconColor = Colors.white70;
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          // Left Slot 1
          if (leftItems.isNotEmpty) _buildNavItem(context, leftItems[0]),
          const SizedBox(width: 4),

          // Left Slot 2
          if (leftItems.length > 1) _buildNavItem(context, leftItems[1]),
          const SizedBox(width: 4),

          // Center Icon: Always New Zaznam logo
          GestureDetector(
            onTap: onQuickAdd,
            child: Container(
              width: 42,
              height: 42,
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
          const SizedBox(width: 4),

          // Right Slot 1
          if (rightItems.isNotEmpty) _buildNavItem(context, rightItems[0]),
          const SizedBox(width: 4),

          // Right Slot 2
          if (rightItems.length > 1) _buildNavItem(context, rightItems[1]),
        ],
      ),
    );
  }
}