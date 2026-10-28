// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class FutureMetricsCard extends StatefulWidget {
  final List<String> owners;
  final String? selectedOwner;
  final Map<String, double> futureFlowByOwner;
  final double totalFutureFlow;
  final Map<String, double> prognosisByOwner;
  final double totalPrognosis;
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime?, DateTime?)? onDateRangeChanged;
  final VoidCallback onClearDateFilter;
  final VoidCallback? onShowPendingZaznams;

  const FutureMetricsCard({
    super.key,
    required this.owners,
    this.selectedOwner,
    required this.futureFlowByOwner,
    required this.totalFutureFlow,
    required this.prognosisByOwner,
    required this.totalPrognosis,
    required this.transactions,
    this.labels = const [],
    this.startDate,
    this.endDate,
    this.onDateRangeChanged,
    required this.onClearDateFilter,
    this.onShowPendingZaznams,
  });

  @override
  State<FutureMetricsCard> createState() => _FutureMetricsCardState();
}

class _FutureMetricsCardState extends State<FutureMetricsCard> {
  late String _selectedOwner;
  String _dateRangeSetting = '90 Days';
  bool _isZaznamityMode = true;
  bool _excludeTransfers = true;
  String _primaryCurrency = 'USD';
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _selectedOwner = widget.selectedOwner ?? 'All Owners';
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _dateRangeSetting = prefs.getString('set_futureMetrics_range') ?? '90 Days';
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
    if (widget.selectedOwner != oldWidget.selectedOwner) {
      setState(() {
        _selectedOwner = widget.selectedOwner ?? 'All Owners';
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

  Map<String, double> _calculateBurnAndSavingsRate() {
    double totalIncome = 0;
    double totalExpense = 0;
    final now = DateTime.now();
    
    int baselineDays = 90;
    if (_dateRangeSetting == '30 Days') baselineDays = 30;
    else if (_dateRangeSetting == '1 Year' || _dateRangeSetting == 'Next 1 Year') baselineDays = 365;

    final pastLimit = now.subtract(Duration(days: baselineDays));

    for (var tx in widget.transactions) {
      if (tx.isConfirmed != 1) continue;
      if (_selectedOwner != 'All Owners' && tx.owner != _selectedOwner) continue;

      if (_excludeTransfers && widget.labels.isNotEmpty) {
        final matchLbl = widget.labels.where((l) => l.id == tx.labelId).firstOrNull;
        if (matchLbl != null && matchLbl.name.toLowerCase() == 'transfer') {
          continue;
        }
      }

      final dt = DateTime.tryParse(tx.createdAt) ?? now;
      if (dt.isAfter(pastLimit)) {
        if (tx.type == 'income') totalIncome += tx.amount;
        if (tx.type == 'expense') totalExpense += tx.amount;
      }
    }

    double monthsDiv = baselineDays / 30.0;
    if (monthsDiv < 1) monthsDiv = 1.0;

    double monthlyBurn = totalExpense > 0 ? (totalExpense / monthsDiv) : 0.0;
    double monthlyIncome = totalIncome > 0 ? (totalIncome / monthsDiv) : 0.0;
    double savingsRate = monthlyIncome > 0 ? ((monthlyIncome - monthlyBurn) / monthlyIncome) * 100 : 0.0;

    return {
      'burnRate': monthlyBurn,
      'savingsRate': savingsRate.clamp(-100.0, 100.0),
    };
  }

  double _calculate30DayNetShift() {
    final now = DateTime.now();
    final next30Days = now.add(const Duration(days: 30));
    double netShift = 0.0;

    for (var tx in widget.transactions) {
      if (_selectedOwner != 'All Owners' && tx.owner != _selectedOwner) continue;
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt != null && dt.isAfter(now) && dt.isBefore(next30Days)) {
        if (tx.type == 'income') {
          netShift += tx.amount;
        } else if (tx.type == 'expense') {
          netShift -= tx.amount;
        }
      }
    }

    return netShift;
  }

  int _calculateUpcomingScheduledCount() {
    final now = DateTime.now();
    final next7Days = now.add(const Duration(days: 7));
    int count = 0;

    for (var tx in widget.transactions) {
      if (_selectedOwner != 'All Owners' && tx.owner != _selectedOwner) continue;
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt != null && dt.isAfter(now) && dt.isBefore(next7Days)) {
        if (tx.isConfirmed != 1) {
          count++;
        }
      }
    }
    return count;
  }

  Map<String, dynamic> _calculateRunwayDepletionInfo() {
    final now = DateTime.now();
    
    double startingBalance = _selectedOwner == 'All Owners'
        ? widget.totalPrognosis
        : (widget.prognosisByOwner[_selectedOwner] ?? 0.0);

    List<Map<String, dynamic>> scheduledTxs = [];
    for (var tx in widget.transactions) {
      if (_selectedOwner != 'All Owners' && tx.owner != _selectedOwner) continue;
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt != null && dt.isAfter(now)) {
        double amt = tx.amount;
        scheduledTxs.add({
          'date': dt,
          'netAmount': tx.type == 'income' ? amt : -amt,
          'description': tx.description,
        });
      }
    }

    scheduledTxs.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    double runningBalance = startingBalance;
    DateTime? deficitDate;

    for (var item in scheduledTxs) {
      final DateTime dt = item['date'];
      final double netAmt = item['netAmount'];
      runningBalance += netAmt;

      if (runningBalance < 0) {
        deficitDate = dt;
        break;
      }
    }

    if (deficitDate == null && scheduledTxs.isEmpty) {
      final burnAndSavings = _calculateBurnAndSavingsRate();
      final monthlyBurn = burnAndSavings['burnRate'] ?? 0.0;
      final dailyBurn = monthlyBurn / 30.0;
      if (dailyBurn > 0 && startingBalance > 0) {
        int daysLeft = (startingBalance / dailyBurn).floor();
        deficitDate = now.add(Duration(days: daysLeft));
      }
    }

    return {
      'hasDeficit': deficitDate != null || startingBalance < 0,
      'deficitDate': deficitDate,
      'startingBalance': startingBalance,
    };
  }

  void _showMetricInfo(BuildContext context, String title, String explanation) {
    final lastDateStr = _getLastZaznamDateString();
    final fullExplanation = '$explanation\n\nBy default based on all Zaznams until last Zaznam on $lastDateStr.';

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
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
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

        double currentFutureFlow = _selectedOwner == 'All Owners'
            ? widget.totalFutureFlow
            : (widget.futureFlowByOwner[_selectedOwner] ?? 0.0);

        double currentPrognosis = _selectedOwner == 'All Owners'
            ? widget.totalPrognosis
            : (widget.prognosisByOwner[_selectedOwner] ?? 0.0);

        final burnAndSavings = _calculateBurnAndSavingsRate();
        final monthlyBurn = burnAndSavings['burnRate'] ?? 0.0;
        final savingsRate = burnAndSavings['savingsRate'] ?? 0.0;
        final net30Shift = _calculate30DayNetShift();
        final upcomingCount = _calculateUpcomingScheduledCount();
        
        final runwayInfo = _calculateRunwayDepletionInfo();
        final DateTime? deficitDate = runwayInfo['deficitDate'];

        final bool hasDateFilter = widget.startDate != null || widget.endDate != null;

        return Container(
          padding: const EdgeInsets.all(16),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'FUTURE METRICS',
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
                            'ABOUT FUTURE METRICS & PREDICTIONS',
                            'This card aggregates forward-looking financial forecasting and risk indicators.\n\n• Nature of Data: These figures represent predictive modeling and trend extrapolations rather than absolute certainties.\n• Basis of Calculation: Projections are computed using a combination of past historical Zaznams, future scheduled recurring/recorded entries, and average burn-rate modeling.\n• Disclaimer: Actual financial outcomes may differ due to unexpected expenses or variable income shifts. This tool provides analytical insight and does not constitute certified professional financial advice.',
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
                              _selectedOwner,
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
                            Icon(Icons.person_outline_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedOwner,
                                  isDense: true,
                                  isExpanded: true,
                                  dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                  items: [
                                    DropdownMenuItem(value: 'All Owners', child: Text('All Owners', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                    ...widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedOwner = val);
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

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: boxWidth,
                      child: _buildMetricBox(
                        title: 'FUTURE FLOW',
                        amount: currentFutureFlow,
                        amountColor: currentFutureFlow >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        width: boxWidth,
                        infoExplanation: 'Future Flow calculates the net sum of all scheduled incoming and outgoing transactions (income minus expenses) dated after today.\n\nHow to use & relevance: Use this metric to immediately gauge whether your scheduled cash flow for upcoming days is net positive or negative, helping you anticipate shortfalls before they occur.',
                      ),
                    ),
                    SizedBox(
                      width: boxWidth,
                      child: _buildMetricBox(
                        title: 'PROGNOSIS',
                        amount: currentPrognosis,
                        amountColor: _isZaznamityMode ? Colors.white : const Color(0xFF000000),
                        width: boxWidth,
                        infoExplanation: 'Prognosis estimates your projected balance trajectory over time by combining current liquid funds with upcoming future cashflows.\n\nHow to use & relevance: Provides a comprehensive long-term view of your financial trajectory, combining current holdings with expected future earnings and bills.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: boxWidth,
                      child: _buildMetricBox(
                        title: 'MONTHLY BURN RATE',
                        amount: monthlyBurn,
                        amountColor: const Color(0xFFF87171),
                        width: boxWidth,
                        infoExplanation: 'Monthly Burn Rate represents your average monthly baseline spending calculated over your configured timeframe setting.\n\nHow to use & relevance: Essential for understanding your baseline overhead and determining how quickly your cash reserves deplete each month.',
                      ),
                    ),
                    SizedBox(
                      width: boxWidth,
                      child: _buildSavingsRateBox(
                        title: 'SAVINGS RATE',
                        savingsRate: savingsRate,
                        width: boxWidth,
                        infoExplanation: 'Savings Rate shows the exact percentage of your monthly income that you successfully retain rather than spend, based on your configured timeframe setting.\n\nHow to use & relevance: Helps track your wealth-building efficiency. A rate above 20% indicates healthy financial retention, while negative rates signal that spending exceeds earnings.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: deficitDate != null 
                        ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) 
                        : (_isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: deficitDate != null ? const Color(0xFFF87171) : (_isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            deficitDate != null ? Icons.warning_rounded : Icons.shield_rounded,
                            size: 16,
                            color: deficitDate != null ? const Color(0xFFF87171) : const Color(0xFF34D399),
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
                              'Scans your scheduled outflows against your liquid checking balance to project the exact calendar date you might hit a cash deficit if no income arrives.\n\nActs as an early-warning radar for liquidity crunches, allowing you to plan ahead and avoid surprises.',
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
                          color: deficitDate != null ? const Color(0xFFF87171) : const Color(0xFF34D399),
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
                          Icon(
                            net30Shift >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            size: 16,
                            color: net30Shift >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'NEXT 30-DAY CASH SHIFT:',
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
                              'NEXT 30-DAY CASH SHIFT',
                              'Calculates the absolute net change in your liquid cash over the next 30 days by combining both incoming scheduled cashflows (income) and outgoing pending cashflows (expenses/bills).\n\nThis gives you a precise 30-day tactical window to see if your upcoming salary covers your near-term liabilities.',
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
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
                      onTap: widget.onShowPendingZaznams,
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
                                  'PENDING ZAZNAMS (NEXT 7 DAYS):',
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
                                    'PENDING ZAZNAMS (NEXT 7 DAYS)',
                                    'Shows the total number of unconfirmed scheduled zaznams or bills coming due within the next 7 days, helping you stay ahead of upcoming payments.\n\nClicking on this row takes you directly to the All Zaznams card and displays exactly those pending Zaznams within 7 days for quick confirmation.',
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2.0),
                                    child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
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

  Widget _buildSavingsRateBox({
    required String title,
    required double savingsRate,
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
              '${savingsRate.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: savingsRate >= 20 ? const Color(0xFF34D399) : const Color(0xFFF87171),
              ),
            ),
          ),
        ],
      ),
    );
  }
}