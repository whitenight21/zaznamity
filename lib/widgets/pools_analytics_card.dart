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
  final bool isWide;
  final VoidCallback onToggleWidth;
  final VoidCallback onHide;

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
    required this.isWide,
    required this.onToggleWidth,
    required this.onHide,
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
    setState(() {
      _primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';
      _dateRangeSetting = prefs.getString('set_poolsTrends_range') ?? '30 Days';
      _showOnlyFunded = prefs.getBool('set_poolsTrends_funded_only') ?? false;
      _showFuture = prefs.getBool('set_poolsTrends_show_future') ?? false;

      for (var key in widget.pools.keys) {
        _visiblePools[key] = prefs.getBool('set_poolsTrends_pool_visible_$key') ?? true;
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final bool hasDateFilter = widget.startDate != null || widget.endDate != null;
    final now = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 48;
        final double boxWidth = (fullWidth - 12) / 2;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
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
                      child: Row(
                        children: [
                          const Text(
                            'POOLS TRENDS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF582F95),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              hasDateFilter ? 'Custom' : _dateRangeSetting,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: SizedBox(
                          height: 32,
                          width: 32,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF64748B),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: widget.onToggleWidth,
                            icon: Icon(
                              widget.isWide ? Icons.fullscreen_exit : Icons.fullscreen,
                              size: 18,
                            ),
                            tooltip: widget.isWide ? 'Narrow' : 'Wide',
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 32,
                        width: 32,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            foregroundColor: const Color(0xFF64748B),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: widget.onHide,
                          icon: const Icon(
                            Icons.visibility_off_outlined,
                            size: 16,
                          ),
                          tooltip: 'Hide',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: boxWidth,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: widget.selectedOwner,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                hint: const Text('All Owners', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF64748B))),
                                items: [
                                  const DropdownMenuItem<String?>(value: null, child: Text('All Owners')),
                                  ...widget.owners.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o))),
                                ],
                                onChanged: widget.onOwnerChanged,
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
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.horizontal(
                                left: const Radius.circular(10),
                                right: hasDateFilter ? Radius.zero : const Radius.circular(10),
                              ),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
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
                                      const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF582F95)),
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
                                                ? const Color(0xFF1E293B)
                                                : const Color(0xFF64748B),
                                            fontWeight: hasDateFilter
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!hasDateFilter)
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF94A3B8)),
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
                              color: const Color(0xFFE2E8F0),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
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
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              widget.pools.keys.isEmpty
                  ? const Text('No pools available.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.pools.keys.where((k) {
                        if (_visiblePools[k] == false) return false;
                        if (_showOnlyFunded) {
                          double bal = 0;
                          for (var tx in widget.transactions) {
                            if (tx.pool.toLowerCase() == k.toLowerCase() && tx.isConfirmed == 1) {
                              bal += (tx.type == 'income' ? tx.amount : -tx.amount);
                            }
                          }
                          if (bal <= 0) return false;
                        }
                        return true;
                      }).length,
                      itemBuilder: (context, index) {
                        String poolKey = widget.pools.keys.where((k) {
                          if (_visiblePools[k] == false) return false;
                          if (_showOnlyFunded) {
                            double bal = 0;
                            for (var tx in widget.transactions) {
                              if (tx.pool.toLowerCase() == k.toLowerCase() && tx.isConfirmed == 1) {
                                bal += (tx.type == 'income' ? tx.amount : -tx.amount);
                              }
                            }
                            if (bal <= 0) return false;
                          }
                          return true;
                        }).toList()[index];
                        return _buildPoolMiniSection(poolKey, now);
                      },
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPoolMiniSection(String poolKey, DateTime now) {
    // Fully linked setting for effective start date if widget.startDate is not explicitly provided
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

      // Fully linked setting for future zaznams visibility toggle
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

    double initialBalance = 0;
    if (effectiveStartDate != null) {
      final startClean = DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day);
      for (var tx in widget.transactions) {
        if (tx.pool.toLowerCase() != poolKey.toLowerCase()) continue;
        if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && tx.owner != widget.selectedOwner) continue;
        final txDate = DateTime.tryParse(tx.createdAt);
        if (txDate != null && txDate.isBefore(startClean)) {
          if (tx.isConfirmed == 1) {
            initialBalance += (tx.type == 'income' ? tx.amount : -tx.amount);
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

    for (int i = 0; i < sortedTxs.length; i++) {
      final t = sortedTxs[i];
      if (t.isConfirmed == 1) {
        runningTotal += (t.type == 'income' ? t.amount : -t.amount);
      }
      final txDate = DateTime.tryParse(t.createdAt) ?? now;
      spots.add(FlSpot(i.toDouble(), runningTotal));
      spotDates.add(txDate);
    }

    if (spots.length == 1) {
      spots.insert(0, FlSpot(0, spots[0].y - (sortedTxs[0].type == 'income' ? sortedTxs[0].amount : -sortedTxs[0].amount)));
      spotDates.insert(0, spotDates[0].subtract(const Duration(days: 1)));
    } else if (spots.isEmpty) {
      spots.add(const FlSpot(0, 0));
      spotDates.add(now);
    }

    double poolBalance = runningTotal;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                poolKey.toUpperCase(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Text(
                _formatCurrency(poolBalance, _primaryCurrency),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: poolBalance >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
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
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF582F95),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF582F95).withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}