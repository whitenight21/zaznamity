// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class FutureMetricsCard extends StatefulWidget {
  final List<String> owners;
  final String? selectedOwner;
  final List<String> pools;
  final String? selectedPool;
  final Map<String, double> futureFlowByOwner;
  final double totalFutureFlow;
  final Map<String, double> prognosisByOwner;
  final double totalPrognosis;

  final Map<String, double>? currentBalanceByOwner;
  final double? totalCurrentBalance;
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime?, DateTime?)? onDateRangeChanged;
  final VoidCallback onClearDateFilter;
  final Function(DateTime start, DateTime end)? onShowPendingZaznams; // Updated to pass 7-day window
  final VoidCallback? onShow30DayShiftZaznams;
  final Function(String?)? onPoolChanged;
  final VoidCallback? onJumpToAnalytics; // Quick-jump bridge to Future Analytics card

  const FutureMetricsCard({
    super.key,
    required this.owners,
    this.selectedOwner,
    required this.pools,
    this.selectedPool,
    required this.futureFlowByOwner,
    required this.totalFutureFlow,
    required this.prognosisByOwner,
    required this.totalPrognosis,
    this.currentBalanceByOwner,
    this.totalCurrentBalance,
    required this.transactions,
    this.labels = const [],
    this.startDate,
    this.endDate,
    this.onDateRangeChanged,
    required this.onClearDateFilter,
    this.onShowPendingZaznams,
    this.onShow30DayShiftZaznams,
    this.onPoolChanged,
    this.onJumpToAnalytics,
  });

  @override
  State<FutureMetricsCard> createState() => _FutureMetricsCardState();
}

class _FutureMetricsCardState extends State<FutureMetricsCard> {
  late String _selectedOwner;
  late String _selectedPool;
  String _burnRateBaseline = 'Last 90 Days';
  bool _isZaznamityMode = true;
  bool _excludeTransfers = true;
  String _primaryCurrency = 'USD';
  bool _isCollapsed = false;
  Map<Object?, String> _labelNames = {};

  @override
  void initState() {
    super.initState();
    _rebuildLabelNames();
    _selectedOwner = widget.selectedOwner ?? 'All Owners';
    _selectedPool = widget.selectedPool ?? 'All Pools';
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _burnRateBaseline = prefs.getString('set_burn_rate_baseline') ?? 'Last 90 Days';
        _excludeTransfers = prefs.getBool('exclude_transfers_insights') ?? true;
        _primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';
        _isCollapsed = prefs.getBool('set_futureMetrics_collapsed') ?? false;
      });
    }
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_futureMetrics_collapsed', _isCollapsed);
  }

  @override
  void didUpdateWidget(covariant FutureMetricsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebuildLabelNames();
    if (widget.selectedOwner != oldWidget.selectedOwner) {
      setState(() {
        _selectedOwner = widget.selectedOwner ?? 'All Owners';
      });
    }
    if (widget.selectedPool != oldWidget.selectedPool) {
      setState(() {
        _selectedPool = widget.selectedPool ?? 'All Pools';
      });
    }
    _loadPrefs();
  }

  String _getCurrencySymbol() {
    switch (_primaryCurrency) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      case 'CNY': return '¥';
      case 'AUD': return 'A\$';
      case 'CAD': return 'C\$';
      case 'CHF': return 'CHF ';
      case 'HKD': return 'HK\$';
      case 'SGD': return 'S\$';
      default: return '\$';
    }
  }

  String _formatCurrency(double amount) {
    final symbol = _getCurrencySymbol();
    final format = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return format.format(amount);
  }

  String _getLastZaznamDateString() {
    if (widget.transactions.isEmpty) return 'N/A';
    
    DateTime? latestDate;
    for (var tx in widget.transactions) {
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt != null) {
        if (latestDate == null || dt.isAfter(latestDate)) {
          latestDate = dt;
        }
      }
    }
    
    if (latestDate == null) return 'N/A';
    return DateFormat('yyyy-MM-dd').format(latestDate);
  }

  static const Set<String> _nonSpendingLabels = {'transfer', 'goals', 'goalssavings'};
  static const List<String> _transferDescriptionPrefixes = [
    'transfer out',
    'transfer in',
    'withdrawal from',
    'deposit into',
  ];

  void _rebuildLabelNames() {
    _labelNames = {for (final l in widget.labels) l.id: l.name};
  }

  bool _matchesOwner(TransactionModel tx) =>
      _selectedOwner == 'All Owners' || tx.owner == _selectedOwner;

  bool _matchesPool(TransactionModel tx) =>
      _selectedPool == 'All Pools' || tx.pool.toLowerCase() == _selectedPool.toLowerCase();

  bool _matchesFilters(TransactionModel tx) => _matchesOwner(tx) && _matchesPool(tx);

  bool _isTransferLike(TransactionModel tx) {
    if (!_excludeTransfers) return false;

    final savingsFlag = '${tx.isSavings}';
    if (savingsFlag == '1' || savingsFlag == 'true') return true;

    final labelName = _labelNames[tx.labelId];
    if (labelName != null &&
        _nonSpendingLabels.contains(labelName.toLowerCase().replaceAll(' ', ''))) {
      return true;
    }

    final desc = '${tx.description}'.toLowerCase().trim();
    return _transferDescriptionPrefixes.any(desc.startsWith);
  }

  bool _includeInHistory(TransactionModel tx) =>
      tx.isConfirmed == 1 && _matchesFilters(tx) && !_isTransferLike(tx);

  bool _includeInForecast(TransactionModel tx) =>
      _matchesFilters(tx) && !_isTransferLike(tx);

  double _signedAmount(TransactionModel tx) {
    if (tx.type == 'income') return tx.amount;
    if (tx.type == 'expense') return -tx.amount;
    return 0.0;
  }

  double _currentLiquidBalance() {
    double balance = 0.0;
    for (var tx in widget.transactions) {
      if (!_matchesFilters(tx)) continue;
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt == null || dt.isAfter(DateTime.now())) continue;
      if (tx.isConfirmed == 1) {
        balance += _signedAmount(tx);
      }
    }
    return balance;
  }

  double _calculateMonthlyBurn() {
    final now = DateTime.now();
    int baselineDays = 90;
    if (_burnRateBaseline == 'Last 30 Days') {
      baselineDays = 30;
    } else if (_burnRateBaseline == 'Last 90 Days') {
      baselineDays = 90;
    } else if (_burnRateBaseline == 'Fixed Baseline') {
      baselineDays = 365;
    }
    final pastLimit = now.subtract(Duration(days: baselineDays));

    double totalExpense = 0;
    DateTime? firstDate;

    for (final tx in widget.transactions) {
      if (!_includeInHistory(tx)) continue;

      final dt = DateTime.tryParse(tx.createdAt);
      if (dt == null || dt.isAfter(now)) continue;

      if (firstDate == null || dt.isBefore(firstDate)) firstDate = dt;

      if (dt.isAfter(pastLimit)) {
        if (tx.type == 'expense') totalExpense += tx.amount;
      }
    }

    final historyDays = firstDate == null ? baselineDays : now.difference(firstDate).inDays + 1;
    final effectiveDays = math.min(baselineDays, math.max(7, historyDays));
    final monthsDiv = effectiveDays / 30.0;

    return totalExpense > 0 ? totalExpense / monthsDiv : 0.0;
  }

  double _calculate30DayNetShift() {
    final now = DateTime.now();
    final next30Days = now.add(const Duration(days: 30));
    double netShift = 0.0;

    for (final tx in widget.transactions) {
      if (!_includeInForecast(tx)) continue;
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt != null && dt.isAfter(now) && dt.isBefore(next30Days)) {
        netShift += _signedAmount(tx);
      }
    }
    return netShift;
  }

  int _calculateUpcomingScheduledCount() {
    final now = DateTime.now();
    final next7Days = now.add(const Duration(days: 7));
    int count = 0;

    for (final tx in widget.transactions) {
      if (!_matchesFilters(tx)) continue;
      final dt = DateTime.tryParse(tx.createdAt);
      // Strictly check: future date within 7 days AND explicitly unconfirmed (isConfirmed != 1)
      if (dt != null && dt.isAfter(now) && dt.isBefore(next7Days) && tx.isConfirmed != 1) {
        count++;
      }
    }
    return count;
  }

  ({int days, DateTime? date, double amount})? _calculateNextIncomeInfo() {
    final now = DateTime.now();
    DateTime? nextDate;
    double nextAmount = 0.0;

    for (final tx in widget.transactions) {
      if (!_matchesFilters(tx)) continue;
      if (tx.type != 'income') continue;
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt != null && dt.isAfter(now)) {
        if (nextDate == null || dt.isBefore(nextDate)) {
          nextDate = dt;
          nextAmount = tx.amount;
        }
      }
    }

    if (nextDate == null) return null;
    final days = nextDate.difference(now).inDays;
    return (days: days < 0 ? 0 : days, date: nextDate, amount: nextAmount);
  }

  List<({DateTime date, double amount, String description})> _getTopThreeUpcomingBills() {
    final now = DateTime.now();
    final bills = <({DateTime date, double amount, String description})>[];

    for (final tx in widget.transactions) {
      if (!_includeInForecast(tx)) continue;
      if (tx.type != 'expense') continue;
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt == null || !dt.isAfter(now)) continue;

      bills.add((date: dt, amount: tx.amount, description: tx.description ?? 'Expense'));
    }

    bills.sort((a, b) {
      int amountComparison = b.amount.compareTo(a.amount);
      if (amountComparison != 0) {
        return amountComparison;
      }
      return a.date.compareTo(b.date);
    });

    return bills.take(3).toList();
  }

  Map<String, dynamic> _calculateRunwayDepletionInfo(double monthlyBurn) {
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 365));
    final startingBalance = _currentLiquidBalance();

    final scheduled = <({DateTime date, double net})>[];
    for (final tx in widget.transactions) {
      if (!_includeInForecast(tx)) continue;
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt == null || !dt.isAfter(now) || dt.isAfter(horizon)) continue;
      final net = _signedAmount(tx);
      if (net != 0) scheduled.add((date: dt, net: net));
    }
    scheduled.sort((a, b) => a.date.compareTo(b.date));

    double running = startingBalance;
    DateTime cursor = now;
    DateTime? deficitDate;

    if (running < 0) {
      deficitDate = now;
    } else {
      for (final item in scheduled) {
        running += item.net;
        cursor = item.date;
        if (running < 0) {
          deficitDate = item.date;
          break;
        }
      }
    }

    if (deficitDate == null) {
      final dailyBurn = monthlyBurn / 30.0;
      if (dailyBurn > 0) {
        final daysLeft = (running / dailyBurn).floor();
        final projected = cursor.add(Duration(days: daysLeft));
        if (projected.isBefore(horizon)) deficitDate = projected;
      }
    }

    return {
      'hasDeficit': deficitDate != null,
      'deficitDate': deficitDate,
      'startingBalance': startingBalance,
    };
  }

  void _showMetricInfo(BuildContext context, String title, String explanation) {
    final lastDateStr = _getLastZaznamDateString();
    final fullExplanation = '$explanation\n\nUnless a custom date range is specifically set, the default date range is based on all Zaznams until last Zaznam on $lastDateStr.\n\n';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))),
          ],
        ),
        content: Text(
          fullExplanation,
          style: TextStyle(fontSize: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569), height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: todayMidnight,
      lastDate: DateTime(2030),
      initialDateRange: (widget.startDate != null && widget.endDate != null)
          ? DateTimeRange(start: widget.startDate!, end: widget.endDate!)
          : null,
      builder: (context, child) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 1.0,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: child!,
              ),
            ),
          ),
        );
      },
    );

    if (picked != null && widget.onDateRangeChanged != null) {
      widget.onDateRangeChanged!(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 32;
        final double boxWidth = (fullWidth - 12) / 2;

        double calculatedFutureFlow = 0.0;
        final now = DateTime.now();
        final effectiveStart = widget.startDate ?? now;
        final effectiveEnd = widget.endDate;

        for (final tx in widget.transactions) {
          if (!_includeInForecast(tx)) continue;
          final dt = DateTime.tryParse(tx.createdAt);
          if (dt == null) continue;

          if (dt.isBefore(now)) continue;

          if (effectiveEnd != null) {
            if (dt.isAfter(effectiveStart.subtract(const Duration(days: 1))) && dt.isBefore(effectiveEnd.add(const Duration(days: 1)))) {
              calculatedFutureFlow += _signedAmount(tx);
            }
          } else {
            calculatedFutureFlow += _signedAmount(tx);
          }
        }

        double currentFutureFlow = calculatedFutureFlow;
        double currentLiquid = _currentLiquidBalance();
        double currentPrognosis = currentLiquid + currentFutureFlow;

        final monthlyBurn = _calculateMonthlyBurn();
        final net30Shift = _calculate30DayNetShift();
        final upcomingCount = _calculateUpcomingScheduledCount();
        final nextIncome = _calculateNextIncomeInfo();
        final topBills = _getTopThreeUpcomingBills();
        
        final runwayInfo = _calculateRunwayDepletionInfo(monthlyBurn);
        final DateTime? deficitDate = runwayInfo['deficitDate'];

        final daysToDeficit = deficitDate != null ? deficitDate.difference(now).inDays : 999;
        Color runwayColor;
        if (deficitDate != null && daysToDeficit < 30) {
          runwayColor = const Color(0xFFF87171); // Red
        } else if (deficitDate != null && daysToDeficit < 90) {
          runwayColor = const Color(0xFFF59E0B); // Yellow
        } else {
          runwayColor = const Color(0xFF34D399); // Green
        }

        final bool hasDateFilter = widget.startDate != null || widget.endDate != null;

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
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'FUTURE OUTLOOK ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _showMetricInfo(
                              context,
                              'Future Outlook ',
                              ' “Will I be okay?” - This card provides forward-looking financial forecasting and risk indicators.\n\n'
                              '• Basis of Calculation: Projections are computed using a combination of past historical Zaznams, future scheduled recurring/recorded entries, and average burn-rate modeling.\n'
                              '• Interpretation: Anticipate potential cash flow shortfalls, plan for upcoming expenses, and make informed financial decisions.\n'
                              '• Date Range: By default, this card considers all Zaznams up to the last recorded Zaznam. You can set a custom date range to focus on specific periods.\n'
                              '• Exclusions: Transfers and savings-related Zaznams are excluded from the calculations to provide a clearer picture of actual spendable cash flow.\n'
                              '• Burn Rate Baseline: The burn rate is calculated based on the selected baseline period (Last 30 Days, Last 90 Days, or Fixed Baseline). Adjusting this can provide different perspectives on your spending habits.\n'
                              '• Next 7-day Pending Zaznams: The number of scheduled Zaznams in the next 7 days and clicking the link will allow you to view them in "All Zaznams".\n'
                              '• This card is connected to the "Future Breakdown" card, which provides a more detailed breakdown of these metrics by labels and in bar chart form.',
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Icon(Icons.info_outline_rounded, size: 15, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onJumpToAnalytics != null) ...[
                          Tooltip(
                            message: 'Jump to Future Analytics',
                            child: InkWell(
                              onTap: widget.onJumpToAnalytics,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                height: 28,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: _isZaznamityMode ? const Color(0xFF3D256B) : const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _isZaznamityMode ? const Color(0xFFA855F7).withValues(alpha: 0.4) : const Color(0xFFDDD6FE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.pie_chart_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Analytics',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
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
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedPool,
                                  isDense: true,
                                  isExpanded: true,
                                  dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                  items: [
                                    DropdownMenuItem(value: 'All Pools', child: Text('All Pools', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                    ...widget.pools.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase(), style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedPool = val);
                                      if (widget.onPoolChanged != null) {
                                        widget.onPoolChanged!(val == 'All Pools' ? null : val);
                                      }
                                    }
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
                                  onTap: () => _pickDateRange(context),
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
                                            hasDateFilter
                                                ? '${DateFormat('MM/dd').format(widget.startDate!)} - ${DateFormat('MM/dd').format(widget.endDate!)}'
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

                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                      const SizedBox(width: 6),
                      Text('Burn Rate Basis:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade700)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _burnRateBaseline,
                            isDense: true,
                            isExpanded: true,
                            dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                            items: ['Last 30 Days', 'Last 90 Days', 'Fixed Baseline'].map((b) => DropdownMenuItem(value: b, child: Text(b, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))).toList(),
                            onChanged: (val) async {
                              if (val != null) {
                                setState(() => _burnRateBaseline = val);
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('set_burn_rate_baseline', val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: _buildMetricBox(
                          title: 'FUTURE FLOW',
                          amount: currentFutureFlow,
                          amountColor: currentFutureFlow >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                          width: boxWidth,
                          infoExplanation: 'Future Flow calculates the net sum of all scheduled incoming and outgoing transactions (income minus expenses) for the selected pool within your timeframe from today forward.',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _buildMetricBox(
                          title: 'PROGNOSIS',
                          amount: currentPrognosis,
                          amountColor: _isZaznamityMode ? Colors.white : const Color(0xFF000000),
                          width: boxWidth,
                          infoExplanation: 'Prognosis calculates your projected remaining balance for the selected pool at the end of the timeframe by combining current liquid funds with upcoming future cashflows from today forward.',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: runwayColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: runwayColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            daysToDeficit < 90 ? Icons.warning_rounded : Icons.shield_rounded,
                            size: 16,
                            color: runwayColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RUNWAY DEPLETION DATE:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _showMetricInfo(
                              context,
                              'RUNWAY DEPLETION DATE',
                              'Starts from your current liquid balance and applies scheduled income and expenses in date order, extending using your burn rate basis. Alerts red if <30 days, yellow if <90 days, green if >180 days.',
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        deficitDate != null ? DateFormat('MMM dd, yyyy').format(deficitDate) : 'Stable (> 1 Year)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: runwayColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward_rounded, size: 16, color: Color(0xFF34D399)),
                          const SizedBox(width: 8),
                          Text(
                            'NEXT INCOME:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        nextIncome != null
                            ? 'in ${nextIncome.days} days (${DateFormat('MMM dd').format(nextIncome.date!)}) • ${_formatCurrency(nextIncome.amount)}'
                            : 'No scheduled income',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: nextIncome != null ? const Color(0xFF34D399) : (_isZaznamityMode ? Colors.white54 : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFFF87171)),
                          const SizedBox(width: 8),
                          Text(
                            'NEXT 3 BIGGEST BILLS:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      topBills.isEmpty
                          ? Text('No upcoming scheduled bills', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white38 : Colors.grey))
                          : Column(
                              children: topBills.map((bill) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '• ${bill.description} (${DateFormat('MMM dd').format(bill.date)})',
                                          style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF334155)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(bill.amount),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF87171)),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onShow30DayShiftZaznams,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  net30Shift >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                  size: 16,
                                  color: net30Shift >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'NEXT 30-DAY CASH SHIFT :',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${net30Shift >= 0 ? '+' : ''}${_formatCurrency(net30Shift)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: net30Shift >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Updated Pending Zaznams tap action to pass the next 7 days window (excluding past zaznams)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (widget.onShowPendingZaznams != null) {
                          final nowTime = DateTime.now();
                          final next7Days = nowTime.add(const Duration(days: 7));
                          widget.onShowPendingZaznams!(nowTime, next7Days);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.notification_important_rounded, size: 16, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 8),
                                Text(
                                  'NEXT 7-DAY PENDING ZAZNAMS :',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$upcomingCount Pending',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: upcomingCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF34D399),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricBox({
    required String title,
    required double amount,
    required Color amountColor,
    required double width,
    required String infoExplanation,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _showMetricInfo(context, title, infoExplanation),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatCurrency(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: amountColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}