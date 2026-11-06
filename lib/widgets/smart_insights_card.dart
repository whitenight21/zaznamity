// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';
import '../models/savings_goal_model.dart';
import '../widgets/masked_amount.dart';
import '../services/privacy_service.dart';

class SmartInsightsCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<dynamic> budgets;
  final List<dynamic> liabilities; // Accepts LiabilityItem or map list
  final List<SavingsGoalModel> savingsGoals;
  final Map<String, double> futureFlowByOwner;
  final Map<String, double> prognosisByOwner;
  final String? selectedOwner;
  final Function(int? labelId, String? owner, DateTime? start, DateTime? end)? onJumpToHistory;
  final VoidCallback? onJumpToBudgets;

  const SmartInsightsCard({
    super.key,
    required this.transactions,
    required this.labels,
    required this.budgets,
    required this.liabilities,
    required this.savingsGoals,
    required this.futureFlowByOwner,
    required this.prognosisByOwner,
    this.selectedOwner,
    this.onJumpToHistory,
    this.onJumpToBudgets,
  });

  @override
  State<SmartInsightsCard> createState() => _SmartInsightsCardState();
}

class _AppThemeColors {
  final bool isZaznamity;
  const _AppThemeColors(this.isZaznamity);

  Color get background => isZaznamity ? Colors.black : Colors.white;
  Color get cardBackground => isZaznamity ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC);
  Color get containerBorder => isZaznamity ? Colors.white12 : const Color(0xFFCBD5E1);
  Color get textPrimary => isZaznamity ? Colors.white : const Color(0xFF1E293B);
  Color get textSecondary => isZaznamity ? const Color(0xFFC4B5FD) : const Color(0xFF64748B);
  Color get accent => isZaznamity ? const Color(0xFFA855F7) : const Color(0xFF582F95);
  Color get dialogBackground => isZaznamity ? const Color(0xFF2D1B4E) : Colors.white;
}

class _SmartInsightsCardState extends State<SmartInsightsCard> {
  bool _isZaznamityMode = true;
  bool _excludeTransfers = true;
  bool _excludeTransfersForBalance = false;
  bool _isCollapsed = false;
  String _primaryCurrency = 'USD';
  final Map<String, bool> _multiLabelFixedCategories = {};
  
  // Selected pools normalized to lowercase
  Set<String> _selectedRunwayPools = {'checking', 'cash', 'savings'};

  final Set<String> _dismissedInsights = {};
  Map<String, dynamic>? _cachedAnalysis;
  String? _lastTxFingerprint;
  String? _lastOwner;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void didUpdateWidget(covariant SmartInsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedOwner != widget.selectedOwner ||
        oldWidget.transactions.length != widget.transactions.length ||
        oldWidget.budgets.length != widget.budgets.length ||
        oldWidget.liabilities.length != widget.liabilities.length ||
        oldWidget.savingsGoals.length != widget.savingsGoals.length ||
        oldWidget.labels.length != widget.labels.length) {
      _computeDataIfNeeded(force: true);
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final primary = prefs.getString('primaryCurrency') ?? 'USD';
    final collapsed = prefs.getBool('set_smartInsights_collapsed') ?? false;
    final savedPoolsStr = prefs.getString('smart_insights_runway_pools');
    
    if (savedPoolsStr != null) {
      _selectedRunwayPools = savedPoolsStr
          .split(',')
          .map((p) => p.trim().toLowerCase())
          .where((p) => p.isNotEmpty)
          .toSet();
    } else {
      final oldInc = prefs.getBool('include_savings_emergency') ?? false;
      _selectedRunwayPools = {'checking', 'cash'};
      if (oldInc) _selectedRunwayPools.add('savings');
    }
    
    _multiLabelFixedCategories.clear();
    for (var label in widget.labels) {
      _multiLabelFixedCategories[label.name] = prefs.getBool('set_multilabel_fixed_${label.name}') ?? false;
    }

    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _excludeTransfers = prefs.getBool('exclude_transfers_insights') ?? true;
        _excludeTransfersForBalance = prefs.getBool('exclude_transfers_balance') ?? false;
        _primaryCurrency = primary;
        _isCollapsed = collapsed;
      });
      _computeDataIfNeeded(force: true);
    }
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_smartInsights_collapsed', _isCollapsed);
  }

  Future<void> _saveRunwayPools(Set<String> pools) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('smart_insights_runway_pools', pools.join(','));
    setState(() {
      _selectedRunwayPools = Set.from(pools);
      _computeDataIfNeeded(force: true);
    });
  }

  void _showPoolSelectorDialog(BuildContext context) {
    final theme = _AppThemeColors(_isZaznamityMode);
    
    final Set<String> availablePools = {'checking', 'cash', 'savings'};
    for (var tx in widget.transactions) {
      if (tx.pool != null && tx.pool!.trim().isNotEmpty) {
        availablePools.add(tx.pool!.trim().toLowerCase());
      }
    }

    final Set<String> tempSelected = Set.from(_selectedRunwayPools);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.dialogBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Select Runway Pools',
            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SizedBox(
            width: 300,
            child: ListView(
              shrinkWrap: true,
              children: availablePools.map((pool) {
                final isSelected = tempSelected.contains(pool);
                return CheckboxListTile(
                  title: Text(
                    pool.toUpperCase(),
                    style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  value: isSelected,
                  activeColor: theme.accent,
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) {
                        tempSelected.add(pool);
                      } else {
                        tempSelected.remove(pool);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                _saveRunwayPools(tempSelected);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': 
      case 'CNY': return '¥';
      case 'CAD': return 'C\$';
      case 'AUD': return 'A\$';
      case 'HKD': return 'HK\$';
      case 'SGD': return 'S\$';
      case 'CZK': return 'Kč';
      case 'HUF': return 'Ft';
      case 'PLN': return 'zł';
      case 'CHF': return 'CHF';
      case 'RUB': return '₽';
      case 'BRL': return 'R\$';
      default: return '€';
    }
  }

  double _normalizeAmount(double amount, String? txCurrency) {
    if (txCurrency == null || txCurrency.isEmpty || txCurrency.toUpperCase() == _primaryCurrency.toUpperCase()) {
      return amount;
    }
    return amount; 
  }

  String _formatCurrency(double amount) {
    final symbol = _getCurrencySymbol(_primaryCurrency);
    final format = NumberFormat('#,##0.00', 'en_US');
    return '${format.format(amount)} $symbol';
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

  bool _isSavingsLabel(String labelName) {
    final lower = labelName.toLowerCase();
    return lower.contains('saving') || lower.contains('goal') || lower.contains('investment');
  }

  String _createTxFingerprint(List<TransactionModel> txs) {
    final sb = StringBuffer();
    sb.write(txs.length);
    sb.write('_');
    for (var tx in txs) {
      sb.write('${tx.id}:${tx.amount}:${tx.createdAt}:${tx.labelId}:${tx.pool};');
    }
    return sb.toString();
  }

  void _computeDataIfNeeded({bool force = false}) {
    final currentFingerprint = _createTxFingerprint(widget.transactions);
    if (!force && _cachedAnalysis != null && _lastTxFingerprint == currentFingerprint && _lastOwner == widget.selectedOwner) {
      return;
    }

    _lastTxFingerprint = currentFingerprint;
    _lastOwner = widget.selectedOwner;
    _cachedAnalysis = _runCalculations();
  }

  Map<String, dynamic> _runCalculations() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final int daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
    final int currentDay = now.day;
    final double monthProgressRatio = currentDay / daysInMonth;

    double currentMonthExpense = 0;
    double currentMonthIncome = 0;
    double prevMonthExpense = 0;
    double currentMonthExpenseToDate = 0;
    double prevMonthExpenseToDate = 0;
    double prevMonthIncomeToDate = 0;

    final int prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;
    final int prevYear = currentMonth == 1 ? currentYear - 1 : currentYear;

    Map<int, double> labelExpenses = {};
    double totalLiquidChecking = 0;
    double scheduledNetRestOfMonth = 0;

    double needsExpense = 0;
    double wantsExpense = 0;
    double savingsContribution = 0;

    double fixedOverhead = 0;
    double variableSpending = 0;
    bool hasFixedCategoriesConfigured = false;

    Map<String, Map<int, double>> recurringDescHistory = {};
    final Map<int, LabelModel> labelMap = {for (var l in widget.labels) l.id: l};
    final fallbackLabel = LabelModel(id: 0, name: 'General', color: '#64748B');

    double trailing3MIncome = 0;
    double trailing3MExpense = 0;
    final DateTime threeMonthsAgo = DateTime(currentYear, currentMonth - 3, 1);
    double spentToday = 0;

    for (var tx in widget.transactions) {
      if (widget.selectedOwner != null &&
          widget.selectedOwner!.isNotEmpty &&
          widget.selectedOwner != 'All Owners' &&
          tx.owner != widget.selectedOwner) {
        continue;
      }

      final dt = DateTime.tryParse(tx.createdAt);
      final LabelModel matchLbl = labelMap[tx.labelId] ?? fallbackLabel;
      final String labelName = matchLbl.name.toLowerCase();

      if (_isFixedExpenseLabel(matchLbl)) {
        hasFixedCategoriesConfigured = true;
      }

      final String poolLower = (tx.pool ?? '').toLowerCase().trim();
      bool isTransfer = labelName == 'transfer';
      double normalizedAmount = _normalizeAmount(tx.amount, null);

      if (dt != null && !dt.isAfter(now)) {
        if (!(_excludeTransfersForBalance && isTransfer)) {
          double signedAmt = tx.type == 'income' ? normalizedAmount : -normalizedAmount;
          if (_selectedRunwayPools.contains(poolLower) || (_selectedRunwayPools.contains('savings') && _isSavingsLabel(labelName))) {
            totalLiquidChecking += signedAmt;
          }
        }
      }

      if (_excludeTransfers && isTransfer) {
        continue;
      }

      if (tx.isConfirmed != 1) {
        if (dt != null && dt.year == currentYear && dt.month == currentMonth && dt.isAfter(now)) {
          double signedAmt = tx.type == 'income' ? normalizedAmount : -normalizedAmount;
          scheduledNetRestOfMonth += signedAmt;
        }
        continue;
      }

      if (dt == null) continue;

      if (tx.type == 'expense' && _isFixedExpenseLabel(matchLbl)) {
        int monthKey = dt.year * 12 + dt.month;
        String descKey = tx.description.isNotEmpty ? tx.description.trim().toLowerCase() : matchLbl.name.toLowerCase();
        recurringDescHistory.putIfAbsent(descKey, () => {});
        recurringDescHistory[descKey]![monthKey] = (recurringDescHistory[descKey]![monthKey] ?? 0) + normalizedAmount;
      }

      if (!dt.isBefore(threeMonthsAgo) && dt.isBefore(DateTime(currentYear, currentMonth, 1))) {
        if (tx.type == 'income') trailing3MIncome += normalizedAmount;
        if (tx.type == 'expense') trailing3MExpense += normalizedAmount;
      }

      if (dt.year == currentYear && dt.month == currentMonth) {
        if (tx.type == 'expense') {
          bool isSavings = _isSavingsLabel(matchLbl.name);
          
          if (!isSavings) {
            currentMonthExpense += normalizedAmount;
            if (dt.day <= currentDay) currentMonthExpenseToDate += normalizedAmount;
            if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
              spentToday += normalizedAmount;
            }

            bool isFixed = _isFixedExpenseLabel(matchLbl);
            if (!isFixed) {
              labelExpenses[tx.labelId] = (labelExpenses[tx.labelId] ?? 0) + normalizedAmount;
            }

            if (isFixed) {
              fixedOverhead += normalizedAmount;
              needsExpense += normalizedAmount;
            } else {
              variableSpending += normalizedAmount;
              wantsExpense += normalizedAmount;
            }
          } else {
            savingsContribution += normalizedAmount;
          }
        }
        if (tx.type == 'income') currentMonthIncome += normalizedAmount;
      } else if (dt.year == prevYear && dt.month == prevMonth) {
        if (tx.type == 'expense') {
          prevMonthExpense += normalizedAmount;
          if (dt.day <= currentDay) prevMonthExpenseToDate += normalizedAmount;
        }
        if (tx.type == 'income') {
          if (dt.day <= currentDay) prevMonthIncomeToDate += normalizedAmount;
        }
      }
    }

    // --- COMMITTED THIS MONTH CALCULATION ---
    double totalBudgetsCommitted = 0;
    for (var b in widget.budgets) {
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners') {
        final ownerField = b['owner']?.toString().trim() ?? '';
        if (ownerField.toLowerCase() != widget.selectedOwner!.trim().toLowerCase()) continue;
      }
      totalBudgetsCommitted += ((b['limit_amount'] ?? b['limitAmount'] ?? 0) as num).toDouble();
    }

    double totalLiabilitiesCommitted = 0;
    for (var l in widget.liabilities) {
      String ownerVal = '';
      double installmentVal = 0;
      if (l is Map) {
        ownerVal = l['owner']?.toString() ?? 'Shared';
        installmentVal = ((l['monthly_installment'] ?? l['monthlyInstallment'] ?? 0) as num).toDouble();
      } else {
        ownerVal = l.owner;
        installmentVal = l.monthlyInstallment;
      }

      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners') {
        if (ownerVal.trim().toLowerCase() != widget.selectedOwner!.trim().toLowerCase()) continue;
      }
      totalLiabilitiesCommitted += installmentVal;
    }

    double totalSavingsCommitted = 0;
    for (var g in widget.savingsGoals) {
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners') {
        if (g.owner.trim().toLowerCase() != widget.selectedOwner!.trim().toLowerCase()) continue;
      }
      totalSavingsCommitted += g.monthlyContribution;
    }

    double totalCommittedThisMonth = totalBudgetsCommitted + totalLiabilitiesCommitted + totalSavingsCommitted;
    double effectiveIncomeForCommitment = currentMonthIncome > 0 ? currentMonthIncome : (trailing3MIncome > 0 ? (trailing3MIncome / 3.0) : totalCommittedThisMonth);
    double freeToSpend = effectiveIncomeForCommitment - totalCommittedThisMonth;

    if (!hasFixedCategoriesConfigured && currentMonthExpense > 0) {
      needsExpense = 0;
      wantsExpense = currentMonthExpense;
      fixedOverhead = 0;
      variableSpending = currentMonthExpense;
    }

    double expenseDiffPercent = 0;
    if (prevMonthExpenseToDate > 0) {
      expenseDiffPercent = ((currentMonthExpenseToDate - prevMonthExpenseToDate) / prevMonthExpenseToDate) * 100;
    }

    double trailingSavingsRate = trailing3MIncome > 0
        ? ((trailing3MIncome - trailing3MExpense) / trailing3MIncome) * 100
        : (currentMonthIncome > 0 ? ((currentMonthIncome - currentMonthExpense) / currentMonthIncome) * 100 : 0.0);

    double monthlyBurnBaseline = prevMonthExpense > 0 ? prevMonthExpense : (currentMonthExpense > 0 ? currentMonthExpense : 1.0);
    double emergencyRunwayMonths = totalLiquidChecking > 0 ? (totalLiquidChecking / monthlyBurnBaseline) : 0.0;

    final double daysLeft = (daysInMonth - currentDay + 1).clamp(1, 31).toDouble();
    final double spendable = (totalLiquidChecking + scheduledNetRestOfMonth) * 0.8;
    double targetBufferAllowance = spendable.clamp(0.0, double.infinity) / daysLeft;

    double dailyAverageBurn = monthlyBurnBaseline / 30.0;
    double moneyRunwayDays = dailyAverageBurn > 0 ? (totalLiquidChecking / dailyAverageBurn) : (totalLiquidChecking > 0 ? 999.0 : 0.0);

    double currentNetToDate = currentMonthIncome - currentMonthExpenseToDate;
    double prevNetToDate = prevMonthIncomeToDate - prevMonthExpenseToDate;
    double netCashflowVelocityDelta = currentNetToDate - prevNetToDate;

    String topCulpritLabel = 'None';
    double topCulpritAmount = 0;
    int? topCulpritLabelId;
    if (labelExpenses.isNotEmpty) {
      var sortedLabels = labelExpenses.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      topCulpritLabelId = sortedLabels.first.key;
      topCulpritAmount = sortedLabels.first.value;
      
      final matchingLabel = labelMap[topCulpritLabelId];
      if (matchingLabel != null) topCulpritLabel = matchingLabel.name;
    }

    List rawInsights = [];

    int currentMonthKey = currentYear * 12 + currentMonth;
    int prevMonthKey = prevYear * 12 + prevMonth;
    
    recurringDescHistory.forEach((descKey, history) {
      double? currVal = history[currentMonthKey];
      double? prevVal = history[prevMonthKey];
      if (currVal != null && prevVal != null && prevVal > 0) {
        double hikePct = ((currVal - prevVal) / prevVal) * 100;
        if (hikePct >= 5) {
          rawInsights.add({
            'id': 'hike_$descKey',
            'severity': 3,
            'type': 'warning',
            'icon': Icons.trending_up_rounded,
            'title': 'Price Hike Detected: $descKey',
            'message': 'Recurring payment "$descKey" increased by ${hikePct.toStringAsFixed(0)}% (${_formatCurrency(prevVal)} → ${_formatCurrency(currVal)}).',
            'action': 'Review subscription terms',
            'onAction': () => widget.onJumpToBudgets?.call(),
          });
        }
      }
    });

    double flexibleBudgetCeiling = currentMonthIncome > 0 ? (currentMonthIncome * 0.3) : (currentMonthExpense * 0.4);
    if (flexibleBudgetCeiling > 0 && monthProgressRatio > 0) {
      double flexibleSpendRatio = (wantsExpense / flexibleBudgetCeiling);
      if (flexibleSpendRatio >= 0.8 && monthProgressRatio < 0.8) {
        rawInsights.add({
          'id': 'budget_breaker',
          'severity': 2,
          'type': 'warning',
          'icon': Icons.warning_amber_rounded,
          'title': 'Discretionary Budget Breaker',
          'message': 'Consumed ${(flexibleSpendRatio * 100).toStringAsFixed(0)}% of flexible budget with ${((1.0 - monthProgressRatio) * 100).toStringAsFixed(0)}% of month left.',
          'action': 'Adjust budget limits',
          'onAction': () => widget.onJumpToBudgets?.call(),
        });
      }
    }

    if (expenseDiffPercent > 15) {
      rawInsights.add({
        'id': 'spend_velocity',
        'severity': 2,
        'type': 'warning',
        'icon': Icons.trending_up_rounded,
        'title': 'Spending Velocity Alert',
        'message': 'Spending is ${expenseDiffPercent.toStringAsFixed(0)}% higher than last month up to date.',
        'action': 'Review recent history',
        'onAction': () => widget.onJumpToHistory?.call(null, widget.selectedOwner, null, null),
      });
    }

    if (emergencyRunwayMonths < 3) {
      bool isCritical = emergencyRunwayMonths < 1.0;
      rawInsights.add({
        'id': 'emergency_runway',
        'severity': isCritical ? 3 : 2,
        'type': isCritical ? 'critical' : 'warning',
        'icon': Icons.security_rounded,
        'title': isCritical ? 'Critical Reserve Deficit' : 'Low Emergency Runway',
        'message': totalLiquidChecking <= 0 
            ? 'Liquid balances are zero or negative, posing an immediate cashflow risk.'
            : 'Reserves cover only ${emergencyRunwayMonths.toStringAsFixed(1)} months of living expenses.',
        'action': 'Add to emergency fund',
        'onAction': () => widget.onJumpToBudgets?.call(),
      });
    }

    if (topCulpritAmount > 0) {
      rawInsights.add({
        'id': 'top_culprit_$topCulpritLabel',
        'severity': 1,
        'type': 'neutral',
        'icon': Icons.pie_chart_rounded,
        'title': 'Top Driver: $topCulpritLabel',
        'message': '$topCulpritLabel accounts for ${_formatCurrency(topCulpritAmount)} of expenses.',
        'action': 'Filter history by label',
        'onAction': () => widget.onJumpToHistory?.call(topCulpritLabelId, widget.selectedOwner, null, null),
      });
    }

    if (rawInsights.isEmpty) {
      rawInsights.add({
        'id': 'stable_trajectory',
        'severity': 0,
        'type': 'neutral',
        'icon': Icons.lightbulb_outline_rounded,
        'title': 'Stable Cashflow Trajectory',
        'message': 'Financial indicators are stable with no unusual spikes.',
        'action': 'View transaction history',
        'onAction': () => widget.onJumpToHistory?.call(null, widget.selectedOwner, null, null),
      });
    }

    rawInsights.removeWhere((ins) => _dismissedInsights.contains(ins['id']));
    rawInsights.sort((a, b) => (b['severity'] as int).compareTo(a['severity'] as int));
    final insightsList = rawInsights.take(3).toList();

    double savingsScorePart = (trailingSavingsRate >= 20 ? 30.0 : (trailingSavingsRate > 0 ? (trailingSavingsRate / 20) * 30.0 : 0.0));
    double runwayScorePart = (emergencyRunwayMonths >= 6 ? 30.0 : (emergencyRunwayMonths / 6) * 30.0);
    
    double budgetAdherencePart = 20.0;
    if (wantsExpense > flexibleBudgetCeiling && flexibleBudgetCeiling > 0) {
      budgetAdherencePart = (20.0 * (flexibleBudgetCeiling / wantsExpense)).clamp(0.0, 20.0);
    }

    double cashflowTrendPart = netCashflowVelocityDelta >= 0 ? 10.0 : 5.0;
    double debtLoadPart = 10.0;

    int healthScore = (savingsScorePart + runwayScorePart + budgetAdherencePart + cashflowTrendPart + debtLoadPart).round().clamp(10, 100);

    if (emergencyRunwayMonths < 0.5) {
      if (healthScore > 40) healthScore = 40;
    } else if (emergencyRunwayMonths < 1.0) {
      if (healthScore > 60) healthScore = 60;
    }

    String healthStatus = 'Stable';
    Color healthColor = const Color(0xFF38BDF8);
    if (healthScore >= 80) {
      healthStatus = 'Excellent';
      healthColor = const Color(0xFF34D399);
    } else if (healthScore >= 65) {
      healthStatus = 'Good / Stable';
      healthColor = const Color(0xFF60A5FA);
    } else if (healthScore >= 45) {
      healthStatus = 'Needs Attention';
      healthColor = const Color(0xFFFBBF24);
    } else {
      healthStatus = 'At Risk';
      healthColor = const Color(0xFFF87171);
    }

    String biggestDrag = emergencyRunwayMonths < 3 ? 'Low emergency runway (-15 pts)' : 'Discretionary spend velocity';
    String fastestWin = 'Add ${_formatCurrency(150)} to emergency fund (+8 pts)';

    return {
      'healthScore': healthScore,
      'healthStatus': healthStatus,
      'healthColor': healthColor,
      'emergencyRunway': emergencyRunwayMonths,
      'targetBufferAllowance': targetBufferAllowance,
      'moneyRunwayDays': moneyRunwayDays,
      'netCashflowVelocityDelta': netCashflowVelocityDelta,
      'needsExpense': needsExpense,
      'wantsExpense': wantsExpense,
      'savingsContribution': savingsContribution,
      'currentMonthIncome': currentMonthIncome > 0 ? currentMonthIncome : 1.0,
      'fixedOverhead': fixedOverhead,
      'variableSpending': variableSpending,
      'hasFixedCategoriesConfigured': hasFixedCategoriesConfigured,
      'insights': insightsList,
      'biggestDrag': biggestDrag,
      'fastestWin': fastestWin,
      'spentToday': spentToday,
      'totalLiquidChecking': totalLiquidChecking,
      'totalCommittedThisMonth': totalCommittedThisMonth,
      'totalBudgetsCommitted': totalBudgetsCommitted,
      'totalLiabilitiesCommitted': totalLiabilitiesCommitted,
      'totalSavingsCommitted': totalSavingsCommitted,
      'freeToSpend': freeToSpend,
    };
  }

  void _dismissInsight(String id) {
    setState(() {
      _dismissedInsights.add(id);
      _computeDataIfNeeded(force: true);
    });
  }

  void _showInfoDialog(BuildContext context, String title, String explanation) {
    final theme = _AppThemeColors(_isZaznamityMode);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.dialogBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: theme.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            explanation,
            style: TextStyle(
              fontSize: 13,
              color: theme.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showHealthBreakdownModal(BuildContext context, Map<String, dynamic> analysis) {
    final theme = _AppThemeColors(_isZaznamityMode);
    final int totalScore = analysis['healthScore'];
    final String biggestDrag = analysis['biggestDrag'];
    final String fastestWin = analysis['fastestWin'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.dialogBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: theme.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Financial Health Breakdown',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weighted Scoring Formula:', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Text('• Savings Rate (30 pts max): Evaluated via trailing 3-month average.', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            Text('• Emergency Runway (30 pts max): Based on current liquid reserves.', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            Text('• Budget Adherence (20 pts max): Controlled discretionary burn.', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            Text('• Cashflow Trend (10 pts): Net cashflow velocity vs prior month.', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            Text('• Debt Load (10 pts): Base baseline support.', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
            const Divider(height: 20),
            Text('• Biggest Drag: $biggestDrag', style: TextStyle(color: const Color(0xFFF87171), fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('• Fastest Win: ', style: TextStyle(color: const Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12)),
                MaskedAmount(
                  formattedAmount: _formatCurrency(150),
                  style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const Text(' to emergency fund (+8 pts)', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Final Computed Score:', 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 14, 
                    color: theme.textPrimary,
                  ),
                ),
                Text('$totalScore / 100', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: analysis['healthColor'])),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _computeDataIfNeeded();
    final analysis = _cachedAnalysis!;
    final theme = _AppThemeColors(_isZaznamityMode);

    final int score = analysis['healthScore'];
    final String status = analysis['healthStatus'];
    final Color scoreColor = analysis['healthColor'];
    final double runway = analysis['emergencyRunway'];
    final double targetBufferAllowance = analysis['targetBufferAllowance'];
    final double moneyRunwayDays = analysis['moneyRunwayDays'];
    final double totalLiquidChecking = analysis['totalLiquidChecking'];
    final double spentToday = analysis['spentToday'];
    
    final double totalCommitted = analysis['totalCommittedThisMonth'];
    final double budgetsCommitted = analysis['totalBudgetsCommitted'];
    final double liabilitiesCommitted = analysis['totalLiabilitiesCommitted'];
    final double savingsCommitted = analysis['totalSavingsCommitted'];
    final double freeToSpend = analysis['freeToSpend'];
    final double incomeBase = analysis['currentMonthIncome'];

    final double needs = analysis['needsExpense'];
    final double wants = analysis['wantsExpense'];
    final double savings = analysis['savingsContribution'];

    final double fixed = analysis['fixedOverhead'];
    final double variable = analysis['variableSpending'];
    final bool hasFixedCategoriesConfigured = analysis['hasFixedCategoriesConfigured'];

    final List insightsList = analysis['insights'];

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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'HEALTH & INSIGHTS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.info_outline, size: 16, color: theme.textSecondary),
                      onPressed: () => _showInfoDialog(
                        context,
                        'Health & Insights',
                        '"At a Glance" - Auto-generated actionable insights based on spending patterns, recurring payments, and runway health.\n\n'
                        '• Health Score: Weighted scoring based on savings rate, emergency runway, budget adherence, cashflow trend, and debt load.\n'
                        '• Committed This Month: Automatically aggregates your budgets ceiling, active liability installments, and savings goal contributions, shown against your income as "Free to Spend".\n'
                        '• Runway Health: Calculated based on liquid balances and average monthly burn rate, indicating how many months of expenses can be covered.\n'
                        '• Target Buffer Allowance: Recommended daily spending limit to maintain runway health.\n'
                        '• Money Runway Days: Estimated number of days before liquid balances are depleted based on current spending velocity.\n'
                        '• Spent Today / Allowed: Total expenses recorded for the current day over the allowed limit.\n'
                        '• Needs / Wants / Savings: Categorized expenses for the current month, distinguishing between essential needs, discretionary wants, and savings contributions.\n'
                        '• Fixed / Variable: Breakdown of expenses into fixed overheads and variable spending, providing insight into controllable costs.\n'
                        '• Suggestions & Actions: Curated list of top actionable insights, highlighting spending anomalies, budget adherence issues, and runway health alerts.',
                      ),
                      tooltip: 'At a Glance',
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 36,
                width: 36,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: theme.cardBackground,
                    foregroundColor: theme.textSecondary,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _toggleCollapse,
                  icon: Icon(_isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded, size: 18),
                  tooltip: _isCollapsed ? 'Expand' : 'Collapse',
                ),
              ),
            ],
          ),
          if (!_isCollapsed) ...[
            const SizedBox(height: 14),

            // 1. Health Status Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.containerBorder),
              ),
              child: InkWell(
                onTap: () => _showHealthBreakdownModal(context, analysis),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scoreColor.withValues(alpha: 0.15),
                        border: Border.all(color: scoreColor, width: 2.5),
                      ),
                      child: Center(
                        child: Text(
                          '$score',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: scoreColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'HEALTH STATUS: ',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.textSecondary),
                                  ),
                                  Text(
                                    status.toUpperCase(),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: scoreColor),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(Icons.info_outline_rounded, size: 16, color: theme.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to view score breakdown details.',
                            style: TextStyle(fontSize: 11, color: theme.textSecondary, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // --- COMMITTED THIS MONTH CARD ---
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: theme.accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'COMMITTED THIS MONTH',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: theme.accent, letterSpacing: 0.6),
                          ),
                        ],
                      ),
                      MaskedAmount(
                        formattedAmount: _formatCurrency(totalCommitted),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: theme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('• Budgets: ', style: TextStyle(fontSize: 10, color: theme.textSecondary)),
                              MaskedAmount(formattedAmount: _formatCurrency(budgetsCommitted), style: TextStyle(fontSize: 10, color: theme.textSecondary)),
                            ],
                          ),
                          Row(
                            children: [
                              Text('• Liabilities: ', style: TextStyle(fontSize: 10, color: theme.textSecondary)),
                              MaskedAmount(formattedAmount: _formatCurrency(liabilitiesCommitted), style: TextStyle(fontSize: 10, color: theme.textSecondary)),
                            ],
                          ),
                          Row(
                            children: [
                              Text('• Goals: ', style: TextStyle(fontSize: 10, color: theme.textSecondary)),
                              MaskedAmount(formattedAmount: _formatCurrency(savingsCommitted), style: TextStyle(fontSize: 10, color: theme.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Free to Spend', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.textSecondary)),
                          const SizedBox(height: 2),
                          MaskedAmount(
                            formattedAmount: _formatCurrency(freeToSpend),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: freeToSpend >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.containerBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.savings_rounded, color: _isZaznamityMode ? const Color(0xFF34D399) : Colors.green, size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TARGET-BUFFER ALLOWANCE',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: theme.textSecondary, letterSpacing: 0.6),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  MaskedAmount(
                                    formattedAmount: _formatCurrency(targetBufferAllowance),
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: theme.textPrimary),
                                  ),
                                  Text(
                                    ' / day',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: theme.textPrimary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      Tooltip(
                        message: 'Based on total liquid reserves ÷ average daily burn rate.',
                        child: Text(
                          'Runway: ${moneyRunwayDays.toStringAsFixed(0)} days left',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: moneyRunwayDays > 15 ? const Color(0xFF34D399) : Colors.orangeAccent),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Spent Today / Allowed:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textSecondary),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MaskedAmount(
                            formattedAmount: _formatCurrency(spentToday),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: spentToday <= targetBufferAllowance ? const Color(0xFF34D399) : const Color(0xFFF87171),
                            ),
                          ),
                          Text(
                            ' / ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: spentToday <= targetBufferAllowance ? const Color(0xFF34D399) : const Color(0xFFF87171),
                            ),
                          ),
                          MaskedAmount(
                            formattedAmount: _formatCurrency(targetBufferAllowance),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: spentToday <= targetBufferAllowance ? const Color(0xFF34D399) : const Color(0xFFF87171),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Emergency Runway box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.containerBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (runway >= 3 ? const Color(0xFF34D399) : const Color(0xFFF87171)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          size: 20,
                          color: runway >= 3 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EMERGENCY RUNWAY',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: theme.textSecondary, letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${runway.toStringAsFixed(1)} mos (${moneyRunwayDays.toStringAsFixed(0)} days)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: runway >= 3 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.info_outline, size: 16, color: theme.textSecondary),
                    onPressed: () => _showInfoDialog(
                      context,
                      'Emergency Fund Runway',
                      'Calculates how many months of baseline living expenses your selected liquid reserves (${_selectedRunwayPools.join(', ')}) can cover based on your monthly burn rate.\n\n'
                      'Total Reserves: ${_formatCurrency(totalLiquidChecking)}.\n'
                      'Days Left = Total Reserves ÷ Average Daily Burn Rate.',
                    ),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Configure Pools Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.containerBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, size: 16, color: theme.accent),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Included Pools in Runway',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textPrimary),
                          ),
                          Text(
                            _selectedRunwayPools.isEmpty ? 'None selected' : _selectedRunwayPools.join(', ').toUpperCase(),
                            style: TextStyle(fontSize: 9, color: theme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _showPoolSelectorDialog(context),
                    child: const Text('Configure Pools', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '50 / 30 / 20 BUDGET BREAKDOWN',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: theme.accent, letterSpacing: 0.8),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.containerBorder),
              ),
              child: Column(
                children: [
                  _buildBudgetBarRow('Needs (≤50%)', needs, incomeBase, 0.5, true),
                  const SizedBox(height: 10),
                  _buildBudgetBarRow('Wants (≤30%)', wants, incomeBase, 0.3, true),
                  const SizedBox(height: 10),
                  _buildBudgetBarRow('Savings (≥20%)', savings, incomeBase, 0.2, false),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FIXED VS. VARIABLE BURN RATE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: theme.accent, letterSpacing: 0.8),
                ),
              ],
            ),
            const SizedBox(height: 8),
            hasFixedCategoriesConfigured
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.containerBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fixed Overhead', style: TextStyle(fontSize: 10, color: theme.textSecondary)),
                            const SizedBox(height: 2),
                            MaskedAmount(
                              formattedAmount: _formatCurrency(fixed),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textPrimary),
                            ),
                          ],
                        ),
                        Container(height: 24, width: 1, color: theme.containerBorder),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Flexible Discretionary', style: TextStyle(fontSize: 10, color: theme.textSecondary)),
                            const SizedBox(height: 2),
                            MaskedAmount(
                              formattedAmount: _formatCurrency(variable),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textPrimary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.containerBorder),
                    ),
                    child: Text(
                      'No fixed categories set. Mark categories as fixed to track overhead splits.',
                      style: TextStyle(fontSize: 11, color: theme.textSecondary),
                    ),
                  ),
            const SizedBox(height: 16),

            Text(
              'SUGGESTIONS & ACTIONS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: theme.accent, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),

            ...insightsList.map((item) {
              final insight = item as Map<String, dynamic>;
              final String id = insight['id'] as String;
              final IconData icon = insight['icon'] as IconData;
              final String title = insight['title'] as String;
              final String message = insight['message'] as String;
              final String action = insight['action'] as String;
              final String type = insight['type'] as String;
              final VoidCallback? onAction = insight['onAction'] as VoidCallback?;

              Color badgeColor = const Color(0xFF38BDF8);
              if (type == 'warning') badgeColor = const Color(0xFFFBBF24);
              if (type == 'critical') badgeColor = const Color(0xFFF87171);
              if (type == 'positive') badgeColor = const Color(0xFF34D399);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isZaznamityMode ? const Color(0xFF160D25) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: type == 'critical' ? const Color(0xFFF87171) : theme.containerBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 18, color: badgeColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textPrimary),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 14),
                                color: theme.textSecondary,
                                tooltip: 'Dismiss insight',
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                padding: EdgeInsets.zero,
                                onPressed: () => _dismissInsight(id),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message,
                            style: TextStyle(fontSize: 12, color: theme.textSecondary, height: 1.3),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: onAction,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: theme.accent.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt_rounded, size: 14, color: theme.accent),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      action,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetBarRow(String label, double amount, double income, double targetRatio, bool isLowerBetter) {
    double incomeBase = income > 0 ? income : 1.0;
    double ratio = (amount / incomeBase).clamp(0.0, 1.0);
    bool isWithinTarget = isLowerBetter ? (amount / incomeBase <= targetRatio) : (amount / incomeBase >= targetRatio);
    Color color = isWithinTarget ? const Color(0xFF34D399) : const Color(0xFFF87171);
    final theme = _AppThemeColors(_isZaznamityMode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textSecondary)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MaskedAmount(
                  formattedAmount: _formatCurrency(amount),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  ' (${((amount / incomeBase) * 100).toStringAsFixed(0)}% of income)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            double maxWidth = constraints.maxWidth;
            double targetLeft = (targetRatio * maxWidth).clamp(0.0, maxWidth);
            return SizedBox(
              height: 10,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 6,
                      width: maxWidth,
                      color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 6,
                      width: maxWidth * ratio,
                      color: color,
                    ),
                  ),
                  Positioned(
                    left: targetLeft - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: _isZaznamityMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}