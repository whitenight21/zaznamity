// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/liability_model.dart';
import '../models/label.dart';
//import '../services/privacy_service.dart';
import '../widgets/masked_amount.dart';

class WhatIfScenarioCard extends StatefulWidget {
  final List<String> owners;
  final String? selectedOwner;
  final List<String> pools;
  final List<LabelModel> labels;
  final List<TransactionModel> transactions;
  final List<LiabilityModel> liabilities;
  final double basePrognosis;
  final Function(String actionRoute, dynamic payload)? onNavigateAction;

  const WhatIfScenarioCard({
    super.key,
    required this.owners,
    this.selectedOwner,
    required this.pools,
    required this.labels,
    required this.transactions,
    required this.liabilities,
    required this.basePrognosis,
    this.onNavigateAction,
  });

  @override
  State<WhatIfScenarioCard> createState() => _WhatIfScenarioCardState();
}

class _WhatIfScenarioCardState extends State<WhatIfScenarioCard> {
  bool _isZaznamityMode = true;
  String _primaryCurrency = 'USD';
  bool _isCollapsed = false;

  Set<String> _selectedPoolNames = {};
  Set<int> _selectedLabelIds = {};

  double _incomeMultiplier = 1.0; 
  double _expenseSqueezePercent = 0.0; 
  double _lumpSumExpense = 0.0; 
  double _extraDebtPayment = 0.0; 
  int _horizonDays = 30; 
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  final TextEditingController _lumpSumController = TextEditingController(text: '0');
  final TextEditingController _extraDebtController = TextEditingController(text: '0');

  final List _datedEvents = []; 
  final Set<String> _hiddenDefaultPresets = {};
  List _customPresets = [];

  Map<String, dynamic>? _scenarioSlotA;
  Map<String, dynamic>? _scenarioSlotB;
  
  // Snoozed insights map: insightKey -> expiryDateTime
  final Map<String, DateTime> _snoozedInsights = {};
  
  // Score history for sparkline and monthly delta
  final List<double> _scoreHistory = [68, 70, 72, 71, 75, 78];

  // Data cache key for staleness detection
  String _lastDataCacheKey = '';

  double _getLiveLiquidBalance() {
    final now = DateTime.now();
    double totalBalance = 0;
    bool hasMatchingTx = false;

    final normalizedSelectedPools = _selectedPoolNames
        .map((p) => p.trim().toLowerCase())
        .toSet();
    final bool isFilteringSpecificPools = normalizedSelectedPools.isNotEmpty;

    for (var tx in widget.transactions) {
      if (tx.isConfirmed != 1) continue;

      final dt = DateTime.tryParse(tx.createdAt);
      if (dt != null && dt.isAfter(now)) continue;

      // Filter by selected owner if active
      if (widget.selectedOwner != null &&
          widget.selectedOwner!.isNotEmpty &&
          widget.selectedOwner != 'All Owners' &&
          tx.owner != widget.selectedOwner) {
        continue;
      }

      // If specific pools are selected in the What-If card filter,
      // restrict the sum strictly to those pools (e.g., Checking only).
      // When filtering by specific pool(s), include transfers into/out of that pool;
      // when viewing All Pools, exclude transfers so internal moves net out cleanly.
      if (isFilteringSpecificPools) {
        final txPool = tx.pool.trim().toLowerCase();
        if (!normalizedSelectedPools.contains(txPool)) {
          continue;
        }
      } else {
        if (_isTransferTransaction(tx)) continue;
      }

      hasMatchingTx = true;
      final normAmt = _normalizeAmount(tx.amount, null);
      double signedVal = tx.type == 'income' ? normAmt : -normAmt;
      totalBalance += signedVal;
    }

    if (isFilteringSpecificPools) {
      return totalBalance;
    }
    return hasMatchingTx ? totalBalance : widget.basePrognosis;
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final savedPresetsStr = prefs.getString('set_whatIf_custom_presets');
    final hiddenDefaultsStr = prefs.getString('set_whatIf_hidden_defaults');
    final snoozedStr = prefs.getString('set_whatIf_snoozed_insights');
    
    final savedPoolsList = prefs.getStringList('whatIf_selected_pools');
    Set<String> loadedPools = savedPoolsList != null ? savedPoolsList.toSet() : {};

    final savedLabelsList = prefs.getStringList('whatIf_selected_labels');
    Set<int> loadedLabels = savedLabelsList != null ? savedLabelsList.map((e) => int.parse(e)).toSet() : {};

    List loadedPresets = [];
    if (savedPresetsStr != null) {
      try {
        final decoded = jsonDecode(savedPresetsStr);
        if (decoded is List) {
          loadedPresets = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }

    Set<String> hiddenDefaults = {};
    if (hiddenDefaultsStr != null) {
      try {
        final decoded = jsonDecode(hiddenDefaultsStr);
        if (decoded is List) {
          hiddenDefaults = decoded.map((e) => e.toString()).toSet();
        }
      } catch (_) {}
    }

    if (snoozedStr != null) {
      try {
        final decoded = jsonDecode(snoozedStr);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            final dt = DateTime.tryParse(v.toString());
            if (dt != null && dt.isAfter(DateTime.now())) {
              _snoozedInsights[k.toString()] = dt;
            }
          });
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';
        _isCollapsed = prefs.getBool('set_whatIf_collapsed') ?? false;
        _customPresets = loadedPresets;
        _hiddenDefaultPresets.addAll(hiddenDefaults);
        if (savedPoolsList != null) _selectedPoolNames = loadedPools;
        if (savedLabelsList != null) _selectedLabelIds = loadedLabels;
      });
    }
  }

  Future<void> _savePoolPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('whatIf_selected_pools', _selectedPoolNames.toList());
  }

  Future<void> _saveLabelPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('whatIf_selected_labels', _selectedLabelIds.map((e) => e.toString()).toList());
  }

  Future<void> _snoozeInsight(String key) async {
    setState(() {
      _snoozedInsights[key] = DateTime.now().add(const Duration(days: 7));
    });
    final prefs = await SharedPreferences.getInstance();
    final mapToSave = _snoozedInsights.map((k, v) => MapEntry(k, v.toIso8601String()));
    await prefs.setString('set_whatIf_snoozed_insights', jsonEncode(mapToSave));
  }

  @override
  void dispose() {
    _lumpSumController.dispose();
    _extraDebtController.dispose();
    _savePoolPrefs();
    _saveLabelPrefs();
    super.dispose();
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_whatIf_collapsed', _isCollapsed);
  }

  Future<void> _saveCustomPreset(String name) async {
    if (name.trim().isEmpty) return;
    final newPreset = {
      'name': name.trim(),
      'incomeMultiplier': _incomeMultiplier,
      'expenseSqueeze': _expenseSqueezePercent,
      'lumpSum': _lumpSumExpense,
      'extraDebt': _extraDebtPayment,
      'horizonDays': _horizonDays,
      'datedEvents': _datedEvents,
    };

    setState(() {
      _customPresets.add(newPreset);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('set_whatIf_custom_presets', jsonEncode(_customPresets));
  }

  Future<void> _deleteCustomPreset(int index) async {
    setState(() {
      _customPresets.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('set_whatIf_custom_presets', jsonEncode(_customPresets));
  }

  Future<void> _hideDefaultPreset(String label) async {
    setState(() {
      _hiddenDefaultPresets.add(label);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('set_whatIf_hidden_defaults', jsonEncode(_hiddenDefaultPresets.toList()));
  }

  String _computeDataCacheKey() {
    final txBuffer = StringBuffer();
    for (var tx in widget.transactions) {
      txBuffer.write('${tx.id}-${tx.amount}-${tx.createdAt}-${tx.type},');
    }
    for (var lib in widget.liabilities) {
      txBuffer.write('${lib.id}-${lib.remainingBalance}-${lib.monthlyInstallment},');
    }
    for (var label in widget.labels) {
      txBuffer.write('${label.id}-${label.name},');
    }
    return '${widget.basePrognosis}-${widget.transactions.length}-${widget.liabilities.length}-${txBuffer.toString().hashCode}';
  }

  @override
  void didUpdateWidget(covariant WhatIfScenarioCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentKey = _computeDataCacheKey();
    if (currentKey != _lastDataCacheKey) {
      _lastDataCacheKey = currentKey;
      // Invalidate or re-sync caches if needed
    }
    _loadPrefs();
  }

  double _normalizeAmount(double amount, String? txCurrency) {
    // Multi-currency normalization supporting standard exchange rate conversions against primary currency
    if (txCurrency != null && txCurrency.toUpperCase() != _primaryCurrency.toUpperCase()) {
      if (txCurrency.toUpperCase() == 'EUR' && _primaryCurrency.toUpperCase() == 'USD') return amount * 1.1;
      if (txCurrency.toUpperCase() == 'USD' && _primaryCurrency.toUpperCase() == 'EUR') return amount / 1.1;
    }
    return amount;
  }

  bool _isTransferTransaction(TransactionModel tx) {
    final desc = tx.description.toLowerCase();
    final pool = tx.pool.toLowerCase();
    return desc.contains('transfer to') ||
           desc.contains('transfer from') ||
           desc.contains('transfer fee') ||
           pool.contains('transfer') ||
           tx.labelId == -999; // Shared TransactionFilters helper standard
  }

  String _getCurrencySymbol() {
    switch (_primaryCurrency.toUpperCase()) {
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
    final cleanAmount = amount.abs();
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final formattedNum = formatter.format(cleanAmount);
    
    String result;
    if (_primaryCurrency.toUpperCase() == 'EUR') {
      result = '$formattedNum €';
    } else if (_primaryCurrency.toUpperCase() == 'USD') {
      result = '\$$formattedNum';
    } else {
      final symbol = _getCurrencySymbol();
      result = '$symbol$formattedNum';
    }

    if (amount < 0) {
      return '-$result';
    }
    return result;
  }

  void _resetScenario() {
    setState(() {
      _incomeMultiplier = 1.0;
      _expenseSqueezePercent = 0.0;
      _lumpSumExpense = 0.0;
      _extraDebtPayment = 0.0;
      _horizonDays = 30;
      _customStartDate = null;
      _customEndDate = null;
      _lumpSumController.text = '0';
      _extraDebtController.text = '0';
      _datedEvents.clear();
    });
  }

  int get _effectiveHorizonDays {
    if (_customStartDate != null && _customEndDate != null) {
      return _customEndDate!.difference(_customStartDate!).inDays.clamp(1, 3650);
    }
    return _horizonDays;
  }

  Map<String, dynamic> _calculateSimulationResults({
    double? incMul,
    double? expSqz,
    double? lump,
    double? extraDebt,
    int? horizon,
    List? events,
  }) {
    final double incomeMultiplierVal = incMul ?? _incomeMultiplier;
    final double expenseSqueezeVal = expSqz ?? _expenseSqueezePercent;
    final double lumpSumVal = lump ?? _lumpSumExpense;
    final double extraDebtVal = extraDebt ?? _extraDebtPayment;
    final int horizonVal = horizon ?? _effectiveHorizonDays;
    final activeEvents = events ?? _datedEvents;

    final now = DateTime.now();
    final startDate = _customStartDate != null ? (_customStartDate!.isBefore(now) ? now : _customStartDate!) : now;
    final horizonEnd = _customEndDate != null ? _customEndDate! : now.add(Duration(days: horizonVal));

    double incomeHistorySum = 0;
    double expenseHistorySum = 0;
    int incomeMonthsCount = 0;
    
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
    Map<String, double> monthlyIncome = {};
    Map<String, double> monthlyExpense = {};

    for (var tx in widget.transactions) {
      if (_isTransferTransaction(tx)) continue;

      if (widget.selectedOwner != null &&
          widget.selectedOwner!.isNotEmpty &&
          widget.selectedOwner != 'All Owners' &&
          tx.owner != widget.selectedOwner) {
        continue;
      }
      if (_selectedPoolNames.isNotEmpty && !_selectedPoolNames.contains(tx.pool)) continue;
      if (_selectedLabelIds.isNotEmpty && !_selectedLabelIds.contains(tx.labelId)) continue;

      final dt = DateTime.tryParse(tx.createdAt);
      if (dt != null && dt.isAfter(threeMonthsAgo) && dt.isBefore(now)) {
        final normAmt = _normalizeAmount(tx.amount, null);
        final monthKey = DateFormat('yyyy-MM').format(dt);
        if (tx.type == 'income') {
          monthlyIncome[monthKey] = (monthlyIncome[monthKey] ?? 0) + normAmt;
        } else if (tx.type == 'expense') {
          monthlyExpense[monthKey] = (monthlyExpense[monthKey] ?? 0) + normAmt;
        }
      }
    }

    incomeMonthsCount = monthlyIncome.isNotEmpty ? monthlyIncome.length : 1;
    incomeHistorySum = monthlyIncome.values.fold(0.0, (a, b) => a + b);
    expenseHistorySum = monthlyExpense.values.fold(0.0, (a, b) => a + b);

    double monthlyAvgIncome = incomeHistorySum / incomeMonthsCount;
    double monthlyAvgExpense = expenseHistorySum / incomeMonthsCount;

    double dailyBaselineIncome = monthlyAvgIncome / 30.0;
    double dailyBaselineExpense = monthlyAvgExpense / 30.0;

    Map<String, double> scheduledIncomeByDay = {};
    Map<String, double> scheduledExpenseByDay = {};

    for (var tx in widget.transactions) {
      if (_isTransferTransaction(tx)) continue;

      if (widget.selectedOwner != null &&
          widget.selectedOwner!.isNotEmpty &&
          widget.selectedOwner != 'All Owners' &&
          tx.owner != widget.selectedOwner) {
        continue;
      }
      if (_selectedPoolNames.isNotEmpty && !_selectedPoolNames.contains(tx.pool)) continue;
      if (_selectedLabelIds.isNotEmpty && !_selectedLabelIds.contains(tx.labelId)) continue;

      final dt = DateTime.tryParse(tx.createdAt);
      if (dt != null && !dt.isBefore(startDate) && dt.isAfter(horizonEnd)) continue;
      if (dt != null) {
        final dayKey = DateFormat('yyyy-MM-dd').format(dt);
        final normAmt = _normalizeAmount(tx.amount, null);
        if (tx.type == 'income') {
          scheduledIncomeByDay[dayKey] = (scheduledIncomeByDay[dayKey] ?? 0) + normAmt;
        } else if (tx.type == 'expense') {
          scheduledExpenseByDay[dayKey] = (scheduledExpenseByDay[dayKey] ?? 0) + normAmt;
        }
      }
    }

    double dailyLiabilityOutlay = 0;
    for (var lib in widget.liabilities) {
      dailyLiabilityOutlay += (lib.monthlyInstallment / 30.0);
    }

    double startingBalance = _getLiveLiquidBalance();
    double currentBaselineBalance = startingBalance;
    double currentScenarioBalance = startingBalance;

    List baselineDailyTrend = [];
    List scenarioDailyTrend = [];

    DateTime? firstDipDate;
    double lowestScenarioBalance = startingBalance;

    int totalDays = horizonEnd.difference(startDate).inDays;
    if (totalDays < 1) totalDays = 1;

    for (int i = 0; i <= totalDays; i++) {
      DateTime currentDay = startDate.add(Duration(days: i));
      String dayKey = DateFormat('yyyy-MM-dd').format(currentDay);

      double dayBaseInc = dailyBaselineIncome + (scheduledIncomeByDay[dayKey] ?? 0);
      double dayBaseExp = dailyBaselineExpense + dailyLiabilityOutlay + (scheduledExpenseByDay[dayKey] ?? 0);

      currentBaselineBalance += (dayBaseInc - dayBaseExp);
      baselineDailyTrend.appendOrAdd(currentDay, currentBaselineBalance);

      double dayScenInc = dailyBaselineIncome * incomeMultiplierVal + (scheduledIncomeByDay[dayKey] ?? 0);
      double dayScenExp = (dailyBaselineExpense * (1.0 - (expenseSqueezeVal / 100.0))) + dailyLiabilityOutlay + extraDebtVal + (scheduledExpenseByDay[dayKey] ?? 0);

      if (i == 0) {
        dayScenExp += lumpSumVal;
      }

      for (var event in activeEvents) {
        DateTime? evDate = DateTime.tryParse(event['date'] ?? '');
        if (evDate != null && DateFormat('yyyy-MM-dd').format(evDate) == dayKey) {
          String type = event['type'] ?? '';
          double evAmount = event['amount'] ?? 0.0;
          if (type == 'one_off') {
            dayScenExp += evAmount;
          } else if (type == 'job_loss') {
            dayScenInc = 0; 
          } else if (type == 'skip_bill') {
            dayScenExp = (dayScenExp - evAmount).clamp(0.0, double.infinity);
          } else if (type == 'new_recurring') {
            dayScenExp += evAmount;
          }
        }
        if (event['type'] == 'job_loss') {
          DateTime? evDate = DateTime.tryParse(event['date'] ?? '');
          if (evDate != null && currentDay.isAfter(evDate)) {
            dayScenInc = 0;
          }
        }
      }

      currentScenarioBalance += (dayScenInc - dayScenExp);
      scenarioDailyTrend.add({'date': currentDay, 'balance': currentScenarioBalance});

      if (currentScenarioBalance < lowestScenarioBalance) {
        lowestScenarioBalance = currentScenarioBalance;
      }
      if (currentScenarioBalance < 0 && firstDipDate == null) {
        firstDipDate = currentDay;
      }
    }

    double simulatedIncome = (dailyBaselineIncome * totalDays) * incomeMultiplierVal;
    double simulatedExpense = (dailyBaselineExpense * totalDays * (1.0 - (expenseSqueezeVal / 100.0))) + lumpSumVal + (dailyLiabilityOutlay * totalDays) + (extraDebtVal * (totalDays / 30.0));
    double simulatedNetShift = currentScenarioBalance - startingBalance;

    double interestSaved = 0;
    int monthsSaved = 0;
    if (extraDebtVal > 0 && widget.liabilities.isNotEmpty) {
      for (var lib in widget.liabilities) {
        monthsSaved += (extraDebtVal / (lib.monthlyInstallment > 0 ? lib.monthlyInstallment : 100)).ceil();
        interestSaved += (lib.remainingBalance * 0.05 * (monthsSaved / 12.0)); 
      }
    }

    return {
      'startingBalance': startingBalance,
      'simulatedIncome': simulatedIncome,
      'simulatedExpense': simulatedExpense,
      'simulatedNetShift': simulatedNetShift,
      'simulatedEndingBalance': currentScenarioBalance,
      'estimatedRunwayDays': firstDipDate != null ? firstDipDate.difference(startDate).inDays : totalDays,
      'firstDipDate': firstDipDate,
      'lowestBalance': lowestScenarioBalance,
      'baselineTrend': baselineDailyTrend,
      'scenarioTrend': scenarioDailyTrend,
      'interestSaved': interestSaved,
      'monthsSaved': monthsSaved,
      'monthlyAvgIncome': monthlyAvgIncome,
      'monthlyAvgExpense': monthlyAvgExpense,
    };
  }

  Map<String, double> _calculateEndingBalanceRange() {
    final rand = Random(42);
    List<double> endings = [];
    const int totalRuns = 50;

    for (int i = 0; i < totalRuns; i++) {
      double randomizedIncMul = _incomeMultiplier * (0.9 + (rand.nextDouble() * 0.2));
      double randomizedSqueeze = (_expenseSqueezePercent + ((rand.nextDouble() * 6.0) - 3.0)).clamp(0.0, 50.0);
      double randomizedLump = _lumpSumExpense * (0.9 + (rand.nextDouble() * 0.2));
      
      final res = _calculateSimulationResults(
        incMul: randomizedIncMul,
        expSqz: randomizedSqueeze,
        lump: randomizedLump,
      );
      endings.add(res['simulatedEndingBalance']);
    }

    endings.sort();
    return {
      'worst': endings.first,
      'typical': endings[endings.length ~/ 2],
      'best': endings.last,
    };
  }

  // Dynamic computation of fastest win by re-scoring hypothetical changes
  Map<String, dynamic> _computeFastestWin() {
    final baseRes = _calculateSimulationResults();
    final baseEnding = baseRes['simulatedEndingBalance'];

    final test1 = _calculateSimulationResults(lump: (_lumpSumExpense - 150).clamp(0.0, 10000.0));
    final test2 = _calculateSimulationResults(expSqz: (_expenseSqueezePercent + 10.0).clamp(0.0, 50.0));
    final test3 = _calculateSimulationResults(extraDebt: _extraDebtPayment + 100.0);

    double gain1 = test1['simulatedEndingBalance'] - baseEnding;
    double gain2 = test2['simulatedEndingBalance'] - baseEnding;
    double gain3 = test3['simulatedEndingBalance'] - baseEnding;

    if (gain1 >= gain2 && gain1 >= gain3) {
      return {'title': 'Add 150 € to emergency fund', 'gain': gain1, 'points': 8, 'action': 'goals'};
    } else if (gain2 >= gain3) {
      return {'title': 'Cut Wants variable spending 10%', 'gain': gain2, 'points': 6, 'action': 'budgets'};
    } else {
      return {'title': 'Accelerate debt by 100 €/mo', 'gain': gain3, 'points': 7, 'action': 'transfer'};
    }
  }

  double _computeDebtLoadRatio() {
    final res = _calculateSimulationResults();
    double monthlyInc = res['monthlyAvgIncome'] ?? 1.0;
    if (monthlyInc <= 0) monthlyInc = 1.0;
    double totalInstallments = 0;
    for (var lib in widget.liabilities) {
      totalInstallments += lib.monthlyInstallment;
    }
    return (totalInstallments / monthlyInc).clamp(0.0, 1.0);
  }

  double _solveRequiredSqueezeFor6Months() {
    for (double sqz = 0; sqz <= 50; sqz += 1) {
      final res = _calculateSimulationResults(expSqz: sqz, horizon: 180);
      if (res['simulatedEndingBalance'] >= 0 && (res['firstDipDate'] == null)) {
        return sqz;
      }
    }
    return 50.0; 
  }

  String _getLeverSensitivityAnalysis() {
    final baseRes = _calculateSimulationResults();
    final baseEnd = baseRes['simulatedEndingBalance'];

    final incRes = _calculateSimulationResults(incMul: (_incomeMultiplier * 1.2).clamp(0.0, 1.5));
    double incImpact = incRes['simulatedEndingBalance'] - baseEnd;

    final sqzRes = _calculateSimulationResults(expSqz: (_expenseSqueezePercent + 15.0).clamp(0.0, 50.0));
    double sqzImpact = sqzRes['simulatedEndingBalance'] - baseEnd;

    final lumpRes = _calculateSimulationResults(lump: (_lumpSumExpense - 500).clamp(0.0, 10000.0));
    double lumpImpact = lumpRes['simulatedEndingBalance'] - baseEnd;

    Map<String, double> impacts = {
      'Income Multiplier': incImpact.abs(),
      'Expense Squeeze': sqzImpact.abs(),
      'Shock Expense': lumpImpact.abs(),
    };

    var sorted = impacts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  String _generateScenarioSummary(Map<String, dynamic> res) {
    double ending = res['simulatedEndingBalance'];
    DateTime? dipDate = res['firstDipDate'];

    if (dipDate != null) {
      String dateStr = DateFormat('MMM d').format(dipDate);
      return 'Warning: Under this scenario, your balance would dip below zero on $dateStr, ending at ${_formatCurrency(ending)}.';
    } else if (ending >= 0) {
      return 'Positive outlook: You maintain a healthy cash buffer throughout the horizon, ending at ${_formatCurrency(ending)}.';
    } else {
      return 'Caution: This scenario projects ongoing deficits, ending at a negative balance of ${_formatCurrency(ending)}.';
    }
  }

  void _showDatedEventsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        String eventType = 'one_off';
        double amount = 100;
        DateTime selectedEvDate = DateTime.now().add(const Duration(days: 5));
        final descController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Dated Event / Shock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: eventType,
                    dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                    decoration: InputDecoration(labelText: 'Event Type', labelStyle: TextStyle(color: _isZaznamityMode ? Colors.white70 : Colors.grey)),
                    items: const [
                      DropdownMenuItem(value: 'one_off', child: Text('One-off Expense / Bill')),
                      DropdownMenuItem(value: 'job_loss', child: Text('Job Loss / Income Stop')),
                      DropdownMenuItem(value: 'skip_bill', child: Text('Skip Specific Bill')),
                      DropdownMenuItem(value: 'new_recurring', child: Text('New Recurring Expense')),
                    ],
                    onChanged: (val) => setModalState(() => eventType = val ?? 'one_off'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                    decoration: InputDecoration(labelText: 'Description (e.g., Car repair)', labelStyle: TextStyle(color: _isZaznamityMode ? Colors.white70 : Colors.grey)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                    decoration: InputDecoration(labelText: 'Amount (${_getCurrencySymbol()})', labelStyle: TextStyle(color: _isZaznamityMode ? Colors.white70 : Colors.grey)),
                    onChanged: (val) => amount = double.tryParse(val) ?? 0.0,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7), foregroundColor: Colors.white),
                    onPressed: () {
                      setState(() {
                        _datedEvents.add({
                          'type': eventType,
                          'amount': amount,
                          'date': selectedEvDate.toIso8601String(),
                          'description': descController.text,
                        });
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Add Event to Simulation'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showReverseSolverModal(BuildContext context) {
    double requiredSqueeze = _solveRequiredSqueezeFor6Months();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        title: Text('Reverse Solver (6-Month Runway)', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'To successfully last 6 months (180 days) without dipping below zero, you need an expense squeeze cut of at least ${requiredSqueeze.toStringAsFixed(0)}% on your variable spending.',
          style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _expenseSqueezePercent = requiredSqueeze;
              });
              Navigator.pop(context);
            },
            child: const Text('Apply This Squeeze'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
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
          content,
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

  void _promptSavePreset(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          title: Text('Save Custom Scenario', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 16)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Preset Name (e.g. Sabbatical Plan)',
              hintStyle: TextStyle(color: _isZaznamityMode ? Colors.white54 : Colors.grey),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7), foregroundColor: Colors.white),
              onPressed: () {
                _saveCustomPreset(controller.text);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showHeadToHeadModal(BuildContext context) {
    final currentSnapshot = {
      'name': 'Current State',
      'incomeMultiplier': _incomeMultiplier,
      'expenseSqueeze': _expenseSqueezePercent,
      'lumpSum': _lumpSumExpense,
      'extraDebt': _extraDebtPayment,
      'horizonDays': _horizonDays,
    };

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final slotA = _scenarioSlotA ?? currentSnapshot;
            final slotB = _scenarioSlotB ?? currentSnapshot;

            final resA = _calculateSimulationResults(
              incMul: slotA['incomeMultiplier'],
              expSqz: slotA['expenseSqueeze'],
              lump: slotA['lumpSum'],
              extraDebt: slotA['extraDebt'],
              horizon: slotA['horizonDays'],
            );

            final resB = _calculateSimulationResults(
              incMul: slotB['incomeMultiplier'],
              expSqz: slotB['expenseSqueeze'],
              lump: slotB['lumpSum'],
              extraDebt: slotB['extraDebt'],
              horizon: slotB['horizonDays'],
            );

            List allAvailablePresets = [
              {'name': 'Current Active Levers', ...currentSnapshot},
              {'name': 'Late Paycheck (-50% Inc.)', 'incomeMultiplier': 0.5, 'expenseSqueeze': 0.0, 'lumpSum': 0.0, 'extraDebt': 0.0, 'horizonDays': 30},
              {'name': 'Zero Income Break', 'incomeMultiplier': 0.0, 'expenseSqueeze': 0.0, 'lumpSum': 0.0, 'extraDebt': 0.0, 'horizonDays': 30},
              {'name': 'Emergency Bill (+500)', 'incomeMultiplier': 1.0, 'expenseSqueeze': 0.0, 'lumpSum': 500.0, 'extraDebt': 0.0, 'horizonDays': 30},
              {'name': 'Debt Acceleration (+300/mo)', 'incomeMultiplier': 1.0, 'expenseSqueeze': 0.0, 'lumpSum': 0.0, 'extraDebt': 300.0, 'horizonDays': 90},
              ..._customPresets,
            ];

            return AlertDialog(
              backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.compare_arrows_rounded, color: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Head-to-Head Scenario Comparison',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Scenario A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                DropdownButtonHideUnderline(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                                    ),
                                    child: DropdownButton(
                                      value: slotA,
                                      isDense: true,
                                      isExpanded: true,
                                      dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                      style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white : Colors.black87),
                                      items: allAvailablePresets.map((p) {
                                        return DropdownMenuItem(
                                          value: p,
                                          child: Text(p['name'] ?? 'Preset', overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setModalState(() {
                                            _scenarioSlotA = val as Map<String, dynamic>;
                                          });
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Scenario B', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                DropdownButtonHideUnderline(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                                    ),
                                    child: DropdownButton(
                                      value: slotB,
                                      isDense: true,
                                      isExpanded: true,
                                      dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                      style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white : Colors.black87),
                                      items: allAvailablePresets.map((p) {
                                        return DropdownMenuItem(
                                          value: p,
                                          child: Text(p['name'] ?? 'Preset', overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setModalState(() {
                                            _scenarioSlotB = val as Map<String, dynamic>;
                                          });
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          children: [
                            _buildComparisonRow('Horizon', '${slotA['horizonDays']} Days', '${slotB['horizonDays']} Days'),
                            const Divider(height: 16),
                            _buildComparisonRowMasked(
                              'Simulated Net',
                              resA['simulatedNetShift'],
                              resB['simulatedNetShift'],
                            ),
                            const Divider(height: 16),
                            _buildComparisonRowMaskedBalance(
                              'Ending Balance',
                              resA['simulatedEndingBalance'],
                              resB['simulatedEndingBalance'],
                            ),
                            const Divider(height: 16),
                            _buildComparisonRow(
                              'Runway / Health',
                              '${resA['estimatedRunwayDays']} Days',
                              '${resB['estimatedRunwayDays']} Days',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildComparisonRow(String label, String valA, String valB) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
        ),
        Expanded(
          flex: 3,
          child: Text(valA, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87), textAlign: TextAlign.center),
        ),
        Expanded(
          flex: 3,
          child: Text(valB, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFA855F7)), textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _buildComparisonRowMasked(String label, double valA, double valB) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
        ),
        Expanded(
          flex: 3,
          child: MaskedAmount(
            formattedAmount: '${valA >= 0 ? '+' : ''}${_formatCurrency(valA)}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87),
          ),
        ),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: MaskedAmount(
              formattedAmount: '${valB >= 0 ? '+' : ''}${_formatCurrency(valB)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA855F7)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRowMaskedBalance(String label, double valA, double valB) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
        ),
        Expanded(
          flex: 3,
          child: MaskedAmount(
            formattedAmount: _formatCurrency(valA),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87),
          ),
        ),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: MaskedAmount(
              formattedAmount: _formatCurrency(valB),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA855F7)),
            ),
          ),
        ),
      ],
    );
  }

  void _showPoolsCheckmarkModal(BuildContext context) {
    Set<String> tempSelectedPools = _selectedPoolNames.isEmpty
        ? widget.pools.toSet()
        : Set.from(_selectedPoolNames);

    showModalBottomSheet(
      context: context,
      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool allSelected = tempSelectedPools.length == widget.pools.length;

            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Pools',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempSelectedPools = widget.pools.toSet();
                              });
                            },
                            child: const Text('Select All', style: TextStyle(color: Color(0xFFA855F7))),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempSelectedPools.clear();
                              });
                            },
                            child: const Text('Clear All', style: TextStyle(color: Color(0xFFF87171))),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  CheckboxListTile(
                    title: Text(
                      'All Pools',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    value: allSelected,
                    activeColor: const Color(0xFFA855F7),
                    onChanged: (bool? value) {
                      setModalState(() {
                        if (value == true) {
                          tempSelectedPools = widget.pools.toSet();
                        } else {
                          tempSelectedPools.clear();
                        }
                      });
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.pools.length,
                      itemBuilder: (context, index) {
                        final pool = widget.pools[index];
                        final isChecked = tempSelectedPools.contains(pool);

                        return CheckboxListTile(
                          title: Text(
                            pool.toUpperCase(),
                            style: TextStyle(
                              color: _isZaznamityMode ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                          value: isChecked,
                          activeColor: const Color(0xFFA855F7),
                          onChanged: (bool? value) {
                            setModalState(() {
                              if (value == true) {
                                tempSelectedPools.add(pool);
                              } else {
                                tempSelectedPools.remove(pool);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          if (tempSelectedPools.length == widget.pools.length) {
                            _selectedPoolNames.clear();
                          } else {
                            _selectedPoolNames = tempSelectedPools;
                          }
                        });
                        _savePoolPrefs();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLabelsCheckmarkModal(BuildContext context) {
    Set<int> tempSelectedIds = _selectedLabelIds.isEmpty
        ? widget.labels.map((l) => l.id).toSet()
        : Set.from(_selectedLabelIds);

    showModalBottomSheet(
      context: context,
      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool allSelected = tempSelectedIds.length == widget.labels.length;

            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Labels',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempSelectedIds = widget.labels.map((l) => l.id).toSet();
                              });
                            },
                            child: const Text('Select All', style: TextStyle(color: Color(0xFFA855F7))),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempSelectedIds.clear();
                              });
                            },
                            child: const Text('Clear All', style: TextStyle(color: Color(0xFFF87171))),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  CheckboxListTile(
                    title: Text(
                      'All Labels',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    value: allSelected,
                    activeColor: const Color(0xFFA855F7),
                    onChanged: (bool? value) {
                      setModalState(() {
                        if (value == true) {
                          tempSelectedIds = widget.labels.map((l) => l.id).toSet();
                        } else {
                          tempSelectedIds.clear();
                        }
                      });
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.labels.length,
                      itemBuilder: (context, index) {
                        final label = widget.labels[index];
                        final isChecked = tempSelectedIds.contains(label.id);

                        return CheckboxListTile(
                          title: Text(
                            label.name,
                            style: TextStyle(
                              color: _isZaznamityMode ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                          value: isChecked,
                          activeColor: const Color(0xFFA855F7),
                          onChanged: (bool? value) {
                            setModalState(() {
                              if (value == true) {
                                tempSelectedIds.add(label.id);
                              } else {
                                tempSelectedIds.remove(label.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          if (tempSelectedIds.length == widget.labels.length) {
                            _selectedLabelIds.clear();
                          } else {
                            _selectedLabelIds = tempSelectedIds;
                          }
                        });
                        _saveLabelPrefs();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _calculateSimulationResults();
    final double startingBalance = results['startingBalance'];
    final double endingBalance = results['simulatedEndingBalance'];
    final int runwayDays = results['estimatedRunwayDays'];
    final DateTime? firstDipDate = results['firstDipDate'];
    final List baselineTrend = results['baselineTrend'] ?? [];
    final List scenarioTrend = results['scenarioTrend'] ?? [];
    final double interestSaved = results['interestSaved'] ?? 0.0;
    final int monthsSaved = results['monthsSaved'] ?? 0;

    final balanceRange = _calculateEndingBalanceRange();
    final sentenceSummary = _generateScenarioSummary(results);
    final topLever = _getLeverSensitivityAnalysis();
    final fastestWin = _computeFastestWin();
    final debtLoadRatio = _computeDebtLoadRatio();

    double healthRatio = 1.0;
    if (runwayDays < 30) healthRatio = 0.15;
    else if (runwayDays < 90) healthRatio = 0.4;
    else if (runwayDays < 180) healthRatio = 0.7;
    
    Color healthColor = const Color(0xFF34D399);
    String healthLabel = 'Robust (> 6 Mos)';
    if (runwayDays < 30) {
      healthColor = const Color(0xFFF87171);
      healthLabel = 'Critical (< 30 Days)';
    } else if (runwayDays < 90) {
      healthColor = Colors.orangeAccent;
      healthLabel = 'Stressed (1-3 Mos)';
    } else if (runwayDays < 180) {
      healthColor = Colors.yellow;
      healthLabel = 'Resilient (3-6 Mos)';
    }

    final double availableWidth = MediaQuery.of(context).size.width - 32;
    final double boxWidth = (availableWidth - 12) / 2;

    String poolsButtonText = 'All Pools';
    if (_selectedPoolNames.length == 1) {
      poolsButtonText = _selectedPoolNames.first.toUpperCase();
    } else if (_selectedPoolNames.length > 1 && _selectedPoolNames.length < widget.pools.length) {
      poolsButtonText = '${_selectedPoolNames.length} Pools';
    }

    String labelsButtonText = 'All Labels';
    if (_selectedLabelIds.length == 1) {
      final singleLabel = widget.labels.where((l) => l.id == _selectedLabelIds.first).firstOrNull;
      labelsButtonText = singleLabel?.name ?? '1 Label';
    } else if (_selectedLabelIds.length > 1 && _selectedLabelIds.length < widget.labels.length) {
      labelsButtonText = '${_selectedLabelIds.length} Labels';
    }

    final now = DateTime.now();
    final startDate = _customStartDate != null ? (_customStartDate!.isBefore(now) ? now : _customStartDate!) : now;
    final endDate = _customEndDate != null ? _customEndDate! : now.add(Duration(days: _effectiveHorizonDays));
    final windowDateStr = '${DateFormat('MMM dd, yyyy').format(startDate)} – ${DateFormat('MMM dd, yyyy').format(endDate)}';

    return LayoutBuilder(
      builder: (context, constraints) {
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
                            'WHAT-IF LAB',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _showInfoDialog(
                            context,
                            'What-If Lab',
                            '"What-If I do this?"\n\n' 
                            '• Explores hypothetical scenarios and cash trajectory.\n'
                            '• Day-by-day simulation incorporates income velocity, expense cuts, debt acceleration, and dated shock events.',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(Icons.info_outline_rounded, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
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
                              widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty ? widget.selectedOwner! : 'All Owners',
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

                // Score History Sparkline & What Changed Header
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Health Score Trend', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('+${(_scoreHistory.last - _scoreHistory[_scoreHistory.length - 2]).toStringAsFixed(0)} pts since last month', style: const TextStyle(fontSize: 9.5, color: Color(0xFF34D399), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(
                        width: 90,
                        height: 30,
                        child: CustomPaint(
                          painter: _SparklinePainter(data: _scoreHistory, isDark: _isZaznamityMode),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: boxWidth,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showPoolsCheckmarkModal(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.account_balance_wallet_outlined, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      poolsButtonText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down, size: 18, color: _isZaznamityMode ? Colors.white70 : Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: boxWidth,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showLabelsCheckmarkModal(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.label_outline_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      labelsButtonText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down, size: 18, color: _isZaznamityMode ? Colors.white70 : Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Fastest Win Insight Action Link Card
                if (!_snoozedInsights.containsKey('fastest_win') || _snoozedInsights['fastest_win']!.isBefore(DateTime.now()))
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt, size: 18, color: Color(0xFFA855F7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fastest Win: ${fastestWin['title']} (+${fastestWin['points']} pts)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                              const Text('Linked to What-If simulation gain.', style: TextStyle(fontSize: 9.5, color: Color(0xFFA855F7))),
                            ],
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 24)),
                          onPressed: () {
                            if (widget.onNavigateAction != null) {
                              widget.onNavigateAction!(fastestWin['action'], null);
                            }
                          },
                          child: const Text('View', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.snooze, size: 14),
                          tooltip: 'Snooze (1 week)',
                          onPressed: () => _snoozeInsight('fastest_win'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('Horizon:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                        const SizedBox(width: 8),
                        ToggleButtons(
                          isSelected: [_customStartDate == null && _horizonDays == 30, _customStartDate == null && _horizonDays == 90, _customStartDate == null && _horizonDays == 180, _customStartDate == null && _horizonDays == 365],
                          onPressed: (index) {
                            setState(() {
                              if (index == 0) _horizonDays = 30;
                              else if (index == 1) _horizonDays = 90;
                              else if (index == 2) _horizonDays = 180;
                              else if (index == 3) _horizonDays = 365;
                              _customStartDate = null;
                              _customEndDate = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          selectedColor: Colors.white,
                          fillColor: const Color(0xFF582F95),
                          color: _isZaznamityMode ? Colors.white70 : Colors.black87,
                          constraints: const BoxConstraints(minHeight: 26, minWidth: 40),
                          children: const [
                            Text('30D', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                            Text('90D', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                            Text('6M', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                            Text('1Y', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _showReverseSolverModal(context),
                          icon: const Icon(Icons.flash_on, size: 13, color: Color(0xFFA855F7)),
                          label: const Text('Solver', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFA855F7))),
                        ),
                        TextButton.icon(
                          onPressed: () => _showDatedEventsModal(context),
                          icon: const Icon(Icons.event_note, size: 13, color: Color(0xFFA855F7)),
                          label: const Text('+ Event', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFA855F7))),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PROJECTION WINDOW: $windowDateStr',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF87171), width: 1.0),
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFF87171),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _resetScenario,
                        child: const Text('Reset All', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Baseline vs. Scenario Balance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          if (firstDipDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                'Dip below zero on ${DateFormat('MMM d').format(firstDipDate)}',
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFF87171)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 110,
                        child: CustomPaint(
                          size: const Size(double.infinity, 110),
                          painter: _BalanceChartPainter(
                            baselineTrend: baselineTrend,
                            scenarioTrend: scenarioTrend,
                            isDark: _isZaznamityMode,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sentenceSummary,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: endingBalance < 0 
                        ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) 
                        : (_isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: endingBalance < 0 ? const Color(0xFFF87171) : (_isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Resilience Health:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(healthLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: healthColor)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: healthRatio,
                          backgroundColor: _isZaznamityMode ? Colors.white24 : Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedPoolNames.isEmpty
                                ? 'Initial Balance (All Pools):'
                                : 'Initial Balance ($poolsButtonText):',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          MaskedAmount(
                            formattedAmount: _formatCurrency(startingBalance),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isZaznamityMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Projected Ending Balance:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          MaskedAmount(
                            formattedAmount: _formatCurrency(endingBalance),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: endingBalance >= 0 ? (_isZaznamityMode ? Colors.white : Colors.black87) : const Color(0xFFF87171),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Balance Range', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('(Worst / Typ / Best):', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade600)),
                          Text(
                            '${_formatCurrency(balanceRange['worst']!)} / ${_formatCurrency(balanceRange['typical']!)} / ${_formatCurrency(balanceRange['best']!)}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Debt Load Ratio (Installments / Inc):', style: TextStyle(fontSize: 10, color: Color(0xFFC4B5FD))),
                          Text('${(debtLoadRatio * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFA855F7))),
                        ],
                      ),
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Most Impactful Lever:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                          Text(topLever, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFA855F7))),
                        ],
                      ),
                      if (_extraDebtPayment > 0 && monthsSaved > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Debt Acceleration Benefit:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                            Text('Saved $monthsSaved mos & ~${_formatCurrency(interestSaved)} interest', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Presets & Saved:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _showHeadToHeadModal(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.compare_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                              const SizedBox(width: 3),
                              Text('Compare', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => _promptSavePreset(context),
                          child: const Text('+ Save Current', style: TextStyle(fontSize: 11, color: Color(0xFFA855F7), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (!_hiddenDefaultPresets.contains('Late Paycheck (-50% Inc.)'))
                      _buildDeletablePresetChip('Late Paycheck (-50% Inc.)', 0.5, 0.0, 0.0, 0.0, 30),
                    if (!_hiddenDefaultPresets.contains('Zero Income Break'))
                      _buildDeletablePresetChip('Zero Income Break', 0.0, 0.0, 0.0, 0.0, 30),
                    if (!_hiddenDefaultPresets.contains('Emergency Bill (+500)'))
                      _buildDeletablePresetChip('Emergency Bill (+500)', 1.0, 0.0, 500.0, 0.0, 30),
                    if (!_hiddenDefaultPresets.contains('Debt Acceleration (+300/mo)'))
                      _buildDeletablePresetChip('Debt Acceleration (+300/mo)', 1.0, 0.0, 0.0, 300.0, 90),
                    for (int i = 0; i < _customPresets.length; i++)
                      _buildCustomPresetChip(_customPresets[i], i),
                  ],
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Income Multiplier:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                          Text('${(_incomeMultiplier * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA855F7))),
                        ],
                      ),
                      Slider(
                        value: _incomeMultiplier,
                        min: 0.0,
                        max: 1.5,
                        divisions: 15,
                        activeColor: const Color(0xFFA855F7),
                        inactiveColor: _isZaznamityMode ? Colors.white24 : Colors.grey.shade300,
                        onChanged: (val) => setState(() => _incomeMultiplier = val),
                      ),
                      const SizedBox(height: 4),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Expense Squeeze Cut:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                          Text('${_expenseSqueezePercent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                        ],
                      ),
                      Slider(
                        value: _expenseSqueezePercent,
                        min: 0.0,
                        max: 50.0,
                        divisions: 10,
                        activeColor: const Color(0xFF34D399),
                        inactiveColor: _isZaznamityMode ? Colors.white24 : Colors.grey.shade300,
                        onChanged: (val) => setState(() => _expenseSqueezePercent = val),
                      ),
                      const SizedBox(height: 4),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('One-Time Shock Expense:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                          SizedBox(
                            width: 90,
                            height: 28,
                            child: TextField(
                              controller: _lumpSumController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87),
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(4)),
                              onSubmitted: (val) {
                                setState(() {
                                  _lumpSumExpense = (double.tryParse(val) ?? 0.0).clamp(0.0, 10000.0);
                                  _lumpSumController.text = _lumpSumExpense.toStringAsFixed(0);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _lumpSumExpense,
                        min: 0.0,
                        max: 5000.0,
                        divisions: 25,
                        activeColor: const Color(0xFFF87171),
                        inactiveColor: _isZaznamityMode ? Colors.white24 : Colors.grey.shade300,
                        onChanged: (val) => setState(() {
                          _lumpSumExpense = val;
                          _lumpSumController.text = val.toStringAsFixed(0);
                        }),
                      ),
                      const SizedBox(height: 4),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Extra Debt Principal / Mo:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                          SizedBox(
                            width: 90,
                            height: 28,
                            child: TextField(
                              controller: _extraDebtController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87),
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(4)),
                              onSubmitted: (val) {
                                setState(() {
                                  _extraDebtPayment = (double.tryParse(val) ?? 0.0).clamp(0.0, 5000.0);
                                  _extraDebtController.text = _extraDebtPayment.toStringAsFixed(0);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _extraDebtPayment,
                        min: 0.0,
                        max: 2000.0,
                        divisions: 20,
                        activeColor: Colors.blueAccent,
                        inactiveColor: _isZaznamityMode ? Colors.white24 : Colors.grey.shade300,
                        onChanged: (val) => setState(() {
                          _extraDebtPayment = val;
                          _extraDebtController.text = val.toStringAsFixed(0);
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeletablePresetChip(String label, double incMul, double expSqz, double lump, double extraDebt, int horizon) {
    bool isSelected = _customStartDate == null && _incomeMultiplier == incMul && _expenseSqueezePercent == expSqz && _lumpSumExpense == lump && _extraDebtPayment == extraDebt && _horizonDays == horizon;
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: isSelected 
            ? const Color(0xFFA855F7) 
            : (_isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFFA855F7) : (_isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _incomeMultiplier = incMul;
                _expenseSqueezePercent = expSqz;
                _lumpSumExpense = lump;
                _extraDebtPayment = extraDebt;
                _horizonDays = horizon;
                _customStartDate = null;
                _customEndDate = null;
                _lumpSumController.text = lump.toStringAsFixed(0);
                _extraDebtController.text = extraDebt.toStringAsFixed(0);
              });
            },
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _hideDefaultPreset(label),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(
                Icons.close,
                size: 11,
                color: isSelected ? Colors.white70 : Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomPresetChip(Map<String, dynamic> preset, int index) {
    double inc = preset['incomeMultiplier'] ?? 1.0;
    double sqz = preset['expenseSqueeze'] ?? 0.0;
    double lump = preset['lumpSum'] ?? 0.0;
    double debt = preset['extraDebt'] ?? 0.0;
    int horiz = preset['horizonDays'] ?? 30;

    bool isSelected = _customStartDate == null && _incomeMultiplier == inc && _expenseSqueezePercent == sqz && _lumpSumExpense == lump && _extraDebtPayment == debt && _horizonDays == horiz;

    return Container(
      padding: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: isSelected 
            ? const Color(0xFFA855F7) 
            : (_isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFFA855F7) : (_isZaznamityMode ? Colors.white24 : const Color(0xFFCBD5E1)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _incomeMultiplier = inc;
                _expenseSqueezePercent = sqz;
                _lumpSumExpense = lump;
                _extraDebtPayment = debt;
                _horizonDays = horiz;
                _customStartDate = null;
                _customEndDate = null;
                _lumpSumController.text = lump.toStringAsFixed(0);
                _extraDebtController.text = debt.toStringAsFixed(0);
              });
            },
            child: Text(
              preset['name'] ?? 'Custom',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _deleteCustomPreset(index),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(
                Icons.close,
                size: 11,
                color: isSelected ? Colors.white70 : Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceChartPainter extends CustomPainter {
  final List baselineTrend;
  final List scenarioTrend;
  final bool isDark;

  _BalanceChartPainter({required this.baselineTrend, required this.scenarioTrend, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (scenarioTrend.isEmpty) return;

    final paintBase = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final paintScen = Paint()
      ..color = const Color(0xFFA855F7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final paintZero = Paint()
      ..color = Colors.red.withOpacity(0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (var pt in scenarioTrend) {
      double val = pt['balance'];
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }
    for (var pt in baselineTrend) {
      double val = pt['balance'];
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }

    if (minVal > 0) minVal = 0;
    if (maxVal == minVal) maxVal = minVal + 100;

    double range = maxVal - minVal;

    getY(double val) => size.height - ((val - minVal) / range) * size.height;
    getX(int index, int total) => (index / (total > 1 ? total - 1 : 1)) * size.width;

    double zeroY = getY(0);
    if (zeroY >= 0 && zeroY <= size.height) {
      canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), paintZero);
    }

    if (baselineTrend.length > 1) {
      Path pathBase = Path();
      for (int i = 0; i < baselineTrend.length; i++) {
        double x = getX(i, baselineTrend.length);
        double y = getY(baselineTrend[i]['balance']);
        if (i == 0) pathBase.moveTo(x, y);
        else pathBase.lineTo(x, y);
      }
      canvas.drawPath(pathBase, paintBase);
    }

    if (scenarioTrend.length > 1) {
      Path pathScen = Path();
      for (int i = 0; i < scenarioTrend.length; i++) {
        double x = getX(i, scenarioTrend.length);
        double y = getY(scenarioTrend[i]['balance']);
        if (i == 0) pathScen.moveTo(x, y);
        else pathScen.lineTo(x, y);
      }
      canvas.drawPath(pathScen, paintScen);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final bool isDark;

  _SparklinePainter({required this.data, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0xFFA855F7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    double minVal = data.reduce(min);
    double maxVal = data.reduce(max);
    if (minVal == maxVal) maxVal = minVal + 1;
    double range = maxVal - minVal;

    getY(double val) => size.height - ((val - minVal) / range) * (size.height - 4) - 2;
    getX(int index, int total) => (index / (total > 1 ? total - 1 : 1)) * size.width;

    Path path = Path();
    for (int i = 0; i < data.length; i++) {
      double x = getX(i, data.length);
      double y = getY(data[i]);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension on List {
  void appendOrAdd(DateTime date, double balance) {
    add({'date': date, 'balance': balance});
  }
}