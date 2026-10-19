// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';

class FutureMetricsCard extends StatefulWidget {
  final List<String> owners;
  final String? selectedOwner;
  final Map<String, double> futureFlowByOwner;
  final double totalFutureFlow;
  final Map<String, double> prognosisByOwner;
  final double totalPrognosis;
  final List<TransactionModel> transactions;
  
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime?, DateTime?)? onDateRangeChanged;
  final VoidCallback onClearDateFilter;

  final bool isWide;
  final VoidCallback? onToggleWidth;
  final VoidCallback? onHide;

  const FutureMetricsCard({
    super.key,
    required this.owners,
    this.selectedOwner,
    required this.futureFlowByOwner,
    required this.totalFutureFlow,
    required this.prognosisByOwner,
    required this.totalPrognosis,
    required this.transactions,
    this.startDate,
    this.endDate,
    this.onDateRangeChanged,
    required this.onClearDateFilter,
    this.isWide = false,
    this.onToggleWidth,
    this.onHide,
  });

  @override
  State<FutureMetricsCard> createState() => _FutureMetricsCardState();
}

class _FutureMetricsCardState extends State<FutureMetricsCard> {
  late String _selectedOwner;
  String _dateRangeSetting = '90 Days';
  bool _isZaznamityMode = true;

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
      });
    }
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

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return format.format(amount);
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

  void _showMetricInfo(BuildContext context, String title, String explanation) {
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
          explanation,
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

        final bool hasDateFilter = widget.startDate != null || widget.endDate != null;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: _isZaznamityMode
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF3B1E63),
                      Color(0xFF160D25),
                      Color(0xFF000000),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onToggleWidth != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: SizedBox(
                            height: 28,
                            width: 28,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                                foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: widget.onToggleWidth,
                              icon: Icon(
                                widget.isWide ? Icons.fullscreen_exit : Icons.fullscreen,
                                size: 16,
                              ),
                              tooltip: widget.isWide ? 'Narrow' : 'Wide',
                            ),
                          ),
                        ),
                      if (widget.onHide != null)
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
                            onPressed: widget.onHide,
                            icon: const Icon(
                              Icons.visibility_off_outlined,
                              size: 14,
                            ),
                            tooltip: 'Hide',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
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
                      infoExplanation: 'Future Flow calculates the net sum of all scheduled incoming and outgoing transactions (income minus expenses) dated after today.',
                    ),
                  ),
                  SizedBox(
                    width: boxWidth,
                    child: _buildMetricBox(
                      title: 'PROGNOSIS',
                      amount: currentPrognosis,
                      amountColor: _isZaznamityMode ? Colors.white : const Color(0xFF000000),
                      width: boxWidth,
                      infoExplanation: 'Prognosis estimates your projected balance trajectory over time by combining current liquid funds with upcoming future cashflows.',
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
                      infoExplanation: 'Monthly Burn Rate represents your average monthly baseline spending calculated over your configured timeframe setting.',
                    ),
                  ),
                  SizedBox(
                    width: boxWidth,
                    child: _buildSavingsRateBox(
                      title: 'SAVINGS RATE',
                      savingsRate: savingsRate,
                      width: boxWidth,
                      infoExplanation: 'Savings Rate shows the exact percentage of your monthly income that you successfully retain rather than spend, based on your configured timeframe setting.',
                    ),
                  ),
                ],
              ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade600,
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade600,
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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