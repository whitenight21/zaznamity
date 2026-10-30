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
  String? _pressedItemKey;
  bool _isHidden = false;

  void _triggerPressEffect(String key) {
    setState(() {
      _pressedItemKey = key;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _pressedItemKey == key) {
        setState(() {
          _pressedItemKey = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // If hidden in portrait mode, show only the small tab handle at the bottom
    if (_isHidden && !widget.isLandscape) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isHidden = false;
            });
          },
          child: Container(
            width: 400,
            height: 20,
            margin: const EdgeInsets.only(bottom: 0),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 82, 35, 126),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      );
    }

    // If hidden in landscape mode, show only the small side tab on the left edge
    if (_isHidden && widget.isLandscape) {
      return Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isHidden = false;
            });
          },
          child: Container(
            width: 20,
            height: 400,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 82, 35, 126),
              borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 4,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.keyboard_arrow_right_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      );
    }

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

    // Horizontal / Landscape View: Rotated 90 degrees and placed on the left edge of the screen
    if (widget.isLandscape) {
      return Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (details.delta.dx < -6) {
              setState(() {
                _isHidden = true;
              });
            }
          },
          child: RotatedBox(
            quarterTurns: 1,
            child: Container(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(16, 1, 16, 1),
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
                      _buildRotatedNavItem(context, effectiveLeft[0]),
                      _buildRotatedNavItem(context, effectiveLeft[1]),
                      _buildRotatedNavItem(context, effectiveLeft[2]),

                      // Center Logo Quick-Add Button with 0.5s Purple Circle Press Effect
                      GestureDetector(
                        onTap: () {
                          _triggerPressEffect('logo');
                          widget.onQuickAdd();
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_pressedItemKey == 'logo')
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFA855F7),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Container(
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
                          ],
                        ),
                      ),

                      _buildRotatedNavItem(context, effectiveRight[0]),
                      _buildRotatedNavItem(context, effectiveRight[1]),
                      _buildRotatedNavItem(context, effectiveRight[2]),
                    ],
                  ),
                  const SizedBox(height: 0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildRotatedPortraitTabItem(0, 'Metrics'),
                      _buildRotatedPortraitTabItem(1, 'Trends'),
                      _buildRotatedPortraitTabItem(2, 'Analytics'),
                      _buildRotatedTabWithManagerAction(3, 'Actions'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Standard Bottom Docked View (Portrait Mode)
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.delta.dy > 6) {
          setState(() {
            _isHidden = true;
          });
        }
      },
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(16, 1, 16, 1),
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

                // Center Logo Quick-Add Button with 0.5s Purple Circle Press Effect
                GestureDetector(
                  onTap: () {
                    _triggerPressEffect('logo');
                    widget.onQuickAdd();
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_pressedItemKey == 'logo')
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFA855F7),
                            shape: BoxShape.circle,
                          ),
                        ),
                      Container(
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
                    ],
                  ),
                ),

                _buildNavItem(context, effectiveRight[0]),
                _buildNavItem(context, effectiveRight[1]),
                _buildNavItem(context, effectiveRight[2]),
              ],
            ),
            const SizedBox(height: 0),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFA855F7).withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildRotatedPortraitTabItem(int index, String label) {
    return RotatedBox(
      quarterTurns: 3,
      child: _buildPortraitTabItem(index, label),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFA855F7).withValues(alpha: 0.3) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.white70,
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

  Widget _buildRotatedTabWithManagerAction(int index, String label) {
    return RotatedBox(
      quarterTurns: 3,
      child: _buildTabWithManagerAction(index, label),
    );
  }

  Widget _buildNavItem(BuildContext context, String itemKey) {
    if (itemKey == 'snapshot') {
      return Stack(
        alignment: Alignment.center,
        children: [
          if (_pressedItemKey == 'snapshot')
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 82, 35, 126),
                shape: BoxShape.circle,
              ),
            ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.grid_view_rounded, color: Colors.white70, size: 20),
            onPressed: () {
              _triggerPressEffect('snapshot');
              widget.onNavigateToCard('snapshot');
            },
            tooltip: 'Zoom-Out Snapshot',
          ),
        ],
      );
    }
    if (itemKey == 'owner') {
      return Stack(
        alignment: Alignment.center,
        children: [
          if (_pressedItemKey == 'owner')
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 82, 35, 126),
                shape: BoxShape.circle,
              ),
            ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.person_outline, color: Colors.white70, size: 20),
            onPressed: () {
              _triggerPressEffect('owner');
              widget.onSelectOwner();
            },
            tooltip: 'Select Owner',
          ),
        ],
      );
    }

    final cardConfig = widget.cards.firstWhere(
      (c) => c.id == itemKey,
      orElse: () => widget.cards.first,
    );

    IconData iconData;
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
      case 'liabilities_card':
        iconData = Icons.account_balance_wallet_outlined;
        tooltip = 'Liabilities & Loans';
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

    return Stack(
      alignment: Alignment.center,
      children: [
        if (_pressedItemKey == cardConfig.id)
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 82, 35, 126),
              shape: BoxShape.circle,
            ),
          ),
        IconButton(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          icon: Icon(iconData, color: Colors.white70, size: 20),
          onPressed: () {
            _triggerPressEffect(cardConfig.id);
            widget.onNavigateToCard(cardConfig.id);
          },
          tooltip: tooltip,
        ),
      ],
    );
  }

  Widget _buildRotatedNavItem(BuildContext context, String itemKey) {
    return RotatedBox(
      quarterTurns: 3,
      child: _buildNavItem(context, itemKey),
    );
  }
}