// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class IncomeExpensesByLabelsCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? selectedOwner;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final ValueChanged<String?> onOwnerChanged;
  final VoidCallback onClearDateFilter;
  final VoidCallback? onHide;
  final bool isWide;
  final VoidCallback? onToggleWidth;

  const IncomeExpensesByLabelsCard({
    super.key,
    required this.transactions,
    required this.labels,
    required this.owners,
    this.startDate,
    this.endDate,
    this.selectedOwner,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onOwnerChanged,
    required this.onClearDateFilter,
    this.onHide,
    this.isWide = false,
    this.onToggleWidth,
  });

  @override
  State<IncomeExpensesByLabelsCard> createState() => _IncomeExpensesByLabelsCardState();
}

class _IncomeExpensesByLabelsCardState extends State<IncomeExpensesByLabelsCard> {
  String chartDisplayMode = 'Show Expenses';
  String chartType = 'Bar'; // 'Bar', 'Donut', or '3D Donut'
  int? touchedPieIndex;
  
  final Set<int> selectedIncomeLabels = {};
  final Set<int> selectedExpenseLabels = {};
  bool _initializedLabels = false;
  String? _localOwner;

  // --- Memoization Cache Fields ---
  double _cachedTotalIncome = 0;
  double _cachedTotalExpenses = 0;
  List<MapEntry<String, double>> _cachedSortedEntries = [];
  double _cachedActiveModeTotalSum = 0;
  double _cachedMaxTopAmount = 1.0;
  double _cachedMaxChartAmount = 1.0;

  int? _lastTxLength;
  String? _lastOwner;
  DateTime? _lastStartDate;
  DateTime? _lastEndDate;
  String? _lastDisplayMode;
  String _lastIncomeLabelsKey = '';
  String _lastExpenseLabelsKey = '';

  @override
  void initState() {
    super.initState();
    _localOwner = widget.selectedOwner;
  }

  @override
  void didUpdateWidget(covariant IncomeExpensesByLabelsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOwner != oldWidget.selectedOwner) {
      setState(() {
        _localOwner = widget.selectedOwner;
      });
    }
  }

  void _computeDataIfNeeded() {
    final activeOwner = widget.selectedOwner ?? _localOwner;
    final incomeLabelsKey = selectedIncomeLabels.join(',');
    final expenseLabelsKey = selectedExpenseLabels.join(',');

    if (_lastTxLength == widget.transactions.length &&
        _lastOwner == activeOwner &&
        _lastStartDate == widget.startDate &&
        _lastEndDate == widget.endDate &&
        _lastDisplayMode == chartDisplayMode &&
        _lastIncomeLabelsKey == incomeLabelsKey &&
        _lastExpenseLabelsKey == expenseLabelsKey) {
      return;
    }

    final filteredTransactions = widget.transactions.where((tx) {
      if (activeOwner != null && tx.owner != activeOwner) {
        return false;
      }
      final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
      if (widget.startDate != null && txDate.isBefore(widget.startDate!)) {
        return false;
      }
      if (widget.endDate != null) {
        final endOfDay = DateTime(widget.endDate!.year, widget.endDate!.month, widget.endDate!.day, 23, 59, 59);
        if (txDate.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();

    double totalIncome = 0;
    double totalExpenses = 0;
    final Map<String, double> labelTotals = {};

    for (var tx in filteredTransactions) {
      if (tx.isConfirmed != 1) continue;
      
      final labelObj = widget.labels.firstWhere(
        (l) => l.id == tx.labelId,
        orElse: () => LabelModel(id: 0, name: 'General', color: '#4338CA'),
      );

      if (tx.type == 'income') {
        if (!selectedIncomeLabels.contains(labelObj.id)) continue;
        totalIncome += tx.amount;
        if (chartDisplayMode == 'Show Income') {
          labelTotals[labelObj.name] = (labelTotals[labelObj.name] ?? 0) + tx.amount;
        }
      } else {
        if (!selectedExpenseLabels.contains(labelObj.id)) continue;
        totalExpenses += tx.amount;
        if (chartDisplayMode == 'Show Expenses') {
          labelTotals[labelObj.name] = (labelTotals[labelObj.name] ?? 0) + tx.amount;
        }
      }
    }

    final sortedEntries = labelTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _cachedTotalIncome = totalIncome;
    _cachedTotalExpenses = totalExpenses;
    _cachedSortedEntries = sortedEntries;
    _cachedActiveModeTotalSum = sortedEntries.fold(0.0, (sum, entry) => sum + entry.value);
    _cachedMaxTopAmount = (totalIncome > totalExpenses ? totalIncome : totalExpenses) > 0 
        ? (totalIncome > totalExpenses ? totalIncome : totalExpenses) 
        : 1.0;
    _cachedMaxChartAmount = sortedEntries.isNotEmpty ? sortedEntries.first.value : 1.0;

    _lastTxLength = widget.transactions.length;
    _lastOwner = activeOwner;
    _lastStartDate = widget.startDate;
    _lastEndDate = widget.endDate;
    _lastDisplayMode = chartDisplayMode;
    _lastIncomeLabelsKey = incomeLabelsKey;
    _lastExpenseLabelsKey = expenseLabelsKey;
  }

  @override
  Widget build(BuildContext context) {
    if (!_initializedLabels && widget.labels.isNotEmpty) {
      for (var l in widget.labels) {
        selectedIncomeLabels.add(l.id);
        selectedExpenseLabels.add(l.id);
      }
      _initializedLabels = true;
    }

    _computeDataIfNeeded();

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final activeOwner = widget.selectedOwner ?? _localOwner;
    
    final paletteColors = [
      const Color(0xFF3B82F6),
      const Color(0xFFA855F7),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
      const Color(0xFF8B5CF6),
      const Color(0xFFEF4444),
    ];

    final bool hasDateFilter = widget.startDate != null || widget.endDate != null;

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
                      child: const Text(
                        'MULTI-LABEL ANALYTICS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 88, 47, 149),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onToggleWidth != null)
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
                      if (widget.onHide != null)
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
                                value: activeOwner,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                hint: const Text('All Owners', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF64748B))),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All Owners'),
                                  ),
                                  ...widget.owners.map((owner) => DropdownMenuItem<String?>(
                                        value: owner,
                                        child: Text(owner),
                                      )),
                                ],
                                onChanged: (val) {
                                  setState(() => _localOwner = val);
                                  widget.onOwnerChanged(val);
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
              const SizedBox(height: 20),

              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL INCOME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857), letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_cachedTotalIncome / _cachedMaxTopAmount).clamp(0.0, 1.0),
                            backgroundColor: const Color(0xDDA7F3D0),
                            color: const Color(0xFF10B981),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currencyFormat.format(_cachedTotalIncome),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL EXPENSES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C), letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_cachedTotalExpenses / _cachedMaxTopAmount).clamp(0.0, 1.0),
                            backgroundColor: const Color(0xDDFECACA),
                            color: const Color(0xFFEF4444),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currencyFormat.format(_cachedTotalExpenses),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Labels Picker (Left) & Type Dropdown (Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: boxWidth,
                    child: InkWell(
                      onTap: () => _showMultiSelectDialog(
                        context,
                        chartDisplayMode == 'Show Income' ? 'Select Income Labels' : 'Select Expense Labels',
                        widget.labels,
                        chartDisplayMode == 'Show Income' ? selectedIncomeLabels : selectedExpenseLabels,
                        (updatedIds) {
                          setState(() {
                            if (chartDisplayMode == 'Show Income') {
                              selectedIncomeLabels.clear();
                              selectedIncomeLabels.addAll(updatedIds);
                            } else {
                              selectedExpenseLabels.clear();
                              selectedExpenseLabels.addAll(updatedIds);
                            }
                          });
                        },
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.label_outline_rounded, size: 16, color: Color(0xFF582F95)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        (chartDisplayMode == 'Show Income' ? selectedIncomeLabels.length : selectedExpenseLabels.length) == widget.labels.length
                                            ? 'All Labels'
                                            : '${chartDisplayMode == 'Show Income' ? selectedIncomeLabels.length : selectedExpenseLabels.length} selected',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                          const Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: chartDisplayMode,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                items: const [
                                  DropdownMenuItem(value: 'Show Expenses', child: Text('Expense')),
                                  DropdownMenuItem(value: 'Show Income', child: Text('Income')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      chartDisplayMode = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Chart Type Selector moved right below labels/type row, above the graph
              Container(
                height: 38,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => chartType = 'Bar'),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: chartType == 'Bar' ? const Color(0xFFF8FAFC) : Colors.white,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                          ),
                          child: Text(
                            'Bar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: chartType == 'Bar' ? Colors.black : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => chartType = 'Donut'),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: chartType == 'Donut' ? const Color(0xFFF8FAFC) : Colors.white,
                          ),
                          child: Text(
                            'Donut',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: chartType == 'Donut' ? Colors.black : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => chartType = '3D Donut'),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: chartType == '3D Donut' ? const Color(0xFFF8FAFC) : Colors.white,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                          ),
                          child: Text(
                            '3D Donut',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: chartType == '3D Donut' ? Colors.black : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _cachedSortedEntries.isEmpty
                  ? const SizedBox(
                      height: 150,
                      child: Center(
                        child: Text('No data available for selected filters.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ),
                    )
                  : chartType == 'Bar'
                      ? Column(
                          children: [
                            ...List.generate(_cachedSortedEntries.length, (index) {
                              final entry = _cachedSortedEntries[index];
                              final barColor = paletteColors[index % paletteColors.length];
                              final double widthFactor = _cachedMaxChartAmount > 0 ? (entry.value / _cachedMaxChartAmount).clamp(0.02, 1.0) : 0.02;
                              final percentageShare = _cachedActiveModeTotalSum > 0 ? (entry.value / _cachedActiveModeTotalSum) * 100 : 0.0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 85,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            entry.key,
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${percentageShare.toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          const priceTextWidth = 75.0;
                                          final availableBarArea = constraints.maxWidth - priceTextWidth;
                                          final computedBarWidth = (availableBarArea * widthFactor).clamp(4.0, availableBarArea);

                                          return Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              SizedBox(
                                                width: computedBarWidth,
                                                child: Container(
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    color: barColor,
                                                    borderRadius: const BorderRadius.only(
                                                      topRight: Radius.circular(6),
                                                      bottomRight: Radius.circular(6),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: priceTextWidth,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerRight,
                                                  child: Text(
                                                    '\$${entry.value.toStringAsFixed(2)}',
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF334155),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            Container(
                              margin: const EdgeInsets.only(left: 97),
                              child: Column(
                                children: [
                                  Container(height: 1, color: const Color(0xFFE2E8F0)),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('\$0', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                      Text('\$${(_cachedMaxChartAmount * 0.5).toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                      Text('\$${_cachedMaxChartAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : chartType == '3D Donut'
                          ? Column(
                              children: [
                                SizedBox(
                                  height: 240,
                                  width: double.infinity,
                                  child: CustomPaint(
                                    painter: _3DGlassDonutChartPainter(
                                      entries: _cachedSortedEntries,
                                      totalSum: _cachedActiveModeTotalSum,
                                      paletteColors: paletteColors,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: List.generate(_cachedSortedEntries.length, (index) {
                                    final entry = _cachedSortedEntries[index];
                                    final color = paletteColors[index % paletteColors.length];
                                    final percentage = _cachedActiveModeTotalSum > 0 ? (entry.value / _cachedActiveModeTotalSum) * 100 : 0.0;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: color,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${entry.key}: ',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                          ),
                                          Text(
                                            '${currencyFormat.format(entry.value)} (${percentage.toStringAsFixed(1)}%)',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                SizedBox(
                                  height: 220,
                                  child: PieChart(
                                    PieChartData(
                                      pieTouchData: PieTouchData(
                                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                          setState(() {
                                            if (!event.isInterestedForInteractions ||
                                                pieTouchResponse == null ||
                                                pieTouchResponse.touchedSection == null) {
                                              touchedPieIndex = null;
                                              return;
                                            }
                                            touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                          });
                                        },
                                      ),
                                      borderData: FlBorderData(show: false),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 45,
                                      sections: List.generate(_cachedSortedEntries.length, (index) {
                                        final entry = _cachedSortedEntries[index];
                                        final isTouched = index == touchedPieIndex;
                                        final radius = isTouched ? 65.0 : 55.0;
                                        final color = paletteColors[index % paletteColors.length];
                                        final percentage = _cachedActiveModeTotalSum > 0 ? (entry.value / _cachedActiveModeTotalSum) * 100 : 0.0;

                                        return PieChartSectionData(
                                          color: color,
                                          value: entry.value,
                                          title: '${percentage.toStringAsFixed(1)}%',
                                          radius: radius,
                                          titleStyle: TextStyle(
                                            fontSize: isTouched ? 13 : 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: List.generate(_cachedSortedEntries.length, (index) {
                                    final entry = _cachedSortedEntries[index];
                                    final color = paletteColors[index % paletteColors.length];
                                    final percentage = _cachedActiveModeTotalSum > 0 ? (entry.value / _cachedActiveModeTotalSum) * 100 : 0.0;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: color,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${entry.key}: ',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                          ),
                                          Text(
                                            '${currencyFormat.format(entry.value)} (${percentage.toStringAsFixed(1)}%)',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
            ],
          ),
        );
      },
    );
  }

  void _showMultiSelectDialog(
    BuildContext context,
    String title,
    List<LabelModel> allLabels,
    Set<int> initialSelected,
    ValueChanged<Set<int>> onSelectionChanged,
  ) {
    Set<int> tempSelected = Set.from(initialSelected);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 300,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      title: const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: tempSelected.length == allLabels.length,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            tempSelected = allLabels.map((l) => l.id).toSet();
                          } else {
                            tempSelected.clear();
                          }
                        });
                      },
                    ),
                    const Divider(),
                    ...allLabels.map((label) {
                      return CheckboxListTile(
                        title: Text(label.name),
                        value: tempSelected.contains(label.id),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              tempSelected.add(label.id);
                            } else {
                              tempSelected.remove(label.id);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 88, 47, 149), foregroundColor: Colors.white),
                  onPressed: () {
                    onSelectionChanged(tempSelected);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Custom 3D Glassmorphic Extruded Donut Chart Painter
class _3DGlassDonutChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> entries;
  final double totalSum;
  final List<Color> paletteColors;

  _3DGlassDonutChartPainter({
    required this.entries,
    required this.totalSum,
    required this.paletteColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalSum <= 0 || entries.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2 - 10);
    final maxVal = entries.first.value;

    double startAngle = -math.pi / 2;

    // Draw Drop Shadows first
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final sweepAngle = (entry.value / totalSum) * 2 * math.pi;
      final valRatio = (entry.value / maxVal).clamp(0.4, 1.0);
      final heightExtent = 25.0 * valRatio;

      final outerR = 85.0;

      final shadowPath = Path()
        ..addOval(Rect.fromCircle(center: center.translate(0, heightExtent + 10), radius: outerR));

      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawPath(shadowPath, shadowPaint);
    }

    // Draw 3D Extruded Blocks and Arc Top Faces
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final sweepAngle = (entry.value / totalSum) * 2 * math.pi;
      final color = paletteColors[i % paletteColors.length];

      final valRatio = (entry.value / maxVal).clamp(0.4, 1.0);
      final heightExtent = 35.0 * valRatio;

      final outerR = 85.0;
      final innerR = 48.0;

      // Outer Arc Wall
      final outerWallPath = Path();
      outerWallPath.addArc(Rect.fromCircle(center: center, radius: outerR), startAngle, sweepAngle);
      outerWallPath.lineTo(
        center.dx + outerR * math.cos(startAngle + sweepAngle),
        center.dy + heightExtent + outerR * math.sin(startAngle + sweepAngle),
      );
      outerWallPath.addArc(Rect.fromCircle(center: center.translate(0, heightExtent), radius: outerR), startAngle + sweepAngle, -sweepAngle);
      outerWallPath.close();

      final outerWallGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.85),
          color.withValues(alpha: 0.45),
        ],
      );

      final outerPaint = Paint()..shader = outerWallGradient.createShader(outerWallPath.getBounds());
      canvas.drawPath(outerWallPath, outerPaint);

      // Inner Wall Glass Highlight
      final innerWallPath = Path();
      innerWallPath.addArc(Rect.fromCircle(center: center, radius: innerR), startAngle, sweepAngle);
      innerWallPath.lineTo(
        center.dx + innerR * math.cos(startAngle + sweepAngle),
        center.dy + heightExtent + innerR * math.sin(startAngle + sweepAngle),
      );
      innerWallPath.addArc(Rect.fromCircle(center: center.translate(0, heightExtent), radius: innerR), startAngle + sweepAngle, -sweepAngle);
      innerWallPath.close();

      final innerWallGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.70),
          color.withValues(alpha: 0.30),
        ],
      );

      final innerPaint = Paint()..shader = innerWallGradient.createShader(innerWallPath.getBounds());
      canvas.drawPath(innerWallPath, innerPaint);

      // Top Face Arc Ring
      final topFacePath = Path();
      topFacePath.addArc(Rect.fromCircle(center: center, radius: outerR), startAngle, sweepAngle);
      topFacePath.lineTo(
        center.dx + innerR * math.cos(startAngle + sweepAngle),
        center.dy + innerR * math.sin(startAngle + sweepAngle),
      );
      topFacePath.addArc(Rect.fromCircle(center: center, radius: innerR), startAngle + sweepAngle, -sweepAngle);
      topFacePath.close();

      final topGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.95),
          color.withValues(alpha: 0.75),
        ],
      );

      final topPaint = Paint()..shader = topGradient.createShader(topFacePath.getBounds());
      canvas.drawPath(topFacePath, topPaint);

      // Glass Edge Highlights
      final glassBorderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.6);

      canvas.drawPath(topFacePath, glassBorderPaint);

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _3DGlassDonutChartPainter oldDelegate) {
    return oldDelegate.entries != entries || oldDelegate.totalSum != totalSum;
  }
}