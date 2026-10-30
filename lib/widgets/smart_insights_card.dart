// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class SmartInsightsCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final Map<String, double> futureFlowByOwner;
  final Map<String, double> prognosisByOwner;
  final String? selectedOwner;

  const SmartInsightsCard({
    super.key,
    required this.transactions,
    required this.labels,
    required this.futureFlowByOwner,
    required this.prognosisByOwner,
    this.selectedOwner,
  });

  @override
  State<SmartInsightsCard> createState() => _SmartInsightsCardState();
}

class _SmartInsightsCardState extends State<SmartInsightsCard> {
  bool _isZaznamityMode = true;
  bool _excludeTransfers = true;
  bool _isCollapsed = false;
  String _primaryCurrency = 'USD';
  final Map<String, bool> _multiLabelFixedCategories = {};

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void didUpdateWidget(covariant SmartInsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final primary = prefs.getString('primaryCurrency') ?? 'USD';
    final collapsed = prefs.getBool('set_smartInsights_collapsed') ?? false;
    
    final fixedMap = <String, bool>{};
    for (var label in widget.labels) {
      fixedMap[label.name] = prefs.getBool('set_multilabel_fixed_${label.name}') ?? false;
    }

    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _excludeTransfers = prefs.getBool('exclude_transfers_insights') ?? true;
        _primaryCurrency = primary;
        _isCollapsed = collapsed;
        _multiLabelFixedCategories.addAll(fixedMap);
      });
    }
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_smartInsights_collapsed', _isCollapsed);
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
      case 'MXN': 
      case 'CLP': 
      case 'COP': return '\$';
      default: return '\$';
    }
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

  void _showInfoDialog(BuildContext context, String title, String explanation, {bool includeDisclaimer = false}) {
    final disclaimer = includeDisclaimer 
        ? '\n\nDisclaimer: Insights are generated dynamically based purely on your logged Zaznams and inputted historical data. This tool is for personal organization and tracking only and does not constitute certified professional financial advice.' 
        : '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            explanation + disclaimer,
            style: TextStyle(
              fontSize: 13,
              color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569),
              height: 1.4,
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showHealthBreakdownModal(BuildContext context, Map<String, dynamic> analysis) {
    final int savingsPts = analysis['savingsPts'];
    final int runwayPts = analysis['runwayPts'];
    final int velocityPts = analysis['velocityPts'];
    final int baseScore = analysis['baseScore'];
    final int totalScore = analysis['healthScore'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Financial Health Breakdown',
                style: TextStyle(
                  color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
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
            Text('Starting Baseline Score: +$baseScore pts', style: TextStyle(color: _isZaznamityMode ? Colors.white70 : Colors.black87, fontSize: 13)),
            const SizedBox(height: 8),
            Text('• Savings Rate Factor: ${savingsPts >= 0 ? "+$savingsPts" : savingsPts} pts', style: TextStyle(color: savingsPts >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171), fontSize: 13, fontWeight: FontWeight.bold)),
            Text('• Emergency Runway Factor: ${runwayPts >= 0 ? "+$runwayPts" : runwayPts} pts', style: TextStyle(color: runwayPts >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171), fontSize: 13, fontWeight: FontWeight.bold)),
            Text('• Cashflow Velocity Factor: ${velocityPts >= 0 ? "+$velocityPts" : velocityPts} pts', style: TextStyle(color: velocityPts >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171), fontSize: 13, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Final Computed Score:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('$totalScore / 100', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: analysis['healthColor'])),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
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

  Map<String, dynamic> _computeSmartInsights() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final int daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
    final int currentDay = now.day;
    final double monthProgressRatio = currentDay / daysInMonth;

    double currentMonthExpense = 0;
    double currentMonthIncome = 0;
    double prevMonthExpense = 0;
    double prevMonthIncome = 0;

    double currentMonthExpenseToDate = 0;
    double prevMonthExpenseToDate = 0;
    double prevMonthIncomeToDate = 0;

    final int prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;
    final int prevYear = currentMonth == 1 ? currentYear - 1 : currentYear;

    Map<int, double> labelExpenses = {};
    double totalLiquidChecking = 0;

    double needsExpense = 0;
    double wantsExpense = 0;
    double savingsContribution = 0;

    double fixedOverhead = 0;
    double variableSpending = 0;

    Map<String, Map<int, double>> recurringBillHistory = {};

    for (var tx in widget.transactions) {
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners' && tx.owner != widget.selectedOwner) {
        continue;
      }

      if (tx.isConfirmed != 1) continue;
      final dt = DateTime.tryParse(tx.createdAt);

      String labelName = '';
      LabelModel? matchLbl = widget.labels.where((l) => l.id == tx.labelId).firstOrNull;
      if (matchLbl != null) labelName = matchLbl.name.toLowerCase();

      if (_excludeTransfers && labelName == 'transfer') {
        continue;
      }
      
      if (dt != null && !dt.isAfter(now)) {
        double signedAmt = tx.type == 'income' ? tx.amount : -tx.amount;
        if (tx.pool == 'checking' || tx.pool == 'cash') {
          totalLiquidChecking += signedAmt;
        }
      }

      if (dt == null) continue;

      if (tx.type == 'expense' && matchLbl != null && _isFixedExpenseLabel(matchLbl)) {
        int monthKey = dt.year * 12 + dt.month;
        recurringBillHistory.putIfAbsent(matchLbl.name, () => {});
        recurringBillHistory[matchLbl.name]![monthKey] = (recurringBillHistory[matchLbl.name]![monthKey] ?? 0) + tx.amount;
      }

      if (dt.year == currentYear && dt.month == currentMonth) {
        if (tx.type == 'expense') {
          currentMonthExpense += tx.amount;
          if (dt.day <= currentDay) currentMonthExpenseToDate += tx.amount;

          labelExpenses[tx.labelId] = (labelExpenses[tx.labelId] ?? 0) + tx.amount;

          bool isFixed = matchLbl != null ? _isFixedExpenseLabel(matchLbl) : false;
          if (isFixed) {
            fixedOverhead += tx.amount;
            needsExpense += tx.amount;
          } else {
            variableSpending += tx.amount;
            if (labelName.contains('saving') || labelName.contains('goal') || tx.pool == 'savings') {
              savingsContribution += tx.amount;
            } else {
              wantsExpense += tx.amount;
            }
          }
        }
        if (tx.type == 'income') currentMonthIncome += tx.amount;
      } else if (dt.year == prevYear && dt.month == prevMonth) {
        if (tx.type == 'expense') {
          prevMonthExpense += tx.amount;
          if (dt.day <= currentDay) prevMonthExpenseToDate += tx.amount;
        }
        if (tx.type == 'income') {
          prevMonthIncome += tx.amount;
          if (dt.day <= currentDay) prevMonthIncomeToDate += tx.amount;
        }
      }
    }

    if (needsExpense == 0 && wantsExpense == 0 && currentMonthExpense > 0) {
      needsExpense = currentMonthExpense * 0.55;
      wantsExpense = currentMonthExpense * 0.45;
      fixedOverhead = currentMonthExpense * 0.5;
      variableSpending = currentMonthExpense * 0.5;
    }

    double expenseDiffPercent = 0;
    if (prevMonthExpense > 0) {
      expenseDiffPercent = ((currentMonthExpense - prevMonthExpense) / prevMonthExpense) * 100;
    }

    double currentSavingsRate = currentMonthIncome > 0
        ? ((currentMonthIncome - currentMonthExpense) / currentMonthIncome) * 100
        : (currentMonthExpense > 0 ? -100.0 : 0.0);

    double monthlyBurnBaseline = prevMonthExpense > 0 ? prevMonthExpense : (currentMonthExpense > 0 ? currentMonthExpense : 1.0);
    double emergencyRunwayMonths = totalLiquidChecking > 0 ? (totalLiquidChecking / monthlyBurnBaseline) : 0.0;

    double dailySpendRate = currentDay > 0 ? (currentMonthExpense / currentDay) : 0;
    double projectedMonthEndExpense = dailySpendRate * daysInMonth;

    double availableChecking = totalLiquidChecking;
    double protectedSavingsBuffer = availableChecking * 0.20;
    double safeSpendablePool = (availableChecking - protectedSavingsBuffer).clamp(0.0, double.infinity);
    double targetBufferAllowance = daysInMonth > 0 ? (safeSpendablePool / daysInMonth) : 0.0;

    double moneyRunwayDays = dailySpendRate > 0 ? (availableChecking / dailySpendRate) : 999.0;

    double currentNetToDate = currentMonthIncome - currentMonthExpenseToDate;
    double prevNetToDate = prevMonthIncomeToDate - prevMonthExpenseToDate;
    double netCashflowVelocityDelta = currentNetToDate - prevNetToDate;

    String topCulpritLabel = 'None';
    double topCulpritAmount = 0;
    if (labelExpenses.isNotEmpty) {
      var sortedLabels = labelExpenses.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      int topLabelId = sortedLabels.first.key;
      topCulpritAmount = sortedLabels.first.value;
      
      final matchingLabel = widget.labels.where((l) => l.id == topLabelId).firstOrNull;
      if (matchingLabel != null) topCulpritLabel = matchingLabel.name;
    }

    List<Map<String, dynamic>> insights = [];

    int currentMonthKey = currentYear * 12 + currentMonth;
    int prevMonthKey = prevYear * 12 + prevMonth;
    recurringBillHistory.forEach((billName, history) {
      double? currVal = history[currentMonthKey];
      double? prevVal = history[prevMonthKey];
      if (currVal != null && prevVal != null && prevVal > 0) {
        double hikePct = ((currVal - prevVal) / prevVal) * 100;
        if (hikePct >= 5) {
          insights.add({
            'type': 'warning',
            'icon': Icons.trending_up_rounded,
            'title': 'Price Hike Detected: $billName',
            'message': '$billName increased by ${hikePct.toStringAsFixed(0)}% compared to last month (${_formatCurrency(prevVal)} → ${_formatCurrency(currVal)}).',
            'action': 'Review subscription or utility billing terms.'
          });
        }
      }
    });

    double flexibleBudgetCeiling = wantsExpense > 0 ? wantsExpense : (currentMonthExpense * 0.4);
    if (flexibleBudgetCeiling > 0 && monthProgressRatio > 0) {
      double flexibleSpendRatio = (wantsExpense / flexibleBudgetCeiling);
      if (flexibleSpendRatio >= 0.8 && monthProgressRatio < 0.8) {
        insights.add({
          'type': 'warning',
          'icon': Icons.warning_amber_rounded,
          'title': 'Discretionary Budget Breaker',
          'message': 'You have consumed over 80% of your flexible spending ceiling (${(flexibleSpendRatio * 100).toStringAsFixed(0)}%) with ${(1.0 - monthProgressRatio) * 100}% of the month still remaining.',
          'action': 'Exercise strict discretionary caution for the rest of the month.'
        });
      }
    }

    if (expenseDiffPercent > 15) {
      insights.add({
        'type': 'warning',
        'icon': Icons.trending_up_rounded,
        'title': 'Spending Velocity Alert',
        'message': 'Your spending is ${expenseDiffPercent.toStringAsFixed(0)}% higher than last month up to this date.',
        'action': 'Review recent discretionary Zaznams and check budget thresholds.'
      });
    } else if (expenseDiffPercent < -10) {
      insights.add({
        'type': 'positive',
        'icon': Icons.thumb_up_alt_rounded,
        'title': 'Controlled Spending',
        'message': 'Great job! You spent ${expenseDiffPercent.abs().toStringAsFixed(0)}% less than last month so far.',
        'action': 'Consider channeling excess savings into investment or savings goals.'
      });
    }

    if (emergencyRunwayMonths < 3 && totalLiquidChecking > 0) {
      insights.add({
        'type': 'warning',
        'icon': Icons.security_rounded,
        'title': 'Low Emergency Runway',
        'message': 'Your current liquid checking/cash reserves cover only ${emergencyRunwayMonths.toStringAsFixed(1)} months of living expenses (Target: 3-6 mos).',
        'action': 'Prioritize building your safety net by trimming non-essential outflows.'
      });
    }

    if (topCulpritAmount > 0 && insights.length < 3) {
      double culpritShare = currentMonthExpense > 0 ? (topCulpritAmount / currentMonthExpense) * 100 : 0;
      insights.add({
        'type': 'neutral',
        'icon': Icons.pie_chart_rounded,
        'title': 'Top Spending Driver: $topCulpritLabel',
        'message': '$topCulpritLabel accounts for ${_formatCurrency(topCulpritAmount)} (${culpritShare.toStringAsFixed(0)}% of expenses).',
        'action': 'Set a strict budget cap for this category.'
      });
    }

    if (insights.isEmpty) {
      insights.add({
        'type': 'neutral',
        'icon': Icons.lightbulb_outline_rounded,
        'title': 'Stable Cashflow Trajectory',
        'message': 'Your financial indicators are stable with no unusual spending spikes.',
        'action': 'Keep logging Zaznams regularly.'
      });
    }

    int baseScore = 70;
    int savingsPts = currentSavingsRate >= 30 ? 15 : (currentSavingsRate < 0 ? -25 : 0);
    int runwayPts = emergencyRunwayMonths >= 6 ? 15 : (emergencyRunwayMonths < 2 ? -15 : 0);
    int velocityPts = netCashflowVelocityDelta > 0 ? 10 : 0;

    int healthScore = (baseScore + savingsPts + runwayPts + velocityPts).clamp(10, 100);

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

    return {
      'healthScore': healthScore,
      'baseScore': baseScore,
      'savingsPts': savingsPts,
      'runwayPts': runwayPts,
      'velocityPts': velocityPts,
      'healthStatus': healthStatus,
      'healthColor': healthColor,
      'emergencyRunway': emergencyRunwayMonths,
      'projectedMonthEndExpense': projectedMonthEndExpense,
      'targetBufferAllowance': targetBufferAllowance,
      'moneyRunwayDays': moneyRunwayDays,
      'netCashflowVelocityDelta': netCashflowVelocityDelta,
      'needsExpense': needsExpense,
      'wantsExpense': wantsExpense,
      'savingsContribution': savingsContribution,
      'fixedOverhead': fixedOverhead,
      'variableSpending': variableSpending,
      'totalExpense': currentMonthExpense > 0 ? currentMonthExpense : 1.0,
      'insights': insights,
    };
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _computeSmartInsights();
    final int score = analysis['healthScore'];
    final String status = analysis['healthStatus'];
    final Color scoreColor = analysis['healthColor'];
    final double runway = analysis['emergencyRunway'];
    final double projectedEnd = analysis['projectedMonthEndExpense'];
    final double targetBufferAllowance = analysis['targetBufferAllowance'];
    final double moneyRunwayDays = analysis['moneyRunwayDays'];
    final double velocityDelta = analysis['netCashflowVelocityDelta'];
    
    final double needs = analysis['needsExpense'];
    final double wants = analysis['wantsExpense'];
    final double savings = analysis['savingsContribution'];
    final double totalExp = analysis['totalExpense'];

    final double fixed = analysis['fixedOverhead'];
    final double variable = analysis['variableSpending'];

    final List<Map<String, dynamic>> insights = analysis['insights'];
    final displayOwner = (widget.selectedOwner == null || widget.selectedOwner!.isEmpty) ? 'All Owners' : widget.selectedOwner!;

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
                          icon: Icon(Icons.info_outline, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
                          onPressed: () => _showInfoDialog(
                            context,
                            'Metrics Calculation & Insights Overview',
                            '• Real-time Recalculation: Metrics refresh instantaneously whenever a transaction is added, edited, or confirmed.\n\n'
                            '• Monthly Baselines: Monthly comparisons and spend-rate velocity metrics are re-anchored on the 1st day of each calendar month.',
                            includeDisclaimer: true,
                          ),
                          tooltip: 'Recalculation Guide',
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
                            Text(
                              displayOwner,
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
                          icon: Icon(_isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded, size: 16),
                          tooltip: _isCollapsed ? 'Expand' : 'Collapse',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!_isCollapsed) ...[
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
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
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                      ),
                                      Text(
                                        status.toUpperCase(),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: scoreColor),
                                      ),
                                    ],
                                  ),
                                  InkWell(
                                    onTap: () => _showInfoDialog(
                                      context,
                                      'Financial Health Score',
                                      'Tap anywhere on this score badge to open the score breakdown modal and see exactly which metrics added or subtracted points from your total score.',
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: Icon(Icons.info_outline_rounded, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to view score breakdown details.',
                                style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569), height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // TARGET-BUFFER ALLOWANCE TILE
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.savings_rounded, color: _isZaznamityMode ? const Color(0xFF34D399) : Colors.green, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'TARGET-BUFFER ALLOWANCE',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), letterSpacing: 0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => _showInfoDialog(
                                          context,
                                          'Target-Buffer Allowance',
                                          'What this means: If you spend exactly this daily allowance every single day, your liquid checking balance would be fully depleted by income day.\n\n50/30/20 Rule Protection: To prevent your balance from hitting zero, this calculation reserves 20% as a safety/savings buffer. Only the remaining safe portion is divided across the month.\n\nMoney Runway: Your current balance will last approximately ${moneyRunwayDays.toStringAsFixed(0)} days at your current daily spend rate.',
                                        ),
                                        child: Icon(Icons.info_outline, size: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${_formatCurrency(targetBufferAllowance)} / day',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                      ),
                                      Text(
                                        'Runway: ${moneyRunwayDays.toStringAsFixed(0)} days left',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: moneyRunwayDays > 15 ? const Color(0xFF34D399) : Colors.orangeAccent),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _buildVitalTile(
                        title: 'EMERGENCY RUNWAY',
                        infoTitle: 'Emergency Fund Runway',
                        infoExplanation: 'Calculates how many months of baseline living expenses your liquid checking and cash reserves can cover as an immediate survival buffer.',
                        value: '${runway.toStringAsFixed(1)} mos',
                        subtitle: 'Survival buffer',
                        icon: Icons.shield_outlined,
                        color: runway >= 3 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildVitalTile(
                        title: 'PROJECTED END-MONTH',
                        infoTitle: 'Month-End Run-Rate Projection',
                        infoExplanation: 'Extrapolates month-end outflow based on daily burn velocity.',
                        value: _formatCurrency(projectedEnd),
                        subtitle: 'Run-rate forecast',
                        icon: Icons.show_chart_rounded,
                        color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'NET SAVINGS TRAJECTORY (VS LAST MONTH)',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), letterSpacing: 0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => _showInfoDialog(
                                      context,
                                      'Net Cashflow Velocity',
                                      'Compares net cashflow up to the exact same day in the previous month.',
                                    ),
                                    child: Icon(Icons.info_outline, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${velocityDelta >= 0 ? '+' : ''}${_formatCurrency(velocityDelta)} to-date',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: velocityDelta >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Icon(
                        velocityDelta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: velocityDelta >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        size: 24,
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
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), letterSpacing: 0.8),
                    ),
                    InkWell(
                      onTap: () => _showInfoDialog(context, '50/30/20 Rule', 'Categorizes monthly outflows into Needs, Wants, and Savings.'),
                      child: Icon(Icons.info_outline, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Column(
                    children: [
                      _buildBudgetBarRow('Needs (50%)', needs, totalExp, const Color(0xFF60A5FA)),
                      const SizedBox(height: 8),
                      _buildBudgetBarRow('Wants (30%)', wants, totalExp, const Color(0xFFFBBF24)),
                      const SizedBox(height: 8),
                      _buildBudgetBarRow('Savings (20%)', savings, totalExp + savings, const Color(0xFF34D399)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FIXED VS. VARIABLE BURN RATE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), letterSpacing: 0.8),
                    ),
                    InkWell(
                      onTap: () => _showInfoDialog(context, 'Fixed vs Variable', 'Separates mandatory overhead from discretionary spending.'),
                      child: Icon(Icons.info_outline, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fixed Overhead', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(_formatCurrency(fixed), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                        ],
                      ),
                      Container(height: 24, width: 1, color: _isZaznamityMode ? Colors.white24 : Colors.black26),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Flexible Discretionary', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(_formatCurrency(variable), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'SUGGESTIONS & COURSES OF ACTION',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),

                ...insights.map((insight) {
                  final IconData icon = insight['icon'];
                  final String title = insight['title'];
                  final String message = insight['message'];
                  final String action = insight['action'];
                  final String type = insight['type'];

                  Color badgeColor = const Color(0xFF38BDF8);
                  if (type == 'warning') badgeColor = const Color(0xFFFBBF24);
                  if (type == 'positive') badgeColor = const Color(0xFF34D399);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isZaznamityMode ? const Color(0xFF160D25) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFE2E8F0)),
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
                              Text(
                                title,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                message,
                                style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), height: 1.3),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bolt_rounded, size: 12, color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Action: $action',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ],
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
      },
    );
  }

  Widget _buildBudgetBarRow(String label, double amount, double total, Color color) {
    double ratio = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF334155))),
            Text('${_formatCurrency(amount)} (${(ratio * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildVitalTile({
    required String title,
    required String infoTitle,
    required String infoExplanation,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), letterSpacing: 0.6),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _showInfoDialog(context, infoTitle, infoExplanation),
                child: Icon(Icons.info_outline, size: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white60 : const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}