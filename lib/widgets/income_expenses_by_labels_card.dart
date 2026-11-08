// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';
import '../services/privacy_service.dart';
import '../widgets/masked_amount.dart';

class IncomeExpensesByLabelsCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
  final List budgets;
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
  final Function(int? labelId, String? owner, DateTime? start, DateTime? end)? onJumpToHistory;

  final ValueChanged<int?>? onLabelSelected;
  final Function(DateTime? start, DateTime? end)? onDateRangeSelected;

  const IncomeExpensesByLabelsCard({
    super.key,
    required this.transactions,
    required this.labels,
    required this.owners,
    this.budgets = const [],
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
    this.onJumpToHistory,
    this.onLabelSelected,
    this.onDateRangeSelected,
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
  
  final Map<int, bool> _multiLabelFixedCategoriesById = {};
  final Map<String, bool> _multiLabelFixedCategories = {};
  
  bool _initializedLabels = false;
  String? _localOwner;
  String _multiLabelDefaultRange = '';
  bool _isZaznamityMode = true;
  bool _excludeTransfers = true;
  bool _isCollapsed = false;

  // Local date state fallbacks to mirror SelectedLabelFocusCard behavior
  DateTime? _localStartDate;
  DateTime? _localEndDate;

  String _primaryCurrency = 'USD';

  Map<int, double> _labelBudgetsById = {};
  Map<String, double> _labelBudgetsByName = {};

  double _cachedTotalIncome = 0;
  double _cachedTotalExpenses = 0;
  List<MapEntry<String, double>> _cachedSortedEntries = [];
  double _cachedActiveModeTotalSum = 0;
  double _cachedMaxTopAmount = 1.0;
  double _cachedMaxChartAmount = 1.0;
  double _cachedFixedExpenses = 0;
  double _cachedDiscretionaryExpenses = 0;
  
  Map<String, double> _cachedLabelMoMDelta = {};
  Map<String, String> _cachedShareOfIncome = {};
  Set<String> _cachedFlagged30PercentLabels = {};

  String _lastTxFingerprint = '';
  String? _lastOwner;
  DateTime? _lastStartDate;
  DateTime? _lastEndDate;
  String? _lastDisplayMode;
  String _lastIncomeLabelsKey = '';
  String _lastExpenseLabelsKey = '';
  String _lastFixedLabelsKey = '';
  bool? _lastExcludeTransfers;
  String? _lastCurrencyKey;
  String _lastBudgetsKey = '';

  @override
  void initState() {
    super.initState();
    _localOwner = widget.selectedOwner;
    _localStartDate = widget.startDate;
    _localEndDate = widget.endDate;
    _loadMultiLabelSettingsOnce();
  }

  Future<void> _loadMultiLabelSettingsOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final collapsed = prefs.getBool('set_incomeExpensesByLabels_collapsed') ?? false;
    final primaryCurr = prefs.getString('primaryCurrency') ?? prefs.getString('currency') ?? 'USD';
    
    final savedIncomeStr = prefs.getString('selected_income_labels');
    if (savedIncomeStr != null && savedIncomeStr.isNotEmpty) {
      selectedIncomeLabels.clear();
      for (var idStr in savedIncomeStr.split(',')) {
        final id = int.tryParse(idStr);
        if (id != null) selectedIncomeLabels.add(id);
      }
    }

    final savedExpenseStr = prefs.getString('selected_expense_labels');
    if (savedExpenseStr != null && savedExpenseStr.isNotEmpty) {
      selectedExpenseLabels.clear();
      for (var idStr in savedExpenseStr.split(',')) {
        final id = int.tryParse(idStr);
        if (id != null) selectedExpenseLabels.add(id);
      }
    }

    final Map<int, bool> fixedById = {};
    final Map<String, bool> fixedByName = {};
    final Map<int, double> budgetsById = {};
    final Map<String, double> budgetsByName = {};

    for (var label in widget.labels) {
      final isFixed = prefs.getBool('set_multilabel_fixed_id_${label.id}') ??
          prefs.getBool('set_multilabel_fixed_${label.name}') ??
          false;
      fixedById[label.id] = isFixed;
      fixedByName[label.name] = isFixed;

      final budgetVal = prefs.getDouble('budget_label_id_${label.id}') ??
          prefs.getDouble('budget_label_${label.name}');
      if (budgetVal != null) {
        budgetsById[label.id] = budgetVal;
        budgetsByName[label.name] = budgetVal;
      }
    }

    if (!mounted) return;
    setState(() {
      _multiLabelDefaultRange = prefs.getString('set_multiLabel_range') ?? 'Current Month';
      _isZaznamityMode = (savedTheme == 'zaznamity');
      _excludeTransfers = prefs.getBool('exclude_transfers_insights') ?? true;
      _isCollapsed = collapsed;
      _primaryCurrency = primaryCurr;
      _multiLabelFixedCategoriesById.clear();
      _multiLabelFixedCategoriesById.addAll(fixedById);
      _multiLabelFixedCategories.clear();
      _multiLabelFixedCategories.addAll(fixedByName);
      _labelBudgetsById = budgetsById;
      _labelBudgetsByName = budgetsByName;
    });
  }

  void _showMoneyBreakdownInfoModal(BuildContext context) {
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
                  'Money Breakdown',
                  style: TextStyle(
                    color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              '“What is my money made of?” - Money Breakdown provides a detailed view of your income and expenses categorized by labels.\n\n' 
              '• This card helps you understand where your money is coming from and where it is going, allowing for better financial planning and decision-making.\n'
              '• You can select which income and expense labels to include in the analysis, giving you a tailored view of your finances.\n'
              '• It displays the total income, total expenses, and a breakdown of each label\'s contribution to the overall financial picture.\n'
              '• You can switch between different chart types (bar, pie, tree) to visualize the data in a way that best suits your preferences.\n'
              '• It provides insights into fixed and discretionary expenses, helping you identify areas where you can potentially save money.\n'
              '• Target budget indicators display directly inside charts comparing spending against set limits.\n'
              '• The card calculates month-over-month changes for each label (in percentages: "+ [red] %" (more than last month) or "- [green] %" (less than last month)), allowing you to track trends and identify areas of concern or improvement.\n'
              '• It automatically detects and flags labels (yellow !) that have exceeded 30% above their 3-month average, alerting you to potential overspending in those categories.\n'
              '• The share-of-income calculation shows how much each label contributes to your total income, providing a clear picture of your financial priorities.\n'
              '• You can filter by date range, owner, and choose to include or exclude transfers in Settings.\n'
              '• Clicking on a specific label in the chart will bring you directly to the "Label Focus" card, providing a deeper understanding of your financial habits regarding that label.',
              style: TextStyle(
                fontSize: 13,
                color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Got it'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_incomeExpensesByLabels_collapsed', _isCollapsed);
  }

  Future<void> _saveSelectedLabels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_income_labels', selectedIncomeLabels.join(','));
    await prefs.setString('selected_expense_labels', selectedExpenseLabels.join(','));
  }

  @override
  void didUpdateWidget(covariant IncomeExpensesByLabelsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOwner != oldWidget.selectedOwner) {
      _localOwner = widget.selectedOwner;
    }
    if (widget.startDate != oldWidget.startDate) {
      _localStartDate = widget.startDate;
    }
    if (widget.endDate != oldWidget.endDate) {
      _localEndDate = widget.endDate;
    }
  }

  bool _isFixedExpenseLabel(LabelModel label) {
    if (_multiLabelFixedCategoriesById.containsKey(label.id)) {
      return _multiLabelFixedCategoriesById[label.id] == true;
    }
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

  DateTime _subtractMonths(DateTime date, int months) {
    int year = date.year;
    int month = date.month - months;
    while (month < 1) {
      month += 12;
      year -= 1;
    }
    int day = date.day;
    int maxDaysInTargetMonth = DateTime(year, month + 1, 0).day;
    if (day > maxDaysInTargetMonth) {
      day = maxDaysInTargetMonth;
    }
    return DateTime(year, month, day, date.hour, date.minute, date.second);
  }

  DateTime? _getEffectiveStartDate() {
    if (_localStartDate != null) return _localStartDate;
    if (widget.startDate != null) return widget.startDate;
    if (_multiLabelDefaultRange.isEmpty) return null;
    final now = DateTime.now();
    switch (_multiLabelDefaultRange) {
      case '15 Days':
        return now.subtract(const Duration(days: 15));
      case '30 Days':
        return now.subtract(const Duration(days: 30));
      case 'Current Month':
        return DateTime(now.year, now.month, 1);
      case '3 Months':
        return _subtractMonths(now, 3);
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  DateTime? _getEffectiveEndDate() {
    if (_localEndDate != null) return _localEndDate;
    if (widget.endDate != null) return widget.endDate;
    return DateTime.now();
  }

  void _applyQuickRange(String rangeKey) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (rangeKey) {
      case 'Month':
        start = DateTime(now.year, now.month, 1);
        break;
      case '90D':
        start = now.subtract(const Duration(days: 90));
        break;
      case '6M':
        start = DateTime(now.year, now.month - 6, now.day);
        break;
      case '1Y':
        start = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        return;
    }

    setState(() {
      _localStartDate = start;
      _localEndDate = end;
    });

    if (widget.onDateRangeSelected != null) {
      widget.onDateRangeSelected!(start, end);
    }
  }

  bool _isQuickRangeActive(String rangeKey) {
    final activeStart = _getEffectiveStartDate();
    if (activeStart == null) return false;
    final now = DateTime.now();
    DateTime? expectedStart;
    switch (rangeKey) {
      case 'Month':
        expectedStart = DateTime(now.year, now.month, 1);
        break;
      case '90D':
        expectedStart = now.subtract(const Duration(days: 90));
        break;
      case '6M':
        expectedStart = DateTime(now.year, now.month - 6, now.day);
        break;
      case '1Y':
        expectedStart = DateTime(now.year - 1, now.month, now.day);
        break;
    }
    if (expectedStart == null) return false;
    final startClean = DateTime(activeStart.year, activeStart.month, activeStart.day);
    final expectedClean = DateTime(expectedStart.year, expectedStart.month, expectedStart.day);
    return startClean.isAtSameMomentAs(expectedClean);
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      symbol: '',
      decimalDigits: 2,
    );
    final formattedVal = formatter.format(amount).trim();
    final code = _primaryCurrency.toUpperCase();

    if (code == 'EUR' || code == '€') {
      return '$formattedVal €';
    } else if (code == 'GBP' || code == '£') {
      return '£$formattedVal';
    } else if (code == 'JPY' || code == 'CNY' || code == '¥') {
      return '¥$formattedVal';
    } else if (code == 'CZK' || code == 'KČ') {
      return '$formattedVal Kč';
    } else {
      return '\$$formattedVal';
    }
  }

  String _createTxFingerprint(List<TransactionModel> txs) {
    final sb = StringBuffer();
    sb.write(txs.length);
    sb.write('_');
    for (var tx in txs) {
      sb.write('${tx.id}:${tx.amount}:${tx.createdAt}:${tx.labelId};');
    }
    return sb.toString();
  }

  double _getBudgetForLabel(String labelName) {
    final matchedLabel = widget.labels.where((l) => l.name == labelName).firstOrNull;
    if (matchedLabel != null && _labelBudgetsById.containsKey(matchedLabel.id)) {
      return _labelBudgetsById[matchedLabel.id]!;
    }
    if (_labelBudgetsByName.containsKey(labelName)) {
      return _labelBudgetsByName[labelName]!;
    }
    
    final matchingBudget = widget.budgets.where((b) {
      final bLabelId = b['label_id'] ?? b['labelId'];
      final bLabelName = b['label_name'] ?? b['labelName'];
      return (matchedLabel != null && bLabelId == matchedLabel.id) || (bLabelName == labelName);
    }).firstOrNull;

    if (matchingBudget != null) {
      return ((matchingBudget['limit_amount'] ?? matchingBudget['limitAmount'] ?? 0) as num).toDouble();
    }

    return 0.0;
  }

  void _computeDataIfNeeded() {
    final activeOwner = widget.selectedOwner ?? _localOwner;
    final incomeLabelsKey = selectedIncomeLabels.join(',');
    final expenseLabelsKey = selectedExpenseLabels.join(',');
    final fixedLabelsKey = _multiLabelFixedCategoriesById.entries.where((e) => e.value).map((e) => e.key).join(',');
    final budgetsKey = widget.budgets.length.toString();
    final effectiveStart = _getEffectiveStartDate();
    final effectiveEnd = _getEffectiveEndDate();
    final currentTxFingerprint = _createTxFingerprint(widget.transactions);

    if (_lastTxFingerprint == currentTxFingerprint &&
        _lastOwner == activeOwner &&
        _lastStartDate == effectiveStart &&
        _lastEndDate == effectiveEnd &&
        _lastDisplayMode == chartDisplayMode &&
        _lastIncomeLabelsKey == incomeLabelsKey &&
        _lastExpenseLabelsKey == expenseLabelsKey &&
        _lastFixedLabelsKey == fixedLabelsKey &&
        _lastExcludeTransfers == _excludeTransfers &&
        _lastCurrencyKey == _primaryCurrency &&
        _lastBudgetsKey == budgetsKey) {
      return;
    }

    final now = DateTime.now();
    final Map<int, LabelModel> labelById = {for (var l in widget.labels) l.id: l};
    final fallbackGeneralLabel = LabelModel(id: 0, name: 'General', color: '#4338CA');

    Duration periodSpan = const Duration(days: 30);
    if (effectiveStart != null && effectiveEnd != null) {
      periodSpan = effectiveEnd.difference(effectiveStart);
      if (periodSpan.inDays < 1) periodSpan = const Duration(days: 1);
    }
    final prevStart = effectiveStart?.subtract(periodSpan);
    final prevEnd = effectiveStart;

    final threeMonthsAgo = _subtractMonths(now, 3);

    double totalIncome = 0;
    double totalExpenses = 0;
    double fixedExp = 0;
    double discExp = 0;

    final Map<String, double> labelTotals = {};
    final Map<String, double> previousPeriodLabelTotals = {};
    final Map<String, double> label3MonthTotals = {};

    for (var tx in widget.transactions) {
      if (activeOwner != null && activeOwner.isNotEmpty && activeOwner != 'All Owners' && tx.owner != activeOwner) {
        continue;
      }

      final txDate = DateTime.tryParse(tx.createdAt) ?? now;
      final bool timePassed = txDate.isBefore(now);
      if (tx.isConfirmed != 1 && !timePassed) continue;

      final labelObj = labelById[tx.labelId] ?? fallbackGeneralLabel;

      if (_excludeTransfers && labelObj.name.toLowerCase() == 'transfer') {
        continue;
      }

      final isCurrentPeriod = (effectiveStart == null || !txDate.isBefore(effectiveStart)) &&
          (effectiveEnd == null || !txDate.isAfter(DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day, 23, 59, 59)));

      final isPrevPeriod = (prevStart != null && !txDate.isBefore(prevStart)) &&
          (prevEnd != null && txDate.isBefore(prevEnd));

      final is3MonthPeriod = !txDate.isBefore(threeMonthsAgo) && !txDate.isAfter(now);

      if (tx.type == 'income') {
        if (!selectedIncomeLabels.contains(labelObj.id) && labelObj.id != 0) continue;

        if (isCurrentPeriod) {
          totalIncome += tx.amount;
          if (chartDisplayMode == 'Show Income') {
            labelTotals[labelObj.name] = (labelTotals[labelObj.name] ?? 0) + tx.amount;
          }
        }
        if (isPrevPeriod && chartDisplayMode == 'Show Income') {
          previousPeriodLabelTotals[labelObj.name] = (previousPeriodLabelTotals[labelObj.name] ?? 0) + tx.amount;
        }
        if (is3MonthPeriod && chartDisplayMode == 'Show Income') {
          label3MonthTotals[labelObj.name] = (label3MonthTotals[labelObj.name] ?? 0) + tx.amount;
        }
      } else {
        if (!selectedExpenseLabels.contains(labelObj.id) && labelObj.id != 0) continue;

        if (isCurrentPeriod) {
          totalExpenses += tx.amount;
          if (_isFixedExpenseLabel(labelObj)) {
            fixedExp += tx.amount;
          } else {
            discExp += tx.amount;
          }

          if (chartDisplayMode == 'Show Expenses') {
            labelTotals[labelObj.name] = (labelTotals[labelObj.name] ?? 0) + tx.amount;
          }
        }
        if (isPrevPeriod && chartDisplayMode == 'Show Expenses') {
          previousPeriodLabelTotals[labelObj.name] = (previousPeriodLabelTotals[labelObj.name] ?? 0) + tx.amount;
        }
        if (is3MonthPeriod && chartDisplayMode == 'Show Expenses') {
          label3MonthTotals[labelObj.name] = (label3MonthTotals[labelObj.name] ?? 0) + tx.amount;
        }
      }
    }

    Map<String, double> labelDeltas = {};
    labelTotals.forEach((label, currentVal) {
      final prevVal = previousPeriodLabelTotals[label] ?? 0.0;
      if (prevVal > 0) {
        labelDeltas[label] = ((currentVal - prevVal) / prevVal) * 100;
      } else if (currentVal > 0) {
        labelDeltas[label] = 100.0;
      } else {
        labelDeltas[label] = 0.0;
      }
    });

    final Map<String, String> shareOfIncomeMap = {};
    labelTotals.forEach((label, amount) {
      if (totalIncome > 0) {
        final share = (amount / totalIncome) * 100;
        shareOfIncomeMap[label] = '$label is ${share.toStringAsFixed(1)}% of income';
      } else {
        shareOfIncomeMap[label] = '$label (N/A vs income)';
      }
    });

    final Set<String> flaggedLabels = {};
    labelTotals.forEach((label, currentAmount) {
      final total3M = label3MonthTotals[label] ?? 0.0;
      final avg3M = total3M / 3.0;
      if (avg3M > 0 && currentAmount > (avg3M * 1.30)) {
        flaggedLabels.add(label);
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
    _cachedShareOfIncome = shareOfIncomeMap;
    _cachedFlagged30PercentLabels = flaggedLabels;

    _cachedActiveModeTotalSum = sortedEntries.fold(0.0, (sum, entry) => sum + entry.value);
    _cachedMaxTopAmount = (totalIncome > totalExpenses ? totalIncome : totalExpenses) > 0 
        ? (totalIncome > totalExpenses ? totalIncome : totalExpenses) 
        : 1.0;
    _cachedMaxChartAmount = sortedEntries.isNotEmpty ? sortedEntries.first.value : 1.0;

    _lastTxFingerprint = currentTxFingerprint;
    _lastOwner = activeOwner;
    _lastStartDate = effectiveStart;
    _lastEndDate = effectiveEnd;
    _lastDisplayMode = chartDisplayMode;
    _lastIncomeLabelsKey = incomeLabelsKey;
    _lastExpenseLabelsKey = expenseLabelsKey;
    _lastFixedLabelsKey = fixedLabelsKey;
    _lastExcludeTransfers = _excludeTransfers;
    _lastCurrencyKey = _primaryCurrency;
    _lastBudgetsKey = budgetsKey;
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

  void _handleLabelTap(String labelName) {
    final matchedLabel = widget.labels.where((l) => l.name == labelName).firstOrNull;
    final labelId = matchedLabel?.id ?? 0;
    final start = _getEffectiveStartDate();
    final end = _getEffectiveEndDate();

    if (widget.onLabelSelected != null) {
      widget.onLabelSelected!(labelId);
    }
    if (widget.onDateRangeSelected != null) {
      widget.onDateRangeSelected!(start, end);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initializedLabels && widget.labels.isNotEmpty) {
      if (selectedIncomeLabels.isEmpty) {
        for (var l in widget.labels) {
          selectedIncomeLabels.add(l.id);
        }
      }
      if (selectedExpenseLabels.isEmpty) {
        for (var l in widget.labels) {
          selectedExpenseLabels.add(l.id);
        }
      }
      _initializedLabels = true;
    }

    _computeDataIfNeeded();

    final activeOwner = widget.selectedOwner ?? _localOwner;
    
    final paletteColors = _isZaznamityMode ? [
      const Color(0xFFA855F7),
      const Color(0xFF38BDF8),
      const Color(0xFF34D399),
      const Color(0xFFFBBF24),
      const Color(0xFFF87171),
      const Color(0xFF818CF8),
      const Color(0xFFFB7185),
      const Color(0xFF2DD4BF),
      const Color(0xFFC084FC),
    ] : [
      const Color(0xFF582F95),
      const Color(0xFF0284C7),
      const Color(0xFF059669),
      const Color(0xFFD97706),
      const Color(0xFFDC2626),
      const Color(0xFF4F46E5),
      const Color(0xFFE11D48),
      const Color(0xFF0D9488),
      const Color(0xFF7C3AED),
    ];

    final bool hasDateFilter = _localStartDate != null || _localEndDate != null || widget.startDate != null || widget.endDate != null;
    final double fixedRatio = _cachedTotalExpenses > 0 ? (_cachedFixedExpenses / _cachedTotalExpenses) * 100 : 0.0;
    final double discRatio = _cachedTotalExpenses > 0 ? (_cachedDiscretionaryExpenses / _cachedTotalExpenses) * 100 : 0.0;
    final effectiveStart = _getEffectiveStartDate();
    final effectiveEnd = _getEffectiveEndDate();

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
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
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
                        'MONEY BREAKDOWN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.info_outline, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
                    onPressed: () => _showMoneyBreakdownInfoModal(context),
                    tooltip: 'Money Breakdown',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
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
                              activeOwner != null && activeOwner.isNotEmpty ? activeOwner : 'All Owners',
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

                // Timeframe Selector Pills & Custom Date Range Picker in One Row (Synced with SelectedLabelFocusCard)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: boxWidth,
                      child: Row(
                        children: ['Month', '90D', '6M', '1Y'].map((tf) {
                          final isSelected = _isQuickRangeActive(tf);
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: tf != '1Y' ? 4 : 0),
                              child: InkWell(
                                onTap: () => _applyQuickRange(tf),
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? const Color(0xFF582F95) 
                                        : (_isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                                  ),
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: Text(
                                      tf,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : (_isZaznamityMode ? Colors.white70 : const Color(0xFF64748B)),
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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
                                color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
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
                                            hasDateFilter
                                                ? '${effectiveStart != null ? DateFormat('MM/dd').format(effectiveStart) : '...'} - ${effectiveEnd != null ? DateFormat('MM/dd').format(effectiveEnd) : '...'}'
                                                : 'Date Range',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: hasDateFilter ? (_isZaznamityMode ? Colors.white : const Color(0xFF334155)) : (_isZaznamityMode ? Colors.white54 : const Color(0xFF94A3B8)),
                                              fontWeight: FontWeight.bold,
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
                            Container(
                              height: 44,
                              width: 32,
                              decoration: BoxDecoration(
                                color: _isZaznamityMode ? const Color(0xFF3D256B) : const Color(0xFFE2E8F0),
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _localStartDate = null;
                                      _localEndDate = null;
                                    });
                                    widget.onClearDateFilter();
                                  },
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

                // Row: "Income Labels" Dropdown and "Expense Labels" Dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: boxWidth,
                      child: InkWell(
                        onTap: () => _showMultiSelectDialog(
                          context,
                          'Select Income Labels',
                          widget.labels,
                          selectedIncomeLabels,
                          (updatedIds) {
                            setState(() {
                              selectedIncomeLabels.clear();
                              selectedIncomeLabels.addAll(updatedIds);
                            });
                            _saveSelectedLabels();
                          },
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.add_circle_outline_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          selectedIncomeLabels.length == widget.labels.length
                                              ? 'Income Labels (All)'
                                              : 'Income (${selectedIncomeLabels.length}/${widget.labels.length})',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_drop_down, size: 18, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: boxWidth,
                      child: InkWell(
                        onTap: () => _showMultiSelectDialog(
                          context,
                          'Select Expense Labels',
                          widget.labels,
                          selectedExpenseLabels,
                          (updatedIds) {
                            setState(() {
                              selectedExpenseLabels.clear();
                              selectedExpenseLabels.addAll(updatedIds);
                            });
                            _saveSelectedLabels();
                          },
                        ),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.remove_circle_outline_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          selectedExpenseLabels.length == widget.labels.length
                                              ? 'Expense Labels (All)'
                                              : 'Expense (${selectedExpenseLabels.length}/${widget.labels.length})',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_drop_down, size: 18, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fixed vs Discretionary Card Box
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FIXED VS DISCRETIONARY',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: fixedRatio > 0 ? fixedRatio.round() : 1,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isZaznamityMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                flex: discRatio > 0 ? discRatio.round() : 1,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFBBF24),
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: MaskedAmount(
                              formattedAmount: 'Fixed: ${_formatCurrency(_cachedFixedExpenses)} (${fixedRatio.toStringAsFixed(1)}%)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: MaskedAmount(
                              formattedAmount: 'Discretionary: ${_formatCurrency(_cachedDiscretionaryExpenses)} (${discRatio.toStringAsFixed(1)}%)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)),
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
                          'Fixed vs. Discretionary Spending',
                          'Separates essential recurring living costs from flexible lifestyle expenses. Configure labels in Zaznamity Settings -> Labels Management.',
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                ValueListenableBuilder<bool>(
                  valueListenable: PrivacyService.instance.isPrivacyModeEnabled,
                  builder: (context, isPrivate, child) {
                    return Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            InkWell(
                              onTap: () => setState(() => chartDisplayMode = 'Show Income'),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _isZaznamityMode ? const Color.fromARGB(255, 17, 34, 28) : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: (_isZaznamityMode ? const Color(0xFF34D399) : const Color(0xFF059669)).withValues(alpha: 0.6), width: 1.2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('TOTAL INCOME     (Tap to view charts)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFF34D399) : const Color(0xFF059669), letterSpacing: 0.5)),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (_cachedTotalIncome / _cachedMaxTopAmount).clamp(0.0, 1.0),
                                        backgroundColor: _isZaznamityMode ? const Color(0xFF064E3B) : const Color(0xFFA7F3D0),
                                        color: _isZaznamityMode ? const Color(0xFF34D399) : const Color(0xFF059669),
                                        minHeight: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: MaskedAmount(
                                          formattedAmount: _formatCurrency(_cachedTotalIncome),
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -4,
                              child: InkWell(
                                onTap: () => _showInfoModal(
                                  context,
                                  'Total Income',
                                  'Sum of all incoming money transactions filtered by owner, date range, and selected income labels. Pressing anywhere on this box shows the charts below as income.',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFE2E8F0), shape: BoxShape.circle),
                                  child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            InkWell(
                              onTap: () => setState(() => chartDisplayMode = 'Show Expenses'),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _isZaznamityMode ? const Color.fromARGB(255, 40, 20, 23) : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: (_isZaznamityMode ? const Color(0xFFF87171) : const Color(0xFFDC2626)).withValues(alpha: 0.6), width: 1.2),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('TOTAL EXPENSES     (Tap to view charts)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFF87171) : const Color(0xFFDC2626), letterSpacing: 0.5)),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: (_cachedTotalExpenses / _cachedMaxTopAmount).clamp(0.0, 1.0),
                                        backgroundColor: _isZaznamityMode ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                                        color: _isZaznamityMode ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                                        minHeight: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: MaskedAmount(
                                          formattedAmount: _formatCurrency(_cachedTotalExpenses),
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -4,
                              child: InkWell(
                                onTap: () => _showInfoModal(
                                  context,
                                  'Total Expenses',
                                  'Sum of all outgoing expense transactions filtered by owner, date range, and your chosen expense labels. Pressing anywhere on this box shows the charts below as expenses.',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFE2E8F0), shape: BoxShape.circle),
                                  child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
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
                              color: chartType == 'Bar' ? (_isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95)) : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                            ),
                            child: Text(
                              'Bar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: chartType == 'Bar' ? Colors.white : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95)),
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
                              color: chartType == 'Donut' ? (_isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95)) : Colors.transparent,
                            ),
                            child: Text(
                              'Donut',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: chartType == 'Donut' ? Colors.white : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95)),
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
                              color: chartType == 'Treemap' ? (_isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95)) : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                            ),
                            child: Text(
                              'Treemap',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: chartType == 'Treemap' ? Colors.white : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95)),
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
                    ? SizedBox(
                        height: 150,
                        child: Center(
                          child: Text('No data available for selected filters.', style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
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
                                final shareOfIncomeText = _cachedShareOfIncome[entry.key] ?? '';
                                final isFlagged = _cachedFlagged30PercentLabels.contains(entry.key);
                                final budget = _getBudgetForLabel(entry.key);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: InkWell(
                                    onTap: () => _handleLabelTap(entry.key),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: 105,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      if (isFlagged)
                                                        const Padding(
                                                          padding: EdgeInsets.only(right: 4.0),
                                                          child: Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFF59E0B)),
                                                        ),
                                                      Expanded(
                                                        child: Text(
                                                          entry.key,
                                                          textAlign: TextAlign.right,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      Tooltip(
                                                        message: shareOfIncomeText,
                                                        child: Text(
                                                          '${percentageShare.toStringAsFixed(1)}%',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '(${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%)',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: delta <= 0 ? (_isZaznamityMode ? const Color(0xFF34D399) : const Color(0xFF059669)) : (_isZaznamityMode ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
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
                                                      Stack(
                                                        clipBehavior: Clip.none,
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
                                                          if (budget > 0 && _cachedMaxChartAmount > 0) ...[
                                                            Positioned(
                                                              left: ((budget / _cachedMaxChartAmount) * availableBarArea).clamp(0.0, availableBarArea),
                                                              top: -2,
                                                              bottom: -2,
                                                              child: Container(
                                                                width: 2.5,
                                                                height: 22,
                                                                decoration: BoxDecoration(
                                                                  color: entry.value > budget ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                                                  borderRadius: BorderRadius.circular(2),
                                                                  boxShadow: const [
                                                                    BoxShadow(
                                                                      color: Colors.black26,
                                                                      blurRadius: 2,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      SizedBox(
                                                        width: priceTextWidth,
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment.centerRight,
                                                          child: MaskedAmount(
                                                            formattedAmount: _formatCurrency(entry.value),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                              color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
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
                                        if (budget > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 117.0, top: 2.0),
                                            child: MaskedAmount(
                                              formattedAmount: 'Budget: ${_formatCurrency(entry.value)} / ${_formatCurrency(budget)}',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: entry.value > budget ? const Color(0xFFF87171) : const Color(0xFF34D399),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                              Container(
                                margin: const EdgeInsets.only(left: 117),
                                child: Column(
                                  children: [
                                    Container(height: 1, color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        MaskedAmount(
                                          formattedAmount: _formatCurrency(0),
                                          style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                        ),
                                        MaskedAmount(
                                          formattedAmount: _formatCurrency(_cachedMaxChartAmount * 0.5),
                                          style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                        ),
                                        MaskedAmount(
                                          formattedAmount: _formatCurrency(_cachedMaxChartAmount),
                                          style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                        ),
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
                                      color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: _buildProportionalTreemap(_cachedSortedEntries, paletteColors),
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
                                      final budget = _getBudgetForLabel(entry.key);

                                      return InkWell(
                                        onTap: () => _handleLabelTap(entry.key),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
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
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                              ),
                                              MaskedAmount(
                                                formattedAmount: '${_formatCurrency(entry.value)} (${percentage.toStringAsFixed(1)}%) ',
                                                style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                              ),
                                              if (budget > 0)
                                                MaskedAmount(
                                                  formattedAmount: '/ ${_formatCurrency(budget)} ',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: entry.value > budget ? const Color(0xFFF87171) : const Color(0xFF34D399)),
                                                ),
                                              Text(
                                                '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: delta <= 0 ? (_isZaznamityMode ? const Color(0xFF34D399) : const Color(0xFF059669)) : (_isZaznamityMode ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                                                ),
                                              ),
                                            ],
                                          ),
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
                                          touchCallback: (FlTouchEvent event, PieTouchResponse? pieTouchResponse) {
                                            if (!event.isInterestedForInteractions) return;

                                            if (pieTouchResponse?.touchedSection != null) {
                                              final index = pieTouchResponse!.touchedSection!.touchedSectionIndex;
                                              if (index >= 0 && index < _cachedSortedEntries.length) {
                                                if (touchedPieIndex != index) {
                                                  setState(() {
                                                    touchedPieIndex = index;
                                                  });
                                                }
                                              }
                                            }

                                            if (event is FlTapUpEvent) {
                                              if (touchedPieIndex != null && touchedPieIndex! >= 0 && touchedPieIndex! < _cachedSortedEntries.length) {
                                                final entryName = _cachedSortedEntries[touchedPieIndex!].key;
                                                setState(() {
                                                  touchedPieIndex = null;
                                                });
                                                _handleLabelTap(entryName);
                                              }
                                            }
                                          },
                                        ),
                                        borderData: FlBorderData(show: false),
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 45,
                                        sections: List.generate(_cachedSortedEntries.length, (index) {
                                          final entry = _cachedSortedEntries[index];
                                          final isTouched = index == touchedPieIndex;
                                          const radius = 50.0;
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
                                              color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
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
                                      final budget = _getBudgetForLabel(entry.key);

                                      return InkWell(
                                        onTap: () => _handleLabelTap(entry.key),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
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
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                              ),
                                              MaskedAmount(
                                                formattedAmount: '${_formatCurrency(entry.value)} (${percentage.toStringAsFixed(1)}%) ',
                                                style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                              ),
                                              if (budget > 0)
                                                MaskedAmount(
                                                  formattedAmount: '/ ${_formatCurrency(budget)} ',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: entry.value > budget ? const Color(0xFFF87171) : const Color(0xFF34D399)),
                                                ),
                                              Text(
                                                '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: delta <= 0 ? (_isZaznamityMode ? const Color(0xFF34D399) : const Color(0xFF059669)) : (_isZaznamityMode ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProportionalTreemap(
    List<MapEntry<String, double>> entries,
    List<Color> paletteColors,
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
              child: InkWell(
                onTap: () => _handleLabelTap(node.label),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: node.color.withValues(alpha: 0.35),
                    border: Border.all(color: _isZaznamityMode ? Colors.white24 : const Color(0xFFCBD5E1), width: 1.5),
                  ),
                  child: fits
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              node.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${node.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
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
              backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
              content: SizedBox(
                width: 300,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      title: Text('Select All', style: TextStyle(fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                      value: tempSelected.length == allLabels.length,
                      activeColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
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
                    Divider(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                    ...allLabels.map((label) {
                      return CheckboxListTile(
                        title: Text(label.name, style: TextStyle(color: _isZaznamityMode ? Colors.white70 : const Color(0xFF475569))),
                        value: tempSelected.contains(label.id),
                        activeColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
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
                  child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    onSelectionChanged(tempSelected);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply and Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
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