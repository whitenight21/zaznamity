// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaznamity/models/transaction_model.dart';

enum MovingAverageFilter { days30, days90, all }

class LiquidTrendChartCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final Map<String, bool> liquidNetPools;
  final List<String> owners;
  final String? selectedOwner;
  final ValueChanged<String?>? onOwnerChanged;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback? onSelectStartDate;
  final VoidCallback? onSelectEndDate;
  final VoidCallback? onClearDateFilter;

  const LiquidTrendChartCard({
    super.key,
    required this.transactions,
    required this.liquidNetPools,
    required this.owners,
    this.selectedOwner,
    this.onOwnerChanged,
    this.startDate,
    this.endDate,
    this.onSelectStartDate,
    this.onSelectEndDate,
    this.onClearDateFilter,
  });

  @override
  State<LiquidTrendChartCard> createState() => _LiquidTrendChartChartCardState();
}

class _LiquidTrendChartChartCardState extends State<LiquidTrendChartCard> {
  MovingAverageFilter? _maFilter;

  List<TransactionModel> _cachedSortedTx = [];
  List<LineChartBarData> _cachedLineBars = [];
  double _cachedMinY = 0;
  double _cachedMaxY = 100;
  List<DateTime> _cachedSpotDates = [];
  double _cachedMonthlyVelocity = 0;
  double _cachedRunwayMonths = 0;

  int? _lastTxLength;
  String? _lastOwner;
  DateTime? _lastStartDate;
  DateTime? _lastEndDate;
  MovingAverageFilter? _lastMaFilter;
  bool? _lastShowFuture;
  String _lastPoolsKey = '';
  String _currencySymbol = '\$';
  String _dateRangeSetting = '30 Days';
  bool _showFuture = false;
  bool _isZaznamityMode = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final primary = prefs.getString('primaryCurrency') ?? 'USD';
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    if (mounted) {
      setState(() {
        _currencySymbol = _getCurrencySymbol(primary);
        _dateRangeSetting = prefs.getString('set_liquidTrend_range') ?? '30 Days';
        _showFuture = prefs.getBool('set_liquidTrend_show_future') ?? false;
        _isZaznamityMode = (savedTheme == 'zaznamity');
      });
    }
  }

  Future<void> _toggleShowFuture() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showFuture = !_showFuture;
    });
    await prefs.setBool('set_liquidTrend_show_future', _showFuture);
  }

  @override
  void didUpdateWidget(covariant LiquidTrendChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadPrefs();
  }

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      default: return '\$';
    }
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

  void _computeChartDataIfNeeded() {
    final poolsKey = widget.liquidNetPools.entries.map((e) => '${e.key}:${e.value}').join(',');

    if (_lastTxLength == widget.transactions.length &&
        _lastOwner == widget.selectedOwner &&
        _lastStartDate == widget.startDate &&
        _lastEndDate == widget.endDate &&
        _lastMaFilter == _maFilter &&
        _lastShowFuture == _showFuture &&
        _lastPoolsKey == poolsKey) {
      return;
    }

    final now = DateTime.now();

    DateTime? effectiveStartDate = widget.startDate;
    if (effectiveStartDate == null) {
      if (_dateRangeSetting == '90 Days') {
        effectiveStartDate = now.subtract(const Duration(days: 90));
      } else if (_dateRangeSetting == '1 Year') {
        effectiveStartDate = now.subtract(const Duration(days: 365));
      } else {
        effectiveStartDate = now.subtract(const Duration(days: 30));
      }
    }

    double initialBalance = 0;
    if (effectiveStartDate != null) {
      final startClean = DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day);
      for (var tx in widget.transactions) {
        if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty) {
          if (tx.owner != widget.selectedOwner) continue;
        }
        final txDate = DateTime.tryParse(tx.createdAt);
        if (txDate != null && txDate.isBefore(startClean)) {
          final isPoolIncluded = widget.liquidNetPools[tx.pool] == true;
          if (tx.isConfirmed == 1 && isPoolIncluded) {
            initialBalance += (tx.type == 'income' ? tx.amount : -tx.amount);
          }
        }
      }
    }

    final filteredTx = widget.transactions.where((tx) {
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty) {
        if (tx.owner != widget.selectedOwner) return false;
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

    final sortedTx = List<TransactionModel>.from(filteredTx)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a.createdAt) ?? DateTime.now();
        final dateB = DateTime.tryParse(b.createdAt) ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

    List<LineChartBarData> lineBars = [];

    double currentBalance = initialBalance;
    List<FlSpot> currentSegmentSpots = [];
    List<DateTime> spotDates = [];
    Color? currentSegmentColor;
    bool currentIsDashed = false;

    List<Map<String, dynamic>> balancePoints = [];

    for (int i = 0; i < sortedTx.length; i++) {
      final t = sortedTx[i];
      final isPoolIncluded = widget.liquidNetPools[t.pool] == true;
      if ((t.isConfirmed == 1 || t.isConfirmed == 0) && isPoolIncluded) {
        currentBalance += (t.type == 'income' ? t.amount : -t.amount);
      }
      
      final txDate = DateTime.tryParse(t.createdAt) ?? now;
      balancePoints.add({
        'index': i.toDouble(),
        'balance': currentBalance,
        'date': txDate,
      });

      final isFuture = txDate.isAfter(now);
      
      Color targetColor;
      if (isFuture) {
        targetColor = const Color.fromARGB(255, 147, 51, 234);
      } else {
        targetColor = t.type == 'income' ? Colors.green.shade600 : Colors.red.shade600;
      }
      bool targetDashed = isFuture;

      if (i == 0) {
        currentSegmentSpots.add(FlSpot(i.toDouble(), currentBalance));
        spotDates.add(txDate);
        currentSegmentColor = targetColor;
        currentIsDashed = targetDashed;
        if (sortedTx.length == 1) {
          currentSegmentSpots.insert(0, FlSpot(0, currentBalance - (t.type == 'income' ? t.amount : -t.amount)));
          spotDates.insert(0, txDate.subtract(const Duration(days: 1)));
        }
      } else {
        if (currentSegmentColor != targetColor || currentIsDashed != targetDashed) {
          final prevSpot = currentSegmentSpots.last;
          currentSegmentSpots.add(FlSpot(i.toDouble(), currentBalance));
          spotDates.add(txDate);

          lineBars.add(
            LineChartBarData(
              spots: List.from(currentSegmentSpots),
              isCurved: false,
              color: currentSegmentColor ?? const Color.fromARGB(255, 88, 47, 149),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: currentIsDashed ? [6, 4] : null,
              belowBarData: BarAreaData(show: false),
            ),
          );

          currentSegmentSpots = [prevSpot, FlSpot(i.toDouble(), currentBalance)];
          currentSegmentColor = targetColor;
          currentIsDashed = targetDashed;
        } else {
          currentSegmentSpots.add(FlSpot(i.toDouble(), currentBalance));
          spotDates.add(txDate);
        }
      }
    }

    if (currentSegmentSpots.isNotEmpty && lineBars.isEmpty) {
      if (currentSegmentSpots.length == 1) {
        currentSegmentSpots.insert(0, FlSpot(0, currentSegmentSpots[0].y));
        spotDates.insert(0, spotDates[0].subtract(const Duration(days: 1)));
      }
      lineBars.add(
        LineChartBarData(
          spots: currentSegmentSpots,
          isCurved: false,
          color: currentSegmentColor ?? const Color.fromARGB(255, 88, 47, 149),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          dashArray: currentIsDashed ? [6, 4] : null,
          belowBarData: BarAreaData(
            show: true,
            color: const Color.fromARGB(255, 189, 145, 255).withValues(alpha: 0.08),
          ),
        ),
      );
    } else if (currentSegmentSpots.isNotEmpty) {
      lineBars.add(
        LineChartBarData(
          spots: currentSegmentSpots,
          isCurved: false,
          color: currentSegmentColor ?? const Color.fromARGB(255, 88, 47, 149),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          dashArray: currentIsDashed ? [6, 4] : null,
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    if (_maFilter != null && balancePoints.isNotEmpty) {
      List<FlSpot> maSpots = [];
      for (int i = 0; i < balancePoints.length; i++) {
        final currentDate = balancePoints[i]['date'] as DateTime;
        double sum = 0;
        int count = 0;

        for (int j = 0; j <= i; j++) {
          final pastDate = balancePoints[j]['date'] as DateTime;
          bool include = false;

          if (_maFilter == MovingAverageFilter.days30) {
            if (currentDate.difference(pastDate).inDays <= 30) include = true;
          } else if (_maFilter == MovingAverageFilter.days90) {
            if (currentDate.difference(pastDate).inDays <= 90) include = true;
          } else if (_maFilter == MovingAverageFilter.all) {
            include = true;
          }

          if (include) {
            sum += (balancePoints[j]['balance'] as double);
            count++;
          }
        }

        if (count > 0) {
          maSpots.add(FlSpot(i.toDouble(), sum / count));
        }
      }

      if (maSpots.isNotEmpty) {
        lineBars.add(
          LineChartBarData(
            spots: maSpots,
            isCurved: true,
            color: Colors.amber.shade700,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        );
      }
    }

    if (lineBars.isEmpty) {
      lineBars.add(
        LineChartBarData(
          spots: const [FlSpot(0, 0), FlSpot(1, 0)],
          color: const Color.fromARGB(255, 88, 47, 149),
          barWidth: 3,
          dotData: const FlDotData(show: false),
        ),
      );
      spotDates = [now, now];
    }

    double lowestPoint = double.infinity;
    double highestPoint = -double.infinity;
    for (var bar in lineBars) {
      for (var spot in bar.spots) {
        if (spot.y < lowestPoint) lowestPoint = spot.y;
        if (spot.y > highestPoint) highestPoint = spot.y;
      }
    }
    if (lowestPoint == double.infinity) lowestPoint = 0;
    if (highestPoint == -double.infinity) highestPoint = 0;

    double monthlyVelocity = 0;
    if (balancePoints.length >= 2) {
      final firstPoint = balancePoints.first;
      final lastPoint = balancePoints.last;
      final daysDiff = (lastPoint['date'] as DateTime).difference(firstPoint['date'] as DateTime).inDays;
      if (daysDiff > 0) {
        final totalDelta = (lastPoint['balance'] as double) - (firstPoint['balance'] as double);
        monthlyVelocity = (totalDelta / daysDiff) * 30;
      }
    }

    double totalExpensesSum = 0;
    int expenseTxCount = 0;
    for (var tx in filteredTx) {
      if (tx.isConfirmed == 1 && tx.type == 'expense') {
        totalExpensesSum += tx.amount;
        expenseTxCount++;
      }
    }
    double runwayMonths = 0;
    if (expenseTxCount > 0 && balancePoints.isNotEmpty) {
      final latestBalance = balancePoints.last['balance'] as double;
      final firstDate = balancePoints.first['date'] as DateTime;
      final lastDate = balancePoints.last['date'] as DateTime;
      final totalSpanDays = lastDate.difference(firstDate).inDays;
      if (totalSpanDays > 0) {
        final monthlyBurnRate = (totalExpensesSum / totalSpanDays) * 30;
        if (monthlyBurnRate > 0) {
          runwayMonths = latestBalance / monthlyBurnRate;
        }
      }
    }

    final double yRange = highestPoint - lowestPoint;
    final double yPadding = yRange == 0 ? 50 : yRange * 0.15;
    
    double minY = lowestPoint - yPadding;
    double maxY = highestPoint + yPadding;

    _cachedSortedTx = sortedTx;
    _cachedLineBars = lineBars;
    _cachedMinY = minY;
    _cachedMaxY = maxY;
    _cachedSpotDates = spotDates;
    _cachedMonthlyVelocity = monthlyVelocity;
    _cachedRunwayMonths = runwayMonths;

    _lastTxLength = widget.transactions.length;
    _lastOwner = widget.selectedOwner;
    _lastStartDate = widget.startDate;
    _lastEndDate = widget.endDate;
    _lastMaFilter = _maFilter;
    _lastShowFuture = _showFuture;
    _lastPoolsKey = poolsKey;
  }

  @override
  Widget build(BuildContext context) {
    _computeChartDataIfNeeded();

    final bool hasDateFilter = widget.startDate != null || widget.endDate != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 48;
        final double boxWidth = (fullWidth - 12) / 2;

        return Container(
          padding: const EdgeInsets.all(24),
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'LIQUID TREND',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isZaznamityMode ? Colors.white : const Color.fromARGB(255, 88, 47, 149),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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

              LayoutBuilder(
                builder: (context, rowConstraints) {
                  final double rowWidth = rowConstraints.maxWidth;
                  final double w25 = (rowWidth - 16) * 0.24;
                  final double w50 = (rowWidth - 16) * 0.48;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: w25,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 48,
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isZaznamityMode
                                    ? const Color(0xFF1E1333)
                                    : (_cachedMonthlyVelocity >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isZaznamityMode
                                      ? Colors.white12
                                      : (_cachedMonthlyVelocity >= 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _cachedMonthlyVelocity >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                        size: 11,
                                        color: _cachedMonthlyVelocity >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Velocity',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${_cachedMonthlyVelocity >= 0 ? '+' : ''}$_currencySymbol${_cachedMonthlyVelocity.toStringAsFixed(2)}/mo',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _cachedMonthlyVelocity >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -4,
                              child: InkWell(
                                onTap: () => _showInfoDialog(
                                  context,
                                  'Liquid Velocity',
                                  'Liquid velocity measures the average monthly rate of change in your liquid net worth over the selected period.',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color.fromARGB(255, 158, 158, 158)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: w25,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 48,
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFBFDBFE)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.hourglass_top_rounded,
                                        size: 11,
                                        color: Color(0xFF2563EB),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Runway',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${_cachedRunwayMonths.toStringAsFixed(1)} mos',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -4,
                              child: InkWell(
                                onTap: () => _showInfoDialog(
                                  context,
                                  'Liquid Runway',
                                  'Liquid runway estimates how many months your current liquid balance will last based on your average burn rate.',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color.fromARGB(255, 158, 158, 158)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: w50,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Moving average (days):',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 2),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ChoiceChip(
                                      label: Text('30', style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                      selected: _maFilter == MovingAverageFilter.days30,
                                      showCheckmark: false,
                                      onSelected: (selected) {
                                        setState(() {
                                          _maFilter = selected ? MovingAverageFilter.days30 : null;
                                        });
                                      },
                                      selectedColor: _isZaznamityMode ? const Color(0xFFA855F7) : Colors.amber.shade200,
                                      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : null,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                    ),
                                    const SizedBox(width: 4),
                                    ChoiceChip(
                                      label: Text('90', style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                      selected: _maFilter == MovingAverageFilter.days90,
                                      showCheckmark: false,
                                      onSelected: (selected) {
                                        setState(() {
                                          _maFilter = selected ? MovingAverageFilter.days90 : null;
                                        });
                                      },
                                      selectedColor: _isZaznamityMode ? const Color(0xFFA855F7) : Colors.amber.shade200,
                                      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : null,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                    ),
                                    const SizedBox(width: 4),
                                    ChoiceChip(
                                      label: Text('All', style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                      selected: _maFilter == MovingAverageFilter.all,
                                      showCheckmark: false,
                                      onSelected: (selected) {
                                        setState(() {
                                          _maFilter = selected ? MovingAverageFilter.all : null;
                                        });
                                      },
                                      selectedColor: _isZaznamityMode ? const Color(0xFFA855F7) : Colors.amber.shade200,
                                      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : null,
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: _cachedMinY,
                    maxY: _cachedMaxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: _isZaznamityMode ? Colors.white10 : const Color(0xFFF1F5F9),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < _cachedSortedTx.length) {
                              final date = DateTime.tryParse(_cachedSortedTx[index].createdAt);
                              if (date != null) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('MMM d').format(date),
                                    style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                  ),
                                );
                              }
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
                            return Text(
                              '$_currencySymbol${value.toInt()}',
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
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final spotIndex = spot.x.toInt();
                            String dateStr = '';
                            if (spotIndex >= 0 && spotIndex < _cachedSpotDates.length) {
                              dateStr = '${DateFormat('MMM d, yyyy').format(_cachedSpotDates[spotIndex])}\n';
                            }
                            return LineTooltipItem(
                              '${dateStr}$_currencySymbol${spot.y.toStringAsFixed(2)}',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: _cachedLineBars,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}