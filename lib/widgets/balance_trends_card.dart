// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaznamity/models/transaction_model.dart';
import 'package:zaznamity/models/label.dart';
import 'package:zaznamity/models/savings_goal_model.dart';
import '../services/privacy_service.dart';

enum TrendViewMode { liquid, savings, pool, allPools }
enum TrendLineOption { none, days7, days30 }

class BalanceTrendsCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final Map<String, bool> liquidNetPools;
  final Map<String, bool> allPools;
  final List<LabelModel> labels;
  final List<SavingsGoalModel> savingsGoals;
  final List<String> owners;
  final String? selectedOwner;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback? onSelectStartDate;
  final VoidCallback? onSelectEndDate;
  final VoidCallback? onClearDateFilter;
  final Function(DateTime day)? onDayTapped;

  const BalanceTrendsCard({
    super.key,
    required this.transactions,
    required this.liquidNetPools,
    required this.allPools,
    required this.labels,
    required this.savingsGoals,
    required this.owners,
    this.selectedOwner,
    this.startDate,
    this.endDate,
    this.onSelectStartDate,
    this.onSelectEndDate,
    this.onClearDateFilter,
    this.onDayTapped,
  });

  @override
  State<BalanceTrendsCard> createState() => _BalanceTrendsCardState();
}

class _BalanceTrendsCardState extends State<BalanceTrendsCard> with WidgetsBindingObserver {
  TrendViewMode _currentViewMode = TrendViewMode.liquid;
  String? _selectedPoolKey;
  TrendLineOption _trendLineOption = TrendLineOption.none;

  // Caching variables & keys
  int? _lastTxLength;
  int? _lastLabelsLength;
  int? _lastGoalsLength;
  String? _lastOwner;
  DateTime? _lastStartDate;
  DateTime? _lastEndDate;
  TrendLineOption? _lastTrendLineOption;
  bool? _lastShowFuture;
  bool? _lastIncludeLiabilities;
  String _lastPoolsKey = '';
  String _lastDateRangeSetting = '';
  String _lastViewModeKey = '';

  List<LineChartBarData> _cachedLineBars = [];
  double _cachedMinY = 0;
  double _cachedMaxY = 100;
  List<DateTime> _cachedSpotDates = [];
  List _cachedDailySeries = [];
  
  // Summary Metrics
  double _cachedInitialBalance = 0;
  double _cachedEndBalance = 0;
  double _cachedChangeAmount = 0;
  double _cachedChangePct = 0;
  double _cachedLowestPoint = 0;
  DateTime? _cachedLowestDate;
  double _cachedHighestPoint = 0;
  DateTime? _cachedHighestDate;
  String _cachedExplanation = '';
  DateTime? _cachedEffectiveStartDate;
  DateTime? _cachedEffectiveEndDate;

  String _currencyCode = 'USD';
  String _dateRangeSetting = '30 Days';
  bool _showFuture = false;
  bool _isZaznamityMode = true;
  bool _isCollapsed = false;
  bool _includeLiabilities = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
  }

  @override
  void didUpdateWidget(covariant BalanceTrendsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPrefs();
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final primary = prefs.getString('primaryCurrency') ?? 'USD';
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final collapsed = prefs.getBool('set_balanceTrends_collapsed') ?? false;
    final rangeSetting = prefs.getString('set_balanceTrends_range') ?? '30 Days';
    final showFuturePref = prefs.getBool('set_balanceTrends_show_future') ?? false;
    final includeLiab = prefs.getBool('set_balanceTrends_include_liab') ?? false;

    if (mounted) {
      setState(() {
        _currencyCode = primary;
        _dateRangeSetting = rangeSetting;
        _showFuture = showFuturePref;
        _includeLiabilities = includeLiab;
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _isCollapsed = collapsed;
      });
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('set_balanceTrends_range', _dateRangeSetting);
    await prefs.setBool('set_balanceTrends_show_future', _showFuture);
    await prefs.setBool('set_balanceTrends_include_liab', _includeLiabilities);
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_balanceTrends_collapsed', _isCollapsed);
  }

  Future<void> _toggleShowFuture() async {
    setState(() {
      _showFuture = !_showFuture;
    });
    await _savePrefs();
  }

  String _formatCurrency(double amount, {bool includeDecimals = true}) {
    final symbol = _getCurrencySymbol(_currencyCode);
    final formattedNumber = NumberFormat(includeDecimals ? '#,##0.00' : '#,##0', 'en_US').format(amount);
    if (_currencyCode.toUpperCase() == 'EUR') {
      return '$formattedNumber $symbol';
    } else {
      return '$symbol$formattedNumber';
    }
  }

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      default: return '\$';
    }
  }

  void _computeChartDataIfNeeded() {
    final poolsKey = widget.liquidNetPools.entries.map((e) => '${e.key}:${e.value}').join(',');
    final viewModeKey = '${_currentViewMode.name}_${_selectedPoolKey ?? ''}';

    if (_lastTxLength == widget.transactions.length &&
        _lastLabelsLength == widget.labels.length &&
        _lastGoalsLength == widget.savingsGoals.length &&
        _lastOwner == widget.selectedOwner &&
        _lastStartDate == widget.startDate &&
        _lastEndDate == widget.endDate &&
        _lastTrendLineOption == _trendLineOption &&
        _lastShowFuture == _showFuture &&
        _lastIncludeLiabilities == _includeLiabilities &&
        _lastPoolsKey == poolsKey &&
        _lastDateRangeSetting == _dateRangeSetting &&
        _lastViewModeKey == viewModeKey) {
      return;
    }

    final now = DateTime.now();
    DateTime? effectiveStartDate = widget.startDate;
    if (effectiveStartDate == null) {
      if (_dateRangeSetting == '90 Days') {
        effectiveStartDate = now.subtract(const Duration(days: 90));
      } else if (_dateRangeSetting == '1 Year') {
        effectiveStartDate = now.subtract(const Duration(days: 365));
      } else if (_dateRangeSetting == 'All Time') {
        effectiveStartDate = null;
      } else {
        effectiveStartDate = now.subtract(const Duration(days: 30));
      }
    }
    
    bool Function(TransactionModel) txFilter;
    if (_currentViewMode == TrendViewMode.liquid) {
      txFilter = (tx) => widget.liquidNetPools[tx.pool.toLowerCase()] == true;
    } else if (_currentViewMode == TrendViewMode.savings) {
      txFilter = (tx) => tx.pool.toLowerCase() == 'savings';
    } else if (_currentViewMode == TrendViewMode.allPools) {
      txFilter = (tx) {
        if (_includeLiabilities) return true;
        return tx.pool.toLowerCase() != 'liabilities' && tx.pool.toLowerCase() != 'debt';
      };
    } else {
      final targetPool = (_selectedPoolKey ?? widget.allPools.keys.firstOrNull ?? '').toLowerCase();
      txFilter = (tx) => tx.pool.toLowerCase() == targetPool;
    }

    // Find earliest and latest transaction dates across filtered transactions
    DateTime? earliestTxDate;
    DateTime? latestTxDate;
    for (var tx in widget.transactions) {
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && tx.owner != widget.selectedOwner) continue;
      if (!txFilter(tx)) continue;
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt != null) {
        if (!_showFuture && dt.isAfter(now)) continue;
        if (earliestTxDate == null || dt.isBefore(earliestTxDate)) {
          earliestTxDate = dt;
        }
        if (latestTxDate == null || dt.isAfter(latestTxDate)) {
          latestTxDate = dt;
        }
      }
    }

    if (_dateRangeSetting == 'All Time' && effectiveStartDate == null) {
      effectiveStartDate = earliestTxDate;
    }

    DateTime effectiveEndDate = widget.endDate ?? (_showFuture ? now.add(const Duration(days: 30)) : (latestTxDate ?? now));

    double initialBalance = 0;
    if (effectiveStartDate != null) {
      final startClean = DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day);
      for (var tx in widget.transactions) {
        if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && tx.owner != widget.selectedOwner) continue;
        final txDate = DateTime.tryParse(tx.createdAt);
        if (txDate != null && txDate.isBefore(startClean)) {
          if (tx.isConfirmed == 1 && txFilter(tx)) {
            double amt = tx.amount;
            if (_currentViewMode == TrendViewMode.allPools && _includeLiabilities && (tx.pool.toLowerCase() == 'liabilities' || tx.pool.toLowerCase() == 'debt')) {
              amt = -amt;
            }
            initialBalance += (tx.type == 'income' ? amt : -amt);
          }
        }
      }
    }

    Map<String, double> dailyDeltas = {};
    Map<String, List<TransactionModel>> dailyTxsMap = {};

    for (var tx in widget.transactions) {
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && tx.owner != widget.selectedOwner) continue;
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null) continue;

      bool counts = tx.isConfirmed == 1 || (_showFuture && tx.isConfirmed == 0 && txDate.isAfter(now));
      if (!counts) continue;
      if (!txFilter(tx)) continue;

      if (effectiveStartDate != null && txDate.isBefore(DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day))) continue;
      if (txDate.isAfter(effectiveEndDate)) continue;

      final dateKey = DateFormat('yyyy-MM-dd').format(txDate);
      double amt = tx.amount;
      if (_currentViewMode == TrendViewMode.allPools && _includeLiabilities && (tx.pool.toLowerCase() == 'liabilities' || tx.pool.toLowerCase() == 'debt')) {
        amt = -amt;
      }
      final delta = (tx.type == 'income' ? amt : -amt);
      dailyDeltas[dateKey] = (dailyDeltas[dateKey] ?? 0) + delta;
      dailyTxsMap.putIfAbsent(dateKey, () => []).add(tx);
    }

    List dailySeries = [];
    double runningBalance = initialBalance;
    DateTime timelineStart = effectiveStartDate ?? (earliestTxDate ?? now.subtract(const Duration(days: 30)));
    DateTime timelineEnd = effectiveEndDate;

    DateTime current = DateTime(timelineStart.year, timelineStart.month, timelineStart.day);
    final endClean = DateTime(timelineEnd.year, timelineEnd.month, timelineEnd.day);

    while (!current.isAfter(endClean)) {
      final dateKey = DateFormat('yyyy-MM-dd').format(current);
      if (dailyDeltas.containsKey(dateKey)) {
        runningBalance += dailyDeltas[dateKey]!;
      }
      dailySeries.add({
        'date': current,
        'balance': runningBalance,
        'transactions': dailyTxsMap[dateKey] ?? [],
      });
      current = current.add(const Duration(days: 1));
    }

    if (dailySeries.isEmpty) {
      dailySeries.add({'date': now, 'balance': 0.0, 'transactions': <TransactionModel>[]});
    }

    List<LineChartBarData> lineBars = [];
    List<FlSpot> currentSegmentSpots = [];
    List<DateTime> spotDates = [];
    Color? currentSegmentColor;
    bool currentIsDashed = false;

    double lowest = double.infinity;
    double highest = -double.infinity;
    DateTime? lowestDate;
    DateTime? highestDate;

    for (int i = 0; i < dailySeries.length; i++) {
      final item = dailySeries[i];
      final bal = item['balance'] as double;
      final dt = item['date'] as DateTime;
      final txs = item['transactions'] as List<TransactionModel>;

      if (bal < lowest) {
        lowest = bal;
        lowestDate = dt;
      }
      if (bal > highest) {
        highest = bal;
        highestDate = dt;
      }

      final isFuture = dt.isAfter(now);
      Color targetColor;
      if (isFuture) {
        targetColor = const Color.fromARGB(255, 147, 51, 234);
      } else {
        double dailyNetDelta = 0;
        for (var tx in txs) {
          double amt = tx.amount;
          if (_currentViewMode == TrendViewMode.allPools && _includeLiabilities && (tx.pool.toLowerCase() == 'liabilities' || tx.pool.toLowerCase() == 'debt')) {
            amt = -amt;
          }
          dailyNetDelta += (tx.type == 'income' ? amt : -amt);
        }

        if (txs.isEmpty && i > 0) {
          targetColor = currentSegmentColor ?? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95));
        } else {
          targetColor = dailyNetDelta >= 0 ? Colors.green.shade600 : Colors.red.shade600;
        }
      }
      bool targetDashed = isFuture;

      if (i == 0) {
        currentSegmentSpots.add(FlSpot(i.toDouble(), bal));
        spotDates.add(dt);
        currentSegmentColor = targetColor;
        currentIsDashed = targetDashed;
        if (dailySeries.length == 1) {
          currentSegmentSpots.insert(0, FlSpot(0, bal));
          spotDates.insert(0, dt.subtract(const Duration(days: 1)));
        }
      } else {
        if (currentSegmentColor != targetColor || currentIsDashed != targetDashed) {
          final prevSpot = currentSegmentSpots.last;
          currentSegmentSpots.add(FlSpot(i.toDouble(), bal));
          spotDates.add(dt);

          lineBars.add(
            LineChartBarData(
              spots: List.from(currentSegmentSpots),
              isCurved: false,
              color: currentSegmentColor ?? const Color(0xFF582F95),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: currentIsDashed ? [6, 4] : null,
              belowBarData: BarAreaData(show: false),
            ),
          );

          currentSegmentSpots = [prevSpot, FlSpot(i.toDouble(), bal)];
          currentSegmentColor = targetColor;
          currentIsDashed = targetDashed;
        } else {
          currentSegmentSpots.add(FlSpot(i.toDouble(), bal));
          spotDates.add(dt);
        }
      }
    }

    if (currentSegmentSpots.isNotEmpty) {
      lineBars.add(
        LineChartBarData(
          spots: currentSegmentSpots,
          isCurved: false,
          color: currentSegmentColor ?? const Color(0xFF582F95),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          dashArray: currentIsDashed ? [6, 4] : null,
          belowBarData: BarAreaData(
            show: true,
            color: (currentSegmentColor ?? const Color(0xFF582F95)).withValues(alpha: 0.08),
          ),
        ),
      );
    }

    double initialBal = dailySeries.isNotEmpty ? dailySeries.first['balance'] as double : 0;
    double endBal = dailySeries.isNotEmpty ? dailySeries.last['balance'] as double : 0;
    double changeAmt = endBal - initialBal;
    double changePct = initialBal != 0 ? (changeAmt / initialBal.abs()) * 100 : 0;

    List<FlSpot> trendLineSpots = [];
    if (_trendLineOption != TrendLineOption.none && dailySeries.isNotEmpty) {
      int window = _trendLineOption == TrendLineOption.days7 ? 7 : 30;
      for (int i = 0; i < dailySeries.length; i++) {
        double sum = 0;
        int count = 0;
        int startIdx = (i - window).clamp(0, i);
        for (int j = startIdx; j <= i; j++) {
          sum += (dailySeries[j]['balance'] as double);
          count++;
        }
        if (count > 0) {
          trendLineSpots.add(FlSpot(i.toDouble(), sum / count));
        }
      }
    }

    if (trendLineSpots.isNotEmpty) {
      lineBars.add(
        LineChartBarData(
          spots: trendLineSpots,
          isCurved: true,
          color: Colors.amber.shade700,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

//   String explanation = _generateExplanation(dailySeries, changeAmt);

    final double yRange = highest - lowest;
    final double yPadding = yRange == 0 ? 50 : yRange * 0.15;

    _cachedLineBars = lineBars;
    _cachedMinY = lowest - yPadding;
    _cachedMaxY = highest + yPadding;
    _cachedSpotDates = spotDates;
    _cachedDailySeries = dailySeries;
    _cachedInitialBalance = initialBal;
    _cachedEndBalance = endBal;
    _cachedChangeAmount = changeAmt;
    _cachedChangePct = changePct;
    _cachedLowestPoint = lowest;
    _cachedLowestDate = lowestDate;
    _cachedHighestPoint = highest;
    _cachedHighestDate = highestDate;
    // _cachedExplanation = explanation;
    _cachedEffectiveStartDate = timelineStart;
    _cachedEffectiveEndDate = timelineEnd;

    _lastTxLength = widget.transactions.length;
    _lastLabelsLength = widget.labels.length;
    _lastGoalsLength = widget.savingsGoals.length;
    _lastOwner = widget.selectedOwner;
    _lastStartDate = widget.startDate;
    _lastEndDate = widget.endDate;
    _lastTrendLineOption = _trendLineOption;
    _lastShowFuture = _showFuture;
    _lastIncludeLiabilities = _includeLiabilities;
    _lastPoolsKey = poolsKey;
    _lastDateRangeSetting = _dateRangeSetting;
    _lastViewModeKey = viewModeKey;
  }

/*   String _generateExplanation(List series, double changeAmt) {
    if (series.length < 2) return 'Stable balance over the period.';
    
    Map<String, double> categoryDeltas = {};
    for (var item in series) {
      final txs = item['transactions'] as List<TransactionModel>;
      for (var tx in txs) {
        if (tx.type == 'expense') {
          categoryDeltas[tx.pool] = (categoryDeltas[tx.pool] ?? 0) + tx.amount;
        }
      }
    }

    var sortedCats = categoryDeltas.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    String direction = changeAmt >= 0 ? 'Up' : 'Down';
    double pct = series.first['balance'] != 0 ? (changeAmt / (series.first['balance'] as double).abs()) * 100 : 0;
    
    if (sortedCats.isNotEmpty) {
      return '$direction ${pct.toStringAsFixed(0)}% vs start, mainly driven by expenses in ${sortedCats.first.key} (${_formatCurrency(sortedCats.first.value, includeDecimals: false)}).';
    }
    return '$direction ${pct.toStringAsFixed(0)}% over the selected range.';
  } */

  @override
  Widget build(BuildContext context) {
    _computeChartDataIfNeeded();
    final bool hasDateFilter = widget.startDate != null || widget.endDate != null;
    final activeOwner = widget.selectedOwner ?? 'All Owners';

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
                  border: Border.all(color: const Color(0xFF582F95).withValues(alpha: 0.5), width: 1.2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))],
                )
              : BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
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
                            'BALANCE TRENDS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                              letterSpacing: 0.8,
                            ),
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
                              activeOwner,
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
                          icon: Icon(_isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded, size: 16),
                          tooltip: _isCollapsed ? 'Expand' : 'Collapse',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!_isCollapsed) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: boxWidth,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _currentViewMode == TrendViewMode.liquid 
                                      ? 'Liquid' 
                                      : _currentViewMode == TrendViewMode.savings 
                                          ? 'Savings'
                                          : _currentViewMode == TrendViewMode.allPools
                                              ? 'All Pools'
                                              : (_selectedPoolKey ?? widget.allPools.keys.firstOrNull ?? 'Pool'),
                                  isDense: true,
                                  isExpanded: true,
                                  dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                  items: [
                                    const DropdownMenuItem(value: 'Liquid', child: Text('Liquid Net')),
                                    const DropdownMenuItem(value: 'Savings', child: Text('Savings Pool')),
                                    const DropdownMenuItem(value: 'All Pools', child: Text('All Pools')),
                                    ...widget.allPools.keys.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == 'Liquid') {
                                        _currentViewMode = TrendViewMode.liquid;
                                        _selectedPoolKey = null;
                                      } else if (val == 'Savings') {
                                        _currentViewMode = TrendViewMode.savings;
                                        _selectedPoolKey = null;
                                      } else if (val == 'All Pools') {
                                        _currentViewMode = TrendViewMode.allPools;
                                        _selectedPoolKey = null;
                                      } else if (val != null) {
                                        _currentViewMode = TrendViewMode.pool;
                                        _selectedPoolKey = val;
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
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
                                              fontWeight: hasDateFilter ? FontWeight.bold : FontWeight.normal,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
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
                                  child: const Center(child: Icon(Icons.clear, size: 14, color: Color(0xFFDC2626))),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildRangeChip('30D', '30 Days'),
                        const SizedBox(width: 4),
                        _buildRangeChip('90D', '90 Days'),
                        const SizedBox(width: 4),
                        _buildRangeChip('1Y', '1 Year'),
                        const SizedBox(width: 4),
                        _buildRangeChip('All', 'All Time'),
                      ],
                    ),
                    InkWell(
                      onTap: _toggleShowFuture,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: _showFuture
                              ? (_isZaznamityMode ? const Color(0xFFA855F7).withValues(alpha: 0.25) : const Color(0xFF582F95).withValues(alpha: 0.15))
                              : (_isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _showFuture
                                ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                : (_isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showFuture ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              size: 14,
                              color: _showFuture
                                  ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                  : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Pending',
                              style: TextStyle(
                                fontSize: 10,
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
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('Trend Line:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                        const SizedBox(width: 6),
                        _buildTrendLineChip('None', TrendLineOption.none),
                        const SizedBox(width: 4),
                        _buildTrendLineChip('7D', TrendLineOption.days7),
                        const SizedBox(width: 4),
                        _buildTrendLineChip('30D', TrendLineOption.days30),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'PROJECTION WINDOW: ${_cachedEffectiveStartDate != null && _cachedEffectiveEndDate != null ? '${DateFormat('MMM dd, yyyy').format(_cachedEffectiveStartDate!)} – ${DateFormat('MMM dd, yyyy').format(_cachedEffectiveEndDate!)}' : 'Dynamic'}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<bool>(
                  valueListenable: PrivacyService.instance.isPrivacyModeEnabled,
                  builder: (context, isPrivate, child) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Subtitles in the same row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Initial Balance', style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Text('Change', style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('End Balance', style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Row 2: Amounts in the same row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    isPrivate ? '••••••' : _formatCurrency(_cachedInitialBalance),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _cachedInitialBalance >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    isPrivate ? '••••••' : '${_cachedChangeAmount >= 0 ? '+' : ''}${_formatCurrency(_cachedChangeAmount)}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _cachedChangeAmount >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    isPrivate ? '••••••' : _formatCurrency(_cachedEndBalance),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _cachedEndBalance >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Row 3: Percentage change of "Change" in a new row
                          Center(
                            child: Text(
                              isPrivate ? '••••••' : '${_cachedChangePct >= 0 ? '+' : ''}${_cachedChangePct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _cachedChangePct >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSummaryItem(
                                'Lowest', 
                                isPrivate ? '••••••' : '${_formatCurrency(_cachedLowestPoint)} (${_cachedLowestDate != null ? DateFormat('MMM d').format(_cachedLowestDate!) : ''})',
                                color: _cachedLowestPoint >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                              ),
                              _buildSummaryItem(
                                'Highest', 
                                isPrivate ? '••••••' : '${_formatCurrency(_cachedHighestPoint)} (${_cachedHighestDate != null ? DateFormat('MMM d').format(_cachedHighestDate!) : ''})',
                                color: _cachedHighestPoint >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                align: CrossAxisAlignment.end,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _cachedExplanation,
                            style: TextStyle(fontSize: 10.5, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: PrivacyService.instance.isPrivacyModeEnabled,
                    builder: (context, isPrivate, child) {
                      final bool isLongRange = _cachedDailySeries.length > 365;
                      final double chartWidth = isLongRange ? _cachedDailySeries.length * 12.0 : constraints.maxWidth - 32;

                      Widget chartWidget = LineChart(
                        LineChartData(
                          minY: _cachedMinY,
                          maxY: _cachedMaxY,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(color: _isZaznamityMode ? Colors.white10 : const Color(0xFFF1F5F9), strokeWidth: 1);
                            },
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: (_cachedDailySeries.length / 5).clamp(1, 100).toDouble(),
                                getTitlesWidget: (value, meta) {
                                  int index = value.toInt();
                                  if (index >= 0 && index < _cachedDailySeries.length) {
                                    final date = _cachedDailySeries[index]['date'] as DateTime;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        DateFormat('MMM d').format(date),
                                        style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 48,
                                getTitlesWidget: (value, meta) {
                                  final labelText = isPrivate ? '•••' : _formatCurrency(value.toDouble(), includeDecimals: false);
                                  return Text(
                                    labelText,
                                    style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            enabled: true,
                            handleBuiltInTouches: true,
                            touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                              if (event is FlTapUpEvent && response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                                final spotIndex = response.lineBarSpots!.first.x.toInt();
                                if (spotIndex >= 0 && spotIndex < _cachedDailySeries.length) {
                                  final tappedDate = _cachedDailySeries[spotIndex]['date'] as DateTime;
                                  widget.onDayTapped?.call(tappedDate);
                                }
                              }
                            },
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final spotIndex = spot.x.toInt();
                                  String dateStr = '';
                                  if (spotIndex >= 0 && spotIndex < _cachedSpotDates.length) {
                                    dateStr = '${DateFormat('MMM d, yyyy').format(_cachedSpotDates[spotIndex])}\n';
                                  }
                                  final tooltipVal = isPrivate ? '••••••' : _formatCurrency(spot.y);
                                  return LineTooltipItem(
                                    '$dateStr$tooltipVal',
                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          lineBarsData: _cachedLineBars,
                        ),
                      );

                      if (isLongRange) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth,
                            height: 220,
                            child: chartWidget,
                          ),
                        );
                      } else {
                        return SizedBox(
                          height: 220,
                          child: chartWidget,
                        );
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRangeChip(String label, String settingValue) {
    final selected = _dateRangeSetting == settingValue;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? Colors.white : Colors.black87)),
      selected: selected,
      showCheckmark: false,
      onSelected: (sel) {
        if (sel) {
          setState(() {
            _dateRangeSetting = settingValue;
          });
          _savePrefs();
        }
      },
      selectedColor: _isZaznamityMode ? const Color(0xFFA855F7) : Colors.amber.shade200,
      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : null,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildTrendLineChip(String label, TrendLineOption option) {
    final selected = _trendLineOption == option;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? Colors.white : Colors.black87)),
      selected: selected,
      showCheckmark: false,
      onSelected: (sel) {
        setState(() {
          _trendLineOption = sel ? option : TrendLineOption.none;
        });
      },
      selectedColor: _isZaznamityMode ? const Color(0xFFA855F7) : Colors.amber.shade200,
      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : null,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildSummaryItem(String label, String value, {Color? color, CrossAxisAlignment align = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color ?? (_isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))),
      ],
    );
  }
}