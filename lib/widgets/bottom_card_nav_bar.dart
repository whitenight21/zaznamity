// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../models/card_config.dart';

class BottomCardNavBar extends StatefulWidget {
  final List<CardConfig> cards;
  final VoidCallback onOpenManager;
  final VoidCallback onQuickAdd;
  final VoidCallback onSelectOwner;
  final Function(CardConfig card) onToggleVisibility;
  final Function(String cardId) onNavigateToCard;
  final List<String> leftItems;
  final List<String> rightItems;
  final bool isLandscape;
  final int currentTabIndex;
  final Function(int) onTabSelected;

  const BottomCardNavBar({
    super.key,
    required this.cards,
    required this.onOpenManager,
    required this.onQuickAdd,
    required this.onSelectOwner,
    required this.onToggleVisibility,
    required this.onNavigateToCard,
    this.leftItems = const ['owner', 'metrics', 'budget'],
    this.rightItems = const ['history', 'calendar', 'snapshot'],
    this.isLandscape = false,
    this.currentTabIndex = 0,
    required this.onTabSelected,
  });

  @override
  State<BottomCardNavBar> createState() => _BottomCardNavBarState();
}

class _BottomCardNavBarState extends State<BottomCardNavBar> {
  bool _isHidden = false;

  @override
  Widget build(BuildContext context) {
    final effectiveLeft = [
      'owner',
      if (widget.leftItems.length > 1 && widget.leftItems[1] != 'owner' && widget.leftItems[1] != 'snapshot') widget.leftItems[1] else 'metrics',
      if (widget.leftItems.length > 2 && widget.leftItems[2] != 'owner' && widget.leftItems[2] != 'snapshot') widget.leftItems[2] else 'budget',
    ];

    final effectiveRight = [
      if (widget.rightItems.isNotEmpty && widget.rightItems[0] != 'snapshot' && widget.rightItems[0] != 'owner') widget.rightItems[0] else 'history',
      if (widget.rightItems.length > 1 && widget.rightItems[1] != 'snapshot' && widget.rightItems[1] != 'owner') widget.rightItems[1] else 'calendar',
      'snapshot',
    ];

    final allNavItems = [
      effectiveLeft[0],
      effectiveLeft[1],
      effectiveLeft[2],
      'logo',
      effectiveRight[0],
      effectiveRight[1],
      effectiveRight[2],
    ];

    if (_isHidden) {
      return GestureDetector(
        onTap: () => setState(() => _isHidden = false),
        child: widget.isLandscape
            ? Container(
                width: 12,
                height: double.infinity,
                color: const Color(0xFF1E1333).withValues(alpha: 0.85),
                alignment: Alignment.center,
                child: Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )
            : Container(
                height: 12,
                width: double.infinity,
                color: const Color(0xFF1E1333).withValues(alpha: 0.85),
                alignment: Alignment.center,
                child: Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
      );
    }

    if (widget.isLandscape) {
      return GestureDetector(
        onPanUpdate: (details) {
          if (details.delta.dx < -10) {
            setState(() => _isHidden = true);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(right: 0, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1333).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(4, 0),
              ),
            ],
            border: Border.all(color: Colors.white10),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...allNavItems.map((itemKey) {
                  if (itemKey == 'logo') {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: GestureDetector(
                        onTap: widget.onQuickAdd,
                        child: Container(
                          width: 32,
                          height: 32,
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
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildNavItem(context, itemKey),
                  );
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(color: Colors.white12, height: 1, indent: 4, endIndent: 4),
                ),
                _buildHorizontalTabItem(0, 'Metrics'),
                _buildHorizontalTabItem(1, 'Trends'),
                _buildHorizontalTabItem(2, 'Analytics'),
                _buildTabWithManagerAction(3, 'Actions'),
              ],
            ),
          ),
        ),
      );
    }

    // Portrait / Docked Bottom Standard View
    return GestureDetector(
      onPanUpdate: (details) {
        if (details.delta.dy > 10) {
          setState(() => _isHidden = true);
        }
      },
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1333).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(context, effectiveLeft[0]),
                _buildNavItem(context, effectiveLeft[1]),
                _buildNavItem(context, effectiveLeft[2]),

                // Center Logo Quick-Add Button
                GestureDetector(
                  onTap: widget.onQuickAdd,
                  child: Container(
                    width: 38,
                    height: 38,
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

                _buildNavItem(context, effectiveRight[0]),
                _buildNavItem(context, effectiveRight[1]),
                _buildNavItem(context, effectiveRight[2]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPortraitTabItem(0, 'Metrics'),
                _buildPortraitTabItem(1, 'Trends'),
                _buildPortraitTabItem(2, 'Analytics'),
                _buildTabWithManagerAction(3, 'Actions'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitTabItem(int index, String label) {
    final isSelected = widget.currentTabIndex == index;
    return InkWell(
      onTap: () => widget.onTabSelected(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFA855F7).withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFFA855F7) : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildTabWithManagerAction(int index, String label) {
    final isSelected = widget.currentTabIndex == index;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => widget.onTabSelected(index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFA855F7).withValues(alpha: 0.3) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFFA855F7) : Colors.white70,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.layers_outlined, color: Colors.white70, size: 16),
          onPressed: widget.onOpenManager,
          tooltip: 'Cards Stack Manager',
        ),
      ],
    );
  }

  Widget _buildHorizontalTabItem(int index, String label) {
    final isSelected = widget.currentTabIndex == index;
    return InkWell(
      onTap: () => widget.onTabSelected(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFA855F7).withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFFA855F7) : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String itemKey) {
    if (itemKey == 'snapshot') {
      return IconButton(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.grid_view_rounded, color: Colors.white70, size: 20),
        onPressed: () => widget.onNavigateToCard('snapshot'),
        tooltip: 'Zoom-Out Snapshot',
      );
    }
    if (itemKey == 'owner') {
      return IconButton(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.person_outline, color: Colors.white70, size: 20),
        onPressed: widget.onSelectOwner,
        tooltip: 'Select Owner',
      );
    }

    final cardConfig = widget.cards.firstWhere(
      (c) => c.id == itemKey,
      orElse: () => widget.cards.first,
    );

    IconData iconData;
    const Color iconColor = Colors.white70;
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
      onPressed: () => widget.onNavigateToCard(cardConfig.id),
      tooltip: tooltip,
    );
  }
}