// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String chartType = 'Bar';
  int? touchedPieIndex;
  
  final Set<int> selectedIncomeLabels = {};
  final Set<int> selectedExpenseLabels = {};
  final Map<String, bool> _multiLabelFixedCategories = {};
  bool _initializedLabels = false;
  String? _localOwner;
  String _multiLabelDefaultRange = '30 Days';

  double _cachedTotalIncome = 0;
  double _cachedTotalExpenses = 0;
  List<MapEntry<String, double>> _cachedSortedEntries = [];
  double _cachedActiveModeTotalSum = 0;
  double _cachedMaxTopAmount = 1.0;
  double _cachedMaxChartAmount = 1.0;
  double _cachedFixedExpenses = 0;
  double _cachedDiscretionaryExpenses = 0;
  Map<String, double> _cachedLabelMoMDelta = {};

  int? _lastTxLength;
  String? _lastOwner;
  DateTime? _lastStartDate;
  DateTime? _lastEndDate;
  String? _lastDisplayMode;
  String _lastIncomeLabelsKey = '';
  String _lastExpenseLabelsKey = '';
  String _lastFixedLabelsKey = '';

  @override
  void initState() {
    super.initState();
    _localOwner = widget.selectedOwner;
    _loadMultiLabelSettings();
  }

  Future<void> _loadMultiLabelSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _multiLabelDefaultRange = prefs.getString('set_multiLabel_range') ?? '30 Days';
      for (var label in widget.labels) {
        _multiLabelFixedCategories[label.name] = prefs.getBool('set_multilabel_fixed_${label.name}') ?? false;
      }
    });
  }

  @override
  void didUpdateWidget(covariant IncomeExpensesByLabelsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOwner != oldWidget.selectedOwner) {
      setState(() {
        _localOwner = widget.selectedOwner;
      });
    }
    _loadMultiLabelSettings();
  }

  bool _isFixedExpenseLabel(LabelModel label) {
    if (_multiLabelFixedCategories.containsKey(label.name)) {
      return _multiLabelFixedCategories[label.name] == true;
    }
    final lower = label.name.toLowerCase();
    return lower.contains('rent') ||
        lower.contains('housing') ||
        lower.contains('utility') ||
        lower.contains('utilities') ||
        lower.contains('insurance') ||
        lower.contains('loan') ||
        lower.contains('mortgage') ||
        lower.contains('bill');
  }

  DateTime? _getEffectiveStartDate() {
    if (widget.startDate != null) return widget.startDate;
    final now = DateTime.now();
    switch (_multiLabelDefaultRange) {
      case '15 Days':
        return now.subtract(const Duration(days: 15));
      case '30 Days':
        return now.subtract(const Duration(days: 30));
      case 'Current Month':
        return DateTime(now.year, now.month, 1);
      case '3 Months':
        return DateTime(now.year, now.month - 3, now.day);
      default:
        return now.subtract(const Duration(days: 30));
    }
  }

  DateTime? _getEffectiveEndDate() {
    return widget.endDate ?? DateTime.now();
  }

  void _computeDataIfNeeded() {
    final activeOwner = widget.selectedOwner ?? _localOwner;
    final incomeLabelsKey = selectedIncomeLabels.join(',');
    final expenseLabelsKey = selectedExpenseLabels.join(',');
    final fixedLabelsKey = _multiLabelFixedCategories.entries.where((e) => e.value).map((e) => e.key).join(',');
    final effectiveStart = _getEffectiveStartDate();
    final effectiveEnd = _getEffectiveEndDate();

    if (_lastTxLength == widget.transactions.length &&
        _lastOwner == activeOwner &&
        _lastStartDate == effectiveStart &&
        _lastEndDate == effectiveEnd &&
        _lastDisplayMode == chartDisplayMode &&
        _lastIncomeLabelsKey == incomeLabelsKey &&
        _lastExpenseLabelsKey == expenseLabelsKey &&
        _lastFixedLabelsKey == fixedLabelsKey) {
      return;
    }

    final filteredTransactions = widget.transactions.where((tx) {
      if (activeOwner != null && activeOwner.isNotEmpty && activeOwner != 'All Owners' && tx.owner != activeOwner) {
        return false;
      }
      final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
      if (effectiveStart != null && txDate.isBefore(effectiveStart)) {
        return false;
      }
      if (effectiveEnd != null) {
        final endOfDay = DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day, 23, 59, 59);
        if (txDate.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();

    double totalIncome = 0;
    double totalExpenses = 0;
    double fixedExp = 0;
    double discExp = 0;
    final Map<String, double> labelTotals = {};
    final Map<String, double> previousPeriodLabelTotals = {};

    for (var tx in filteredTransactions) {
      final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
      final bool timePassed = txDate.isBefore(DateTime.now());
      
      if (tx.isConfirmed != 1 && !timePassed) continue;
      
      final labelObj = widget.labels.firstWhere(
        (l) => l.id == tx.labelId,
        orElse: () => LabelModel(id: 0, name: 'General', color: '#4338CA'),
      );

      final isCurrentPeriod = (effectiveStart == null || !txDate.isBefore(effectiveStart));

      if (tx.type == 'income') {
        if (!selectedIncomeLabels.contains(labelObj.id)) continue;
        totalIncome += tx.amount;
        if (chartDisplayMode == 'Show Income') {
          labelTotals[labelObj.name] = (labelTotals[labelObj.name] ?? 0) + tx.amount;
        }
      } else {
        if (!selectedExpenseLabels.contains(labelObj.id)) continue;
        totalExpenses += tx.amount;
        if (_isFixedExpenseLabel(labelObj)) {
          fixedExp += tx.amount;
        } else {
          discExp += tx.amount;
        }

        if (chartDisplayMode == 'Show Expenses') {
          if (isCurrentPeriod) {
            labelTotals[labelObj.name] = (labelTotals[labelObj.name] ?? 0) + tx.amount;
          } else {
            previousPeriodLabelTotals[labelObj.name] = (previousPeriodLabelTotals[labelObj.name] ?? 0) + tx.amount;
          }
        }
      }
    }

    Map<String, double> labelDeltas = {};
    labelTotals.forEach((label, currentVal) {
      final prevVal = previousPeriodLabelTotals[label] ?? 0.0;
      if (prevVal > 0) {
        labelDeltas[label] = ((currentVal - prevVal) / prevVal) * 100;
      } else {
        labelDeltas[label] = currentVal > 0 ? 100.0 : 0.0;
      }
    });

    final sortedEntries = labelTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _cachedTotalIncome = totalIncome;
    _cachedTotalExpenses = totalExpenses;
    _cachedFixedExpenses = fixedExp;
    _cachedDiscretionaryExpenses = discExp;
    _cachedSortedEntries = sortedEntries;
    _cachedLabelMoMDelta = labelDeltas;
    _cachedActiveModeTotalSum = sortedEntries.fold(0.0, (sum, entry) => sum + entry.value);
    _cachedMaxTopAmount = (totalIncome > totalExpenses ? totalIncome : totalExpenses) > 0 
        ? (totalIncome > totalExpenses ? totalIncome : totalExpenses) 
        : 1.0;
    _cachedMaxChartAmount = sortedEntries.isNotEmpty ? sortedEntries.first.value : 1.0;

    _lastTxLength = widget.transactions.length;
    _lastOwner = activeOwner;
    _lastStartDate = effectiveStart;
    _lastEndDate = effectiveEnd;
    _lastDisplayMode = chartDisplayMode;
    _lastIncomeLabelsKey = incomeLabelsKey;
    _lastExpenseLabelsKey = expenseLabelsKey;
    _lastFixedLabelsKey = fixedLabelsKey;
  }

  void _showInfoModal(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B4E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFA855F7)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
        content: Text(description, style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA855F7),
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
    if (!_initializedLabels && widget.labels.isNotEmpty) {
      for (var l in widget.labels) {
        selectedIncomeLabels.add(l.id);
        selectedExpenseLabels.add(l.id);
      }
      _initializedLabels = true;
    }

    _loadMultiLabelSettings();
    _computeDataIfNeeded();

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final activeOwner = widget.selectedOwner ?? _localOwner;
    
    // High-visibility chart color palette tailored for Zaznamity dark UI
    final paletteColors = [
      const Color(0xFFA855F7), // Electric Purple
      const Color(0xFF38BDF8), // Cyan / Sky Blue
      const Color(0xFF34D399), // Emerald Green
      const Color(0xFFFBBF24), // Amber Gold
      const Color(0xFFF87171), // Coral Red
      const Color(0xFF818CF8), // Indigo
      const Color(0xFFFB7185), // Rose Pink
      const Color(0xFF2DD4BF), // Teal
      const Color(0xFFC084FC), // Light Purple
    ];

    final bool hasDateFilter = widget.startDate != null || widget.endDate != null;
    final double fixedRatio = _cachedTotalExpenses > 0 ? (_cachedFixedExpenses / _cachedTotalExpenses) * 100 : 0.0;
    final double discRatio = _cachedTotalExpenses > 0 ? (_cachedDiscretionaryExpenses / _cachedTotalExpenses) * 100 : 0.0;
    final effectiveStart = _getEffectiveStartDate();
    final effectiveEnd = _getEffectiveEndDate();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 48;
        final double boxWidth = (fullWidth - 12) / 2;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1333),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
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
                          color: Color(0xFFA855F7),
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
                                backgroundColor: const Color(0xFF2D1B4E),
                                foregroundColor: Colors.white70,
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
                              backgroundColor: const Color(0xFF2D1B4E),
                              foregroundColor: Colors.white70,
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
                        color: const Color(0xFF2D1B4E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFFA855F7)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: activeOwner,
                                dropdownColor: const Color(0xFF2D1B4E),
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                hint: const Text('All Owners', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white54)),
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
                              color: const Color(0xFF2D1B4E),
                              borderRadius: BorderRadius.horizontal(
                                left: const Radius.circular(10),
                                right: hasDateFilter ? Radius.zero : const Radius.circular(10),
                              ),
                              border: Border.all(color: Colors.white12),
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
                                      const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFFA855F7)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          effectiveStart != null && effectiveEnd != null
                                              ? '${DateFormat('MM/dd').format(effectiveStart)} - ${DateFormat('MM/dd').format(effectiveEnd)}'
                                              : 'Select Date Range',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: hasDateFilter
                                                ? Colors.white
                                                : Colors.white54,
                                            fontWeight: hasDateFilter
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!hasDateFilter)
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white38),
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
                              color: const Color(0xFF3D256B),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onClearDateFilter,
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                child: const Center(
                                  child: Icon(Icons.clear, size: 14, color: Color(0xFFF87171)),
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
                          color: const Color(0xFF2D1B4E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.label_outline_rounded, size: 16, color: Color(0xFFA855F7)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        (chartDisplayMode == 'Show Income' ? selectedIncomeLabels.length : selectedExpenseLabels.length) == widget.labels.length
                                            ? 'All Labels'
                                            : '${chartDisplayMode == 'Show Income' ? selectedIncomeLabels.length : selectedExpenseLabels.length} selected',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
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
                        color: const Color(0xFF2D1B4E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFFA855F7)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: chartDisplayMode,
                                dropdownColor: const Color(0xFF2D1B4E),
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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
              const SizedBox(height: 16),

              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D1B4E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FIXED VS DISCRETIONARY',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: fixedRatio > 0 ? fixedRatio.round() : 1,
                              child: Container(
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF38BDF8),
                                  borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              flex: discRatio > 0 ? discRatio.round() : 1,
                              child: Container(
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFBBF24),
                                  borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Fixed: ${currencyFormat.format(_cachedFixedExpenses)} (${fixedRatio.toStringAsFixed(1)}%)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                            ),
                            Text(
                              'Discretionary: ${currencyFormat.format(_cachedDiscretionaryExpenses)} (${discRatio.toStringAsFixed(1)}%)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -4,
                    child: InkWell(
                      onTap: () => _showInfoModal(
                        context,
                        'Fixed vs. Discretionary Spending',
                        'Separates essential recurring living costs from flexible lifestyle expenses. Configure labels in App Settings -> Cards Settings -> Multi-Label Analytics.',
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E1333),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info_outline_rounded, size: 13, color: Colors.white54),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A332A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF047857).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL INCOME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF34D399), letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (_cachedTotalIncome / _cachedMaxTopAmount).clamp(0.0, 1.0),
                                backgroundColor: const Color(0xFF064E3B),
                                color: const Color(0xFF34D399),
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
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -4,
                        child: InkWell(
                          onTap: () => _showInfoModal(
                            context,
                            'Total Income',
                            'Sum of all incoming money transactions filtered by owner, date range, and selected income labels.',
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Color(0xFF1E1333), shape: BoxShape.circle),
                            child: const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF34D399)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B1F23),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFB91C1C).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL EXPENSES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF87171), letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (_cachedTotalExpenses / _cachedMaxTopAmount).clamp(0.0, 1.0),
                                backgroundColor: const Color(0xFF7F1D1D),
                                color: const Color(0xFFF87171),
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
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFF87171)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -4,
                        child: InkWell(
                          onTap: () => _showInfoModal(
                            context,
                            'Total Expenses',
                            'Sum of all outgoing expense transactions filtered by owner, date range, and your chosen expense labels.',
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Color(0xFF1E1333), shape: BoxShape.circle),
                            child: const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFF87171)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B4E),
                  border: Border.all(color: Colors.white12),
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
                            color: chartType == 'Bar' ? const Color(0xFFA855F7) : Colors.transparent,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                          ),
                          child: Text(
                            'Bar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: chartType == 'Bar' ? Colors.white : Colors.white70,
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
                            color: chartType == 'Donut' ? const Color(0xFFA855F7) : Colors.transparent,
                          ),
                          child: Text(
                            'Donut',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: chartType == 'Donut' ? Colors.white : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => chartType = 'Treemap'),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: chartType == 'Treemap' ? const Color(0xFFA855F7) : Colors.transparent,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                          ),
                          child: Text(
                            'Treemap',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: chartType == 'Treemap' ? Colors.white : Colors.white70,
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
                        child: Text('No data available for selected filters.', style: TextStyle(fontSize: 12, color: Colors.white54)),
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
                              final delta = _cachedLabelMoMDelta[entry.key] ?? 0.0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 95,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            entry.key,
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${percentageShare.toStringAsFixed(1)}%',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '(${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%)',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: delta <= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                                ),
                                              ),
                                            ],
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
                                                      color: Colors.white,
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
                                  Container(height: 1, color: Colors.white12),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('\$0', style: TextStyle(fontSize: 10, color: Colors.white54)),
                                      Text('\$${(_cachedMaxChartAmount * 0.5).toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                                      Text('\$${_cachedMaxChartAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : chartType == 'Treemap'
                          ? Column(
                              children: [
                                Container(
                                  height: 240,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2D1B4E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _buildProportionalTreemap(_cachedSortedEntries, paletteColors, currencyFormat),
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
                                    final delta = _cachedLabelMoMDelta[entry.key] ?? 0.0;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2D1B4E),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white12),
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
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          Text(
                                            '${currencyFormat.format(entry.value)} (${percentage.toStringAsFixed(1)}%) ',
                                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                                          ),
                                          Text(
                                            '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: delta <= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                            ),
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
                                  height: 240,
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
                                        final radius = isTouched ? 60.0 : 50.0;
                                        final color = paletteColors[index % paletteColors.length];
                                        final percentage = _cachedActiveModeTotalSum > 0 ? (entry.value / _cachedActiveModeTotalSum) * 100 : 0.0;

                                        return PieChartSectionData(
                                          color: color,
                                          value: entry.value,
                                          title: '${percentage.toStringAsFixed(1)}%',
                                          radius: radius,
                                          titlePositionPercentageOffset: 1.3,
                                          titleStyle: TextStyle(
                                            fontSize: isTouched ? 12 : 10,
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
                                    final delta = _cachedLabelMoMDelta[entry.key] ?? 0.0;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2D1B4E),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white12),
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
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          Text(
                                            '${currencyFormat.format(entry.value)} (${percentage.toStringAsFixed(1)}%) ',
                                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                                          ),
                                          Text(
                                            '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: delta <= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                            ),
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

  Widget _buildProportionalTreemap(
    List<MapEntry<String, double>> entries,
    List<Color> paletteColors,
    NumberFormat currencyFormat,
  ) {
    if (entries.isEmpty || _cachedActiveModeTotalSum <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final nodes = TreemapLayout.layout(entries, _cachedActiveModeTotalSum, paletteColors, width, height);

        return Stack(
          children: nodes.map((node) {
            final bool fits = node.rect.width > 55 && node.rect.height > 38;

            return Positioned.fromRect(
              rect: node.rect,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: node.color.withValues(alpha: 0.35),
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: fits
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            node.label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${node.percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }).toList(),
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
              backgroundColor: const Color(0xFF2D1B4E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              content: SizedBox(
                width: 300,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      title: const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      value: tempSelected.length == allLabels.length,
                      activeColor: const Color(0xFFA855F7),
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
                    const Divider(color: Colors.white12),
                    ...allLabels.map((label) {
                      return CheckboxListTile(
                        title: Text(label.name, style: const TextStyle(color: Colors.white70)),
                        value: tempSelected.contains(label.id),
                        activeColor: const Color(0xFFA855F7),
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
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7), foregroundColor: Colors.white),
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

class BorderColorHelper {
  static Color getCachedBorderColor() => Colors.white12;
}

class TreemapNode {
  final String label;
  final double value;
  final double percentage;
  final Color color;
  Rect rect = Rect.zero;

  TreemapNode({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
  });
}

class TreemapLayout {
  static List<TreemapNode> layout(
    List<MapEntry<String, double>> entries,
    double totalSum,
    List<Color> paletteColors,
    double boxWidth,
    double boxHeight,
  ) {
    List<TreemapNode> nodes = [];
    if (entries.isEmpty || totalSum <= 0) return nodes;

    for (int i = 0; i < entries.length; i++) {
      nodes.add(TreemapNode(
        label: entries[i].key,
        value: entries[i].value,
        percentage: (entries[i].value / totalSum) * 100,
        color: paletteColors[i % paletteColors.length],
      ));
    }
    nodes.sort((a, b) => b.value.compareTo(a.value));

    _partition(nodes, 0, nodes.length - 1, Rect.fromLTWH(0, 0, boxWidth, boxHeight), totalSum);
    return nodes;
  }

  static void _partition(
    List<TreemapNode> nodes,
    int start,
    int end,
    Rect rect,
    double totalValue,
  ) {
    if (start > end) return;
    if (start == end) {
      nodes[start].rect = rect;
      return;
    }

    double halfTotal = totalValue / 2;
    double accumulated = 0;
    int splitIndex = start;
    for (int i = start; i <= end; i++) {
      accumulated += nodes[i].value;
      if (accumulated >= halfTotal && i < end) {
        splitIndex = i;
        break;
      }
    }
    if (splitIndex == start) splitIndex = start;

    double firstGroupValue = 0;
    for (int i = start; i <= splitIndex; i++) {
      firstGroupValue += nodes[i].value;
    }
    double ratio = totalValue > 0 ? firstGroupValue / totalValue : 0.5;

    Rect rect1, rect2;
    if (rect.width >= rect.height) {
      double splitWidth = rect.width * ratio;
      rect1 = Rect.fromLTWH(rect.left, rect.top, splitWidth, rect.height);
      rect2 = Rect.fromLTWH(rect.left + splitWidth, rect.top, rect.width - splitWidth, rect.height);
    } else {
      double splitHeight = rect.height * ratio;
      rect1 = Rect.fromLTWH(rect.left, rect.top, rect.width, splitHeight);
      rect2 = Rect.fromLTWH(rect.left, rect.top + splitHeight, rect.width, rect.height - splitHeight);
    }

    _partition(nodes, start, splitIndex, rect1, firstGroupValue);
    _partition(nodes, splitIndex + 1, end, rect2, totalValue - firstGroupValue);
  }
}