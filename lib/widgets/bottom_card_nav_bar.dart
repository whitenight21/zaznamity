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

  @override
  Widget build(BuildContext context) {
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
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(context, effectiveLeft[0]),
            const SizedBox(width: 4),
            _buildNavItem(context, effectiveLeft[1]),
            const SizedBox(width: 4),
            _buildNavItem(context, effectiveLeft[2]),
            const SizedBox(width: 6),

            // Center Icon: Zaznamity Logo Button
            GestureDetector(
              onTap: onQuickAdd,
              child: Container(
                width: 36,
                height: 36,
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

            _buildNavItem(context, effectiveRight[0]),
            const SizedBox(width: 4),
            _buildNavItem(context, effectiveRight[1]),
            const SizedBox(width: 4),
            _buildNavItem(context, effectiveRight[2]),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String itemKey) {
    if (itemKey == 'manager') {
      return IconButton(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.layers_outlined, color: Colors.white70, size: 20),
        onPressed: onOpenManager,
        tooltip: 'Cards Stack Manager',
      );
    }
    if (itemKey == 'settings') {
      return IconButton(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
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
      case 'income_expenses_labels':
        iconData = Icons.bar_chart_outlined;
        tooltip = 'Label Analytics';
        break;
      case 'trend_chart':
        iconData = Icons.show_chart_outlined;
        tooltip = 'Liquid Trend';
        break;
      case 'transfer':
        iconData = Icons.swap_horiz_outlined;
        tooltip = 'Transfer Funds';
        break;
      case 'new_entry':
        iconData = Icons.add_circle_outline;
        tooltip = 'New Zaznam';
        break;
      default:
        iconData = Icons.widgets_outlined;
        break;
    }

    return IconButton(
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      icon: Icon(iconData, color: iconColor, size: 20),
      onPressed: () {
        if (!cardConfig.isVisible) {
          onToggleVisibility(cardConfig);
        }
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final targetContext = cardConfig.key.currentContext;
            if (targetContext != null) {
              Scrollable.ensureVisible(
                targetContext,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          });
        });
      },
      tooltip: tooltip,
    );
  }
}