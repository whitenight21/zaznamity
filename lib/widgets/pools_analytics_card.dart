// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';

class PoolsAnalyticsCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final Map<String, bool> pools;
  final List<String> owners;
  final String? selectedOwner;
  final Function(String?) onOwnerChanged;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final VoidCallback onClearDateFilter;

  const PoolsAnalyticsCard({
    super.key,
    required this.transactions,
    required this.pools,
    required this.owners,
    required this.selectedOwner,
    required this.onOwnerChanged,
    required this.startDate,
    required this.endDate,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onClearDateFilter,
  });

  @override
  State<PoolsAnalyticsCard> createState() => _PoolsAnalyticsCardState();
}

class _PoolsAnalyticsCardState extends State<PoolsAnalyticsCard> {
  late Map<String, bool> _visiblePools;
  String _primaryCurrency = 'USD';
  String _dateRangeSetting = '30 Days';
  bool _showOnlyFunded = false;
  bool _showFuture = false;
  bool _isZaznamityMode = true;
  bool _isCollapsed = false;
  bool _viewAsPercentage = false; // Secondary toggle for Net Worth Share Breakdown

  @override
  void initState() {
    super.initState();
    _visiblePools = {
      for (var key in widget.pools.keys) key: true,
    };
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final collapsed = prefs.getBool('set_poolsAnalytics_collapsed') ?? false;
    final viewPct = prefs.getBool('set_poolsAnalytics_view_pct') ?? false;

    setState(() {
      _primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';
      _dateRangeSetting = prefs.getString('set_poolsTrends_range') ?? '30 Days';
      _showOnlyFunded = prefs.getBool('set_poolsTrends_funded_only') ?? false;
      _showFuture = prefs.getBool('set_poolsTrends_show_future') ?? false;
      _isZaznamityMode = (savedTheme == 'zaznamity');
      _isCollapsed = collapsed;
      _viewAsPercentage = viewPct;

      for (var key in widget.pools.keys) {
        _visiblePools[key] = prefs.getBool('set_poolsTrends_pool_visible_$key') ?? true;
      }
    });
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_poolsAnalytics_collapsed', _isCollapsed);
  }

  Future<void> _toggleViewAsPercentage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _viewAsPercentage = !_viewAsPercentage;
    });
    await prefs.setBool('set_poolsAnalytics_view_pct', _viewAsPercentage);
  }

  Future<void> _toggleShowFuture() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showFuture = !_showFuture;
    });
    await prefs.setBool('set_poolsTrends_show_future', _showFuture);
  }

  @override
  void didUpdateWidget(covariant PoolsAnalyticsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadPrefs();
  }

  String _formatCurrency(double amount, String currencyCode) {
    String symbol = '\$';
    if (currencyCode == 'EUR') symbol = '€';
    else if (currencyCode == 'GBP') symbol = '£';
    else if (currencyCode == 'JPY') symbol = '¥';
    
    final format = NumberFormat.currency(symbol: symbol, decimalDigits: currencyCode == 'JPY' ? 0 : 2);
    return format.format(amount);
  }

  void _showInfoDialog(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))),
          ],
        ),
        content: Text(description, style: TextStyle(fontSize: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155), height: 1.4)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDateFilter = widget.startDate != null || widget.endDate != null;
    final now = DateTime.now();

    // Calculate total liquid net worth across all active pools for percentage breakdown
    final activePoolKeys = widget.pools.keys.where((k) => _visiblePools[k] != false).toList();
    Map<String, double> poolBalancesMap = {};
    double totalLiquidNetWorth = 0;

    for (var poolKey in activePoolKeys) {
      double bal = 0;
      for (var tx in widget.transactions) {
        if (tx.pool.toLowerCase() != poolKey.toLowerCase()) continue;
        if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && tx.owner != widget.selectedOwner) continue;
        final txDate = DateTime.tryParse(tx.createdAt);
        if (txDate != null && !_showFuture && txDate.isAfter(now)) continue;
        if (tx.isConfirmed == 1 || (_showFuture && txDate != null && txDate.isAfter(now))) {
          bal += (tx.type == 'income' ? tx.amount : -tx.amount);
        }
      }
      poolBalancesMap[poolKey] = bal;
      if (bal > 0) {
        totalLiquidNetWorth += bal;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 32;
        final double boxWidth = (fullWidth - 12) / 2;

        return Container(
          padding: EdgeInsets.all(_isCollapsed ? 12 : 16),
          decoration: _isZaznamityMode
              ? BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF582F95).withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                )
              : BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'POOLS TRENDS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _showInfoModal(
                            context,
                            'Pools Analytics Guide',
                            'Analyze liquidity trends, net worth shares, and burn-rate depletion runways across your active financial pools.',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(Icons.info_outline_rounded, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline_rounded, size: 12, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                            const SizedBox(width: 4),
                            Text(
                              widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty ? widget.selectedOwner! : 'All Owners',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 28,
                        width: 28,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                            foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: _toggleCollapse,
                          icon: Icon(
                            _isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                            size: 16,
                          ),
                          tooltip: _isCollapsed ? 'Expand' : 'Collapse',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!_isCollapsed) ...[
                const SizedBox(height: 12),

                // Row 1: Pending Toggle & Date Range
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: boxWidth,
                      child: InkWell(
                        onTap: _toggleShowFuture,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: _showFuture
                                ? (_isZaznamityMode ? const Color(0xFFA855F7).withValues(alpha: 0.25) : const Color(0xFF582F95).withValues(alpha: 0.15))
                                : (_isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _showFuture
                                  ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                  : (_isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _showFuture ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                size: 16,
                                color: _showFuture
                                    ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                    : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pending',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _showFuture
                                      ? (_isZaznamityMode ? Colors.white : const Color(0xFF582F95))
                                      : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: boxWidth,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.horizontal(
                                  left: const Radius.circular(10),
                                  right: hasDateFilter ? Radius.zero : const Radius.circular(10),
                                ),
                                border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: widget.onSelectStartDate,
                                  borderRadius: BorderRadius.horizontal(
                                    left: const Radius.circular(10),
                                    right: hasDateFilter ? Radius.zero : const Radius.circular(10),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.date_range_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            widget.startDate != null && widget.endDate != null
                                                ? '${DateFormat('MM/dd').format(widget.startDate!)} - ${DateFormat('MM/dd').format(widget.endDate!)}'
                                                : widget.startDate != null
                                                    ? DateFormat('MM/dd').format(widget.startDate!)
                                                    : 'Select Date Range',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: hasDateFilter
                                                  ? (_isZaznamityMode ? Colors.white : const Color(0xFF1E293B))
                                                  : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                              fontWeight: hasDateFilter
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!hasDateFilter)
                                          Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (hasDateFilter) ...[
                            const SizedBox(width: 1),
                            Container(
                              height: 44,
                              width: 36,
                              decoration: BoxDecoration(
                                color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFE2E8F0),
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: widget.onClearDateFilter,
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                  child: const Center(
                                    child: Icon(Icons.clear, size: 14, color: Color(0xFFDC2626)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Secondary Toggle: Net Worth Share Breakdown View Mode
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Display Mode:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                    ),
                    InkWell(
                      onTap: _toggleViewAsPercentage,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: _viewAsPercentage
                              ? (_isZaznamityMode ? const Color(0xFFA855F7).withValues(alpha: 0.25) : const Color(0xFF582F95).withValues(alpha: 0.15))
                              : (_isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _viewAsPercentage
                                ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                : (_isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pie_chart_outline_rounded,
                              size: 14,
                              color: _viewAsPercentage
                                  ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                  : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _viewAsPercentage ? 'Net Worth Share (%)' : 'Absolute Amount',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _viewAsPercentage
                                    ? (_isZaznamityMode ? Colors.white : const Color(0xFF582F95))
                                    : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: _isZaznamityMode ? Colors.white24 : const Color(0xFFE2E8F0)),
                const SizedBox(height: 12),

                widget.pools.keys.isEmpty
                    ? Text('No pools available.', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: activePoolKeys.length,
                        itemBuilder: (context, index) {
                          String poolKey = activePoolKeys[index];
                          double poolBal = poolBalancesMap[poolKey] ?? 0;
                          double netWorthShare = (totalLiquidNetWorth > 0 && poolBal > 0) ? (poolBal / totalLiquidNetWorth) * 100 : 0.0;
                          return _buildPoolMiniSection(poolKey, now, poolBal, netWorthShare);
                        },
                      ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showInfoModal(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))),
          ],
        ),
        content: Text(description, style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), height: 1.4)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildPoolMiniSection(String poolKey, DateTime now, double poolBalance, double netWorthShare) {
    DateTime? effectiveStartDate = widget.startDate;
    if (effectiveStartDate == null) {
      if (_dateRangeSetting == '90 Days') {
        effectiveStartDate = now.subtract(const Duration(days: 90));
      } else {
        effectiveStartDate = now.subtract(const Duration(days: 30));
      }
    }

    final poolTxs = widget.transactions.where((tx) {
      if (tx.pool.toLowerCase() != poolKey.toLowerCase()) return false;
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && tx.owner != widget.selectedOwner) {
        return false;
      }
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null) return true;

      if (!_showFuture && txDate.isAfter(now)) return false;

      if (effectiveStartDate != null) {
        final startClean = DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day);
        if (txDate.isBefore(startClean)) return false;
      }
      if (widget.endDate != null) {
        final endClean = DateTime(widget.endDate!.year, widget.endDate!.month, widget.endDate!.day, 23, 59, 59);
        if (txDate.isAfter(endClean)) return false;
      }
      return true;
    }).toList();

    // Calculate Last 30 Days Net Flow for Runway & Depletion Warning calculation
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    double last30DaysNetFlow = 0;
    for (var tx in widget.transactions) {
      if (tx.pool.toLowerCase() != poolKey.toLowerCase()) continue;
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && tx.owner != widget.selectedOwner) continue;
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate != null && txDate.isAfter(thirtyDaysAgo) && txDate.isBefore(now)) {
        if (tx.isConfirmed == 1) {
          last30DaysNetFlow += (tx.type == 'income' ? tx.amount : -tx.amount);
        }
      }
    }

    int? depletionDays;
    if (last30DaysNetFlow < 0 && poolBalance > 0) {
      double dailyBurnRate = (-last30DaysNetFlow) / 30.0;
      if (dailyBurnRate > 0) {
        depletionDays = (poolBalance / dailyBurnRate).floor();
      }
    }

    double initialBalance = 0;
    if (effectiveStartDate != null) {
      final startClean = DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day);
      for (var tx in widget.transactions) {
        if (tx.pool.toLowerCase() != poolKey.toLowerCase()) continue;
        if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && tx.owner != widget.selectedOwner) continue;
        final txDate = DateTime.tryParse(tx.createdAt);
        if (txDate != null && txDate.isBefore(startClean)) {
          final isFutureTx = txDate.isAfter(now);
          if (!isFutureTx || _showFuture) {
            if (tx.isConfirmed == 1 || (isFutureTx && _showFuture)) {
              initialBalance += (tx.type == 'income' ? tx.amount : -tx.amount);
            }
          }
        }
      }
    }

    final sortedTxs = List<TransactionModel>.from(poolTxs)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a.createdAt) ?? DateTime.now();
        final dateB = DateTime.tryParse(b.createdAt) ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

    double runningTotal = initialBalance;
    List<FlSpot> spots = [];
    List<DateTime> spotDates = [];

    List<LineChartBarData> lineBars = [];
    List<FlSpot> currentSegmentSpots = [];
    Color? currentSegmentColor;
    bool currentIsDashed = false;

    for (int i = 0; i < sortedTxs.length; i++) {
      final t = sortedTxs[i];
      runningTotal += (t.type == 'income' ? t.amount : -t.amount);
      
      final txDate = DateTime.tryParse(t.createdAt) ?? now;
      spots.add(FlSpot(i.toDouble(), runningTotal));
      spotDates.add(txDate);

      final isFuture = txDate.isAfter(now);
      Color targetColor = isFuture
          ? const Color.fromARGB(255, 147, 51, 234)
          : (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95));
      bool targetDashed = isFuture;

      if (i == 0) {
        currentSegmentSpots.add(FlSpot(i.toDouble(), runningTotal));
        currentSegmentColor = targetColor;
        currentIsDashed = targetDashed;
        if (sortedTxs.length == 1) {
          currentSegmentSpots.insert(0, FlSpot(0, runningTotal - (t.type == 'income' ? t.amount : -t.amount)));
        }
      } else {
        if (currentSegmentColor != targetColor || currentIsDashed != targetDashed) {
          final prevSpot = currentSegmentSpots.last;
          currentSegmentSpots.add(FlSpot(i.toDouble(), runningTotal));

          lineBars.add(
            LineChartBarData(
              spots: List.from(currentSegmentSpots),
              isCurved: false,
              color: currentSegmentColor ?? const Color(0xFF582F95),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              dashArray: currentIsDashed ? [6, 4] : null,
              belowBarData: BarAreaData(show: false),
            ),
          );

          currentSegmentSpots = [prevSpot, FlSpot(i.toDouble(), runningTotal)];
          currentSegmentColor = targetColor;
          currentIsDashed = targetDashed;
        } else {
          currentSegmentSpots.add(FlSpot(i.toDouble(), runningTotal));
        }
      }
    }

    if (currentSegmentSpots.isNotEmpty && lineBars.isEmpty) {
      if (currentSegmentSpots.length == 1) {
        currentSegmentSpots.insert(0, FlSpot(0, currentSegmentSpots[0].y));
      }
      lineBars.add(
        LineChartBarData(
          spots: currentSegmentSpots,
          isCurved: true,
          color: currentSegmentColor ?? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
          barWidth: 2,
          dotData: const FlDotData(show: false),
          dashArray: currentIsDashed ? [6, 4] : null,
          belowBarData: BarAreaData(
            show: true,
            color: (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)).withValues(alpha: 0.1),
          ),
        ),
      );
    } else if (currentSegmentSpots.isNotEmpty) {
      lineBars.add(
        LineChartBarData(
          spots: currentSegmentSpots,
          isCurved: true,
          color: currentSegmentColor ?? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
          barWidth: 2,
          dotData: const FlDotData(show: false),
          dashArray: currentIsDashed ? [6, 4] : null,
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    if (spots.length == 1) {
      spots.insert(0, FlSpot(0, spots[0].y - (sortedTxs[0].type == 'income' ? sortedTxs[0].amount : -sortedTxs[0].amount)));
      spotDates.insert(0, spotDates[0].subtract(const Duration(days: 1)));
    } else if (spots.isEmpty) {
      spots.add(const FlSpot(0, 0));
      spotDates.add(now);
      lineBars = [
        LineChartBarData(
          spots: const [FlSpot(0, 0), FlSpot(1, 0)],
          color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
          barWidth: 2,
          dotData: const FlDotData(show: false),
        )
      ];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      poolKey.toUpperCase(),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                    ),
                    if (depletionDays != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF87171).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF87171)),
                        ),
                        child: Text(
                          '~${depletionDays}d to depletion',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFF87171)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                _viewAsPercentage
                    ? '${netWorthShare.toStringAsFixed(1)}% of Net Worth'
                    : _formatCurrency(poolBalance, _primaryCurrency),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: poolBalance >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final spotIndex = spot.x.toInt();
                        String dateStr = '';
                        if (spotIndex >= 0 && spotIndex < spotDates.length) {
                          dateStr = '${DateFormat('MMM d, yyyy').format(spotDates[spotIndex])}\n';
                        }
                        return LineTooltipItem(
                          '${dateStr}\$${spot.y.toStringAsFixed(2)}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: lineBars,
              ),
            ),
          ),
        ],
      ),
    );
  }
}