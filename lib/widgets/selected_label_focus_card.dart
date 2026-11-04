// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class SelectedLabelFocusCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? selectedOwner;
  final int? selectedLabelId;
  final Function(int?) onLabelChanged;
  final Function(String?) onOwnerChanged;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final VoidCallback onClearDateFilter;
  
  final Function(int? labelId, String? owner, DateTime? start, DateTime? end)? onJumpToHistory;
  final VoidCallback? onNavigateToWhatIf;

  const SelectedLabelFocusCard({
    super.key,
    required this.transactions,
    required this.labels,
    required this.owners,
    required this.startDate,
    required this.endDate,
    required this.selectedOwner,
    required this.selectedLabelId,
    required this.onLabelChanged,
    required this.onOwnerChanged,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onClearDateFilter,
    this.onJumpToHistory,
    this.onNavigateToWhatIf,
  });

  @override
  State<SelectedLabelFocusCard> createState() => _SelectedLabelFocusCardState();
}

class _SelectedLabelFocusCardState extends State<SelectedLabelFocusCard> {
  String _singleLabelDefaultRange = '';
  bool _isZaznamityMode = true;
  bool _isCollapsed = false;
  String _primaryCurrency = 'USD';
  final NumberFormat _currencyFormatter = NumberFormat('#,##0.00', 'en_US');
  final Map<String, bool> _multiLabelFixedCategories = {};
  
  String _lastFingerprint = '';
  List<TransactionModel> _cachedFilteredTxs = [];
  double _cachedInflow = 0;
  double _cachedOutflow = 0;
  double _cachedPreviousPeriodValue = 0;
  double _cachedMomPercentage = 0;
  Map<int, double> _cachedMonthlyTrend12M = {};
  
  final Map<String, double> _labelBudgetsByName = {};

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    final fixedMap = <String, bool>{};
    final budgetMap = <String, double>{};
    for (var label in widget.labels) {
      fixedMap[label.name] = prefs.getBool('set_multilabel_fixed_${label.name}') ?? false;
      final bVal = prefs.getDouble('budget_label_${label.name}');
      if (bVal != null) budgetMap[label.name] = bVal;
    }

    if (!mounted) return;
    setState(() {
      _singleLabelDefaultRange = prefs.getString('set_singleLabel_range') ?? '';
      final themeStr = prefs.getString('app_theme') ?? 'zaznamity';
      _isZaznamityMode = (themeStr == 'zaznamity');
      _isCollapsed = prefs.getBool('set_selectedLabelFocus_collapsed') ?? false;
      _primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';
      _multiLabelFixedCategories.addAll(fixedMap);
      _labelBudgetsByName.addAll(budgetMap);
    });
  }

  Future<void> _saveBudget(String labelName, double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('budget_label_$labelName', amount);
    if (!mounted) return;
    setState(() {
      _labelBudgetsByName[labelName] = amount;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Budget for "$labelName" set to ${_formatAmount(amount)}')),
    );
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_selectedLabelFocus_collapsed', _isCollapsed);
  }

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      case 'CZK': return 'Kč';
      default: return '\$';
    }
  }

  String _formatAmount(double amount) {
    final symbol = _getCurrencySymbol(_primaryCurrency);
    return '${_currencyFormatter.format(amount)} $symbol';
  }

  bool _isFixedExpenseLabelByName(String labelName) {
    if (_multiLabelFixedCategories.containsKey(labelName)) {
      return _multiLabelFixedCategories[labelName] == true;
    }
    final lower = labelName.toLowerCase();
    return lower.contains('rent') ||
        lower.contains('housing') ||
        lower.contains('utility') ||
        lower.contains('utilities') ||
        lower.contains('insurance') ||
        lower.contains('loan') ||
        lower.contains('mortgage') ||
        lower.contains('bill');
  }

  DateTime? _getComputedStartDate() {
    if (widget.startDate != null) return widget.startDate!;
    if (_singleLabelDefaultRange.isEmpty) return null;
    final now = DateTime.now();
    switch (_singleLabelDefaultRange) {
      case '7 Days':
        return now.subtract(const Duration(days: 7));
      case '15 Days':
        return now.subtract(const Duration(days: 15));
      case '30 Days':
        return now.subtract(const Duration(days: 30));
      case 'Current Month':
        return DateTime(now.year, now.month, 1);
      default:
        return null;
    }
  }

  DateTime? _getComputedEndDate() {
    if (widget.endDate != null) return widget.endDate!;
    if (_getComputedStartDate() == null) return null;
    return DateTime.now();
  }

  String _buildFingerprint() {
    final sb = StringBuffer();
    sb.write('${widget.transactions.length}_');
    sb.write('${widget.selectedLabelId}_');
    sb.write('${widget.selectedOwner}_');
    sb.write('${widget.startDate}_${widget.endDate}_');
    return sb.toString();
  }

  void _computeMetricsIfNeeded() {
    final fp = _buildFingerprint();
    if (_lastFingerprint == fp) return;

    final effectiveStartDate = _getComputedStartDate();
    final effectiveEndDate = _getComputedEndDate();

    final filtered = widget.transactions.where((tx) {
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null) return false;
      
      if (effectiveStartDate != null) {
        final startClean = DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day);
        if (txDate.isBefore(startClean)) return false;
      }

      if (effectiveEndDate != null) {
        final endClean = DateTime(effectiveEndDate.year, effectiveEndDate.month, effectiveEndDate.day, 23, 59, 59);
        if (txDate.isAfter(endClean)) return false;
      }

      if (widget.selectedLabelId != null && tx.labelId != widget.selectedLabelId) return false;
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners' && tx.owner != widget.selectedOwner) return false;
      return true;
    }).toList();

    double inf = 0;
    double out = 0;
    for (var tx in filtered) {
      if (tx.isConfirmed == 1) {
        if (tx.type == 'income') {
          inf += tx.amount;
        } else {
          out += tx.amount;
        }
      }
    }

    bool isIncomeFocus = inf >= out;

    int durationDays = effectiveStartDate != null && effectiveEndDate != null 
        ? effectiveEndDate.difference(effectiveStartDate).inDays + 1 
        : 30;
    if (durationDays < 1) durationDays = 1;

    double prevPeriodValue = 0.0;
    if (effectiveStartDate != null && effectiveEndDate != null) {
      final prevStart = effectiveStartDate.subtract(Duration(days: durationDays));
      final prevEnd = effectiveStartDate.subtract(const Duration(seconds: 1));
      
      for (var tx in widget.transactions) {
        final txDate = DateTime.tryParse(tx.createdAt);
        if (txDate == null || tx.isConfirmed != 1) continue;
        if (txDate.isAfter(prevStart.subtract(const Duration(seconds: 1))) && txDate.isBefore(prevEnd.add(const Duration(seconds: 1)))) {
          if (widget.selectedLabelId != null && tx.labelId != widget.selectedLabelId) continue;
          if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners' && tx.owner != widget.selectedOwner) continue;
          
          if (isIncomeFocus && tx.type == 'income') {
            prevPeriodValue += tx.amount;
          } else if (!isIncomeFocus && tx.type == 'expense') {
            prevPeriodValue += tx.amount;
          }
        }
      }
    }

    double activeCurrentVal = isIncomeFocus ? inf : out;
    double momPct = 0.0;
    if (prevPeriodValue > 0) {
      momPct = ((activeCurrentVal - prevPeriodValue) / prevPeriodValue.abs()) * 100;
    } else if (activeCurrentVal > 0) {
      momPct = 100.0;
    }

    final now = DateTime.now();
    Map<int, double> monthly12M = {};
    for (int i = 1; i <= 12; i++) monthly12M[i] = 0.0;

    for (var tx in widget.transactions) {
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null || tx.isConfirmed != 1) continue;
      if (isIncomeFocus && tx.type != 'income') continue;
      if (!isIncomeFocus && tx.type != 'expense') continue;
      
      if (widget.selectedLabelId != null && tx.labelId != widget.selectedLabelId) continue;
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners' && tx.owner != widget.selectedOwner) continue;
      
      final diffMonths = (now.year - txDate.year) * 12 + (now.month - txDate.month);
      if (diffMonths >= 0 && diffMonths < 12) {
        monthly12M[txDate.month] = (monthly12M[txDate.month] ?? 0.0) + tx.amount;
      }
    }

    _cachedFilteredTxs = filtered;
    _cachedInflow = inf;
    _cachedOutflow = out;
    _cachedPreviousPeriodValue = prevPeriodValue;
    _cachedMomPercentage = momPct;
    _cachedMonthlyTrend12M = monthly12M;
    _lastFingerprint = fp;
  }

  void _showSetBudgetDialog(String labelName) {
    final controller = TextEditingController(text: (_labelBudgetsByName[labelName] ?? 0.0).toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        title: Text('Set Budget for $labelName', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
          decoration: const InputDecoration(labelText: 'Monthly Target Amount', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7), foregroundColor: Colors.white),
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 0.0;
              _saveBudget(labelName, val);
              Navigator.pop(ctx);
            },
            child: const Text('Save Budget'),
          ),
        ],
      ),
    );
  }

  void _showLabelFocusInfoModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Label Focus',
                  style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              '“What is going on with this one label?” - Label Focus provides deep analytical insights into your category patterns[cite: 16].\n\n'
              '• Type-Aware Metrics: Dynamically adapts metrics for both Income and Expense categories[cite: 17].\n'
              '• Granular stats: Transaction counts, averages, frequency intervals, and anomaly detection[cite: 16].\n'
              '• Seasonality & Pace: Daily cumulative pace charts and 12-month historical heatmaps[cite: 16].\n'
              '• Recurring & What-If: Next occurrence forecasts and budget optimization simulations[cite: 16].',
              style: TextStyle(fontSize: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569), height: 1.4),
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), foregroundColor: Colors.white),
              child: const Text('Got it'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _computeMetricsIfNeeded();

    final effectiveStartDate = _getComputedStartDate();
    final effectiveEndDate = _getComputedEndDate();

    String selectedLabelName = 'All Labels';
    if (widget.selectedLabelId != null) {
      final matchLbl = widget.labels.where((l) => l.id == widget.selectedLabelId).firstOrNull;
      if (matchLbl != null) {
        selectedLabelName = matchLbl.name;
      } else {
        selectedLabelName = 'General';
      }
    }
    bool isFixedLabel = _isFixedExpenseLabelByName(selectedLabelName);

    bool isIncomeFocus = _cachedInflow >= _cachedOutflow;
    double primaryFocusAmount = isIncomeFocus ? _cachedInflow : _cachedOutflow;

    int txCount = _cachedFilteredTxs.where((tx) => isIncomeFocus ? tx.type == 'income' : tx.type == 'expense').length;
    double avgPerTx = txCount > 0 ? primaryFocusAmount / txCount : 0.0;
    
    double largestTx = 0.0;
    for (var tx in _cachedFilteredTxs) {
      if ((isIncomeFocus && tx.type == 'income') || (!isIncomeFocus && tx.type == 'expense')) {
        if (tx.amount > largestTx) largestTx = tx.amount;
      }
    }

    String frequencyStr = 'N/A';
    if (txCount > 1) {
      final typeFilteredTxs = _cachedFilteredTxs.where((tx) => isIncomeFocus ? tx.type == 'income' : tx.type == 'expense').toList();
      final sortedDates = typeFilteredTxs.map((t) => DateTime.tryParse(t.createdAt) ?? DateTime.now()).toList()..sort();
      if (sortedDates.length >= 2) {
        final totalSpanDays = sortedDates.last.difference(sortedDates.first).inDays;
        final avgInterval = totalSpanDays / (sortedDates.length - 1);
        frequencyStr = 'every ~${avgInterval.round()} days';
      }
    }

    String nextOccurrenceStr = 'None predicted';
    if (txCount > 0) {
      final typeFilteredTxs = _cachedFilteredTxs.where((tx) => isIncomeFocus ? tx.type == 'income' : tx.type == 'expense').toList();
      final sortedDates = typeFilteredTxs.map((t) => DateTime.tryParse(t.createdAt) ?? DateTime.now()).toList()..sort();
      if (sortedDates.length >= 2) {
        final lastInterval = sortedDates.last.difference(sortedDates[sortedDates.length - 2]).inDays;
        final nextDate = sortedDates.last.add(Duration(days: lastInterval > 0 ? lastInterval : 30));
        nextOccurrenceStr = DateFormat('MMM dd, yyyy').format(nextDate);
      }
    }

    List<TransactionModel> anomalies = _cachedFilteredTxs.where((tx) => 
      ((isIncomeFocus && tx.type == 'income') || (!isIncomeFocus && tx.type == 'expense')) && 
      avgPerTx > 0 && tx.amount > (avgPerTx * 1.5)
    ).toList();

    double labelBudget = _labelBudgetsByName[selectedLabelName] ?? 0.0;
    double budgetProgressRatio = labelBudget > 0 ? (primaryFocusAmount / labelBudget).clamp(0.0, 1.0) : 0.0;

    double potentialImpactYearly = primaryFocusAmount * 0.20 * 12;

    final last5Txs = List<TransactionModel>.from(_cachedFilteredTxs)
      ..sort((a, b) => (DateTime.tryParse(b.createdAt) ?? DateTime.now()).compareTo(DateTime.tryParse(a.createdAt) ?? DateTime.now()));
    final top5Recent = last5Txs.take(5).toList();

    final bool hasDateFilter = effectiveStartDate != null || effectiveEndDate != null;
    final displayOwner = (widget.selectedOwner == null || widget.selectedOwner!.isEmpty) ? 'All Owners' : widget.selectedOwner!;
    double maxMonthlyAmount = _cachedMonthlyTrend12M.values.fold(1.0, (prev, val) => val > prev ? val : prev);

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
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'LABEL FOCUS',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95), letterSpacing: 0.8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.info_outline, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
                          onPressed: () => _showLabelFocusInfoModal(context),
                          tooltip: 'Label Focus Info',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
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
                            Text(displayOwner, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155))),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.horizontal(left: const Radius.circular(10), right: hasDateFilter ? Radius.zero : const Radius.circular(10)),
                                border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                              ),
                              child: InkWell(
                                onTap: widget.onSelectStartDate,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.date_range_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          hasDateFilter
                                              ? '${effectiveStartDate != null ? DateFormat('MM/dd').format(effectiveStartDate) : '...'} - ${effectiveEndDate != null ? DateFormat('MM/dd').format(effectiveEndDate) : '...'}'
                                              : 'Select Date Range',
                                          style: TextStyle(fontSize: 11, color: hasDateFilter ? (_isZaznamityMode ? Colors.white : const Color(0xFF334155)) : (_isZaznamityMode ? Colors.white54 : const Color(0xFF94A3B8)), fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (hasDateFilter)
                            Container(
                              height: 44,
                              width: 36,
                              decoration: BoxDecoration(
                                color: _isZaznamityMode ? const Color(0xFF3D256B) : const Color(0xFFE2E8F0),
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                              ),
                              child: InkWell(
                                onTap: widget.onClearDateFilter,
                                child: const Center(child: Icon(Icons.clear, size: 14, color: Color(0xFFF87171))),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: boxWidth,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.label_outline_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int?>(
                                  value: widget.selectedLabelId,
                                  dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                  isDense: true,
                                  isExpanded: true,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                  hint: Text('All Labels', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF94A3B8))),
                                  items: [
                                    const DropdownMenuItem<int?>(value: null, child: Text('All Labels')),
                                    ...widget.labels.map((l) => DropdownMenuItem<int?>(value: l.id, child: Text(l.name))),
                                  ],
                                  onChanged: widget.onLabelChanged,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: boxWidth,
                      child: InkWell(
                        onTap: () {
                          if (widget.onJumpToHistory != null) {
                            widget.onJumpToHistory!(widget.selectedLabelId, (widget.selectedOwner == 'All Owners' ? null : widget.selectedOwner), effectiveStartDate, effectiveEndDate);
                          }
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Display all records', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC084FC) : const Color(0xFF582F95), fontSize: 9.5, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 1),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${_cachedFilteredTxs.length} Zaznams', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 3),
                                  Icon(Icons.arrow_forward_ios, size: 10, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Type-Aware Main Display (Earnings vs. Spending)
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('TOTAL ${isIncomeFocus ? 'EARNINGS' : 'SPENDING'} FOR $selectedLabelName'.toUpperCase(), style: TextStyle(color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _showInfoModal(context, isIncomeFocus ? 'Total Earnings' : 'Total Spending', 'Total amount for this specific label over the selected timeframe[cite: 16].'),
                            child: Icon(Icons.info_outline, size: 13, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(_formatAmount(primaryFocusAmount), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      Text(
                        'vs. Prev Period: ${_formatAmount(_cachedPreviousPeriodValue)} (${_cachedMomPercentage >= 0 ? '+' : ''}${_cachedMomPercentage.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 11, 
                          fontWeight: FontWeight.bold, 
                          color: isIncomeFocus 
                              ? (_cachedMomPercentage >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171))
                              : (_cachedMomPercentage <= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Granular Stats Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('GRANULAR METRICS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text('Count', style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? Colors.white54 : Colors.grey)),
                              Text('$txCount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                            ],
                          ),
                          Column(
                            children: [
                              Text('Avg / Tx', style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? Colors.white54 : Colors.grey)),
                              Text(_formatAmount(avgPerTx), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                            ],
                          ),
                          Column(
                            children: [
                              Text(isIncomeFocus ? 'Largest Inflow' : 'Largest Tx', style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? Colors.white54 : Colors.grey)),
                              Text(_formatAmount(largestTx), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isIncomeFocus ? const Color(0xFF34D399) : const Color(0xFFF87171))),
                            ],
                          ),
                          Column(
                            children: [
                              Text('Frequency', style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? Colors.white54 : Colors.grey)),
                              Text(frequencyStr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Budget / Target Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(isIncomeFocus ? 'TARGET PROGRESS' : 'BUDGET PROGRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), letterSpacing: 0.5)),
                      ],
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () => _showSetBudgetDialog(selectedLabelName),
                      icon: Icon(Icons.edit, size: 12, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                      label: Text(isIncomeFocus ? 'Set Target' : 'Set Budget', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(labelBudget > 0 ? '${isIncomeFocus ? 'Earned' : 'Spent'}: ${_formatAmount(primaryFocusAmount)} / ${_formatAmount(labelBudget)}' : 'No target set for this label', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                          Text(labelBudget > 0 ? '${(budgetProgressRatio * 100).toStringAsFixed(0)}%' : '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isIncomeFocus ? const Color(0xFF34D399) : (budgetProgressRatio > 0.9 ? const Color(0xFFF87171) : const Color(0xFF34D399)))),
                        ],
                      ),
                      if (labelBudget > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: budgetProgressRatio,
                            backgroundColor: _isZaznamityMode ? Colors.white12 : Colors.grey.shade200,
                            color: isIncomeFocus ? const Color(0xFF34D399) : (budgetProgressRatio > 0.9 ? const Color(0xFFF87171) : const Color(0xFFA855F7)),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Recurring Forecast
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('RECURRING FORECAST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Next Expected Occurrence', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B))),
                      Text(nextOccurrenceStr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 12-Month Seasonality Heatmap
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('12-MONTH SEASONALITY DISTRIBUTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(12, (index) {
                      final monthNum = index + 1;
                      final monthAmount = _cachedMonthlyTrend12M[monthNum] ?? 0.0;
                      final intensity = (monthAmount / maxMonthlyAmount).clamp(0.1, 1.0);
                      final monthAbbr = DateFormat('MMM').format(DateTime(2026, monthNum, 1))[0];

                      return Tooltip(
                        message: '${DateFormat('MMM').format(DateTime(2026, monthNum, 1))}: ${_formatAmount(monthAmount)}',
                        child: Column(
                          children: [
                            Container(
                              width: 22,
                              height: 36,
                              decoration: BoxDecoration(
                                color: monthAmount > 0
                                    ? (isIncomeFocus 
                                        ? const Color(0xFF34D399).withValues(alpha: intensity)
                                        : (_isZaznamityMode ? const Color(0xFFA855F7).withValues(alpha: intensity) : const Color(0xFF582F95).withValues(alpha: intensity)))
                                    : (_isZaznamityMode ? Colors.white10 : Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(monthAbbr, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B))),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // Cumulative Pace Chart
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('CUMULATIVE PACE CHART', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Current Run Rate vs Target', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B))),
                          Text(_formatAmount(primaryFocusAmount), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: labelBudget > 0 ? (primaryFocusAmount / labelBudget).clamp(0.0, 1.0) : 0.5,
                          backgroundColor: _isZaznamityMode ? Colors.white12 : Colors.grey.shade200,
                          color: isIncomeFocus ? const Color(0xFF34D399) : const Color(0xFF38BDF8),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Outlier / Anomaly Detection
                if (anomalies.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isIncomeFocus ? 'INCOME SURGE ANOMALIES (${anomalies.length})' : 'OUTLIER ANOMALIES DETECTED (${anomalies.length})', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isIncomeFocus ? const Color(0xFF34D399) : const Color(0xFFF87171), letterSpacing: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isIncomeFocus ? const Color(0xFF34D399) : const Color(0xFFF87171)).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (isIncomeFocus ? const Color(0xFF34D399) : const Color(0xFFF87171)).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: anomalies.take(2).map((tx) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(tx.description, style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                            Text(_formatAmount(tx.amount), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isIncomeFocus ? const Color(0xFF34D399) : const Color(0xFFF87171))),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // What-If Link / Optimization Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF3B1E63) : const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isIncomeFocus ? 'What if income increases 20%?' : 'What if I cut this 20%?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                            const SizedBox(height: 2),
                            Text('${isIncomeFocus ? 'Adds' : 'Saves'} ${_formatAmount(potentialImpactYearly)} / year', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFF34D399) : const Color(0xFF059669))),
                          ],
                        ),
                      ),
                      if (widget.onNavigateToWhatIf != null)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA855F7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: widget.onNavigateToWhatIf,
                          child: const Text('What-If Lab', style: TextStyle(fontSize: 10)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Last 5 Zaznams Inline
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('LAST 5 ZAZNAMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: top5Recent.isEmpty
                      ? const Padding(padding: EdgeInsets.all(12), child: Center(child: Text('No zaznams found', style: TextStyle(fontSize: 11, color: Colors.grey))))
                      : Column(
                          children: top5Recent.map((tx) {
                            final dt = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
                            return ListTile(
                              dense: true,
                              title: Text(tx.description.isEmpty ? 'Zaznam' : tx.description, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                              subtitle: Text(DateFormat('MMM dd, yyyy').format(dt), style: TextStyle(fontSize: 9.5, color: _isZaznamityMode ? Colors.white54 : Colors.grey)),
                              trailing: Text(_formatAmount(tx.amount), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tx.type == 'income' ? const Color(0xFF34D399) : const Color(0xFFF87171))),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}