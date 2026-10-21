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

  final bool isWide;
  final VoidCallback? onToggleWidth;
  final VoidCallback? onHide;

  const SmartInsightsCard({
    super.key,
    required this.transactions,
    required this.labels,
    required this.futureFlowByOwner,
    required this.prognosisByOwner,
    this.isWide = false,
    this.onToggleWidth,
    this.onHide,
  });

  @override
  State<SmartInsightsCard> createState() => _SmartInsightsCardState();
}

class _SmartInsightsCardState extends State<SmartInsightsCard> {
  bool _isZaznamityMode = true;
  bool _excludeTransfers = true;
  String _primaryCurrency = 'USD';
  String? _selectedOwner;
  final Map<String, bool> _multiLabelFixedCategories = {};

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final primary = prefs.getString('primaryCurrency') ?? 'USD';
    
    final fixedMap = <String, bool>{};
    for (var label in widget.labels) {
      fixedMap[label.name] = prefs.getBool('set_multilabel_fixed_${label.name}') ?? false;
    }

    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _excludeTransfers = prefs.getBool('exclude_transfers_insights') ?? true;
        _primaryCurrency = primary;
        _multiLabelFixedCategories.addAll(fixedMap);
      });
    }
  }

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      default: return '\$';
    }
  }

  String _formatCurrency(double amount) {
    final symbol = _getCurrencySymbol(_primaryCurrency);
    final format = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return format.format(amount);
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

  List<String> get _availableOwners {
    final set = <String>{};
    for (var tx in widget.transactions) {
      if (tx.owner.isNotEmpty) set.add(tx.owner);
    }
    return set.toList();
  }

  void _showInfoDialog(BuildContext context, String title, String explanation) {
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
        content: Text(
          explanation,
          style: TextStyle(
            fontSize: 13,
            color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569),
            height: 1.4,
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

  // --- COMPREHENSIVE OFFLINE FINANCIAL HEALTH ENGINE ---
  Map<String, dynamic> _computeSmartInsights() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final int daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
    final int currentDay = now.day;

    double currentMonthExpense = 0;
    double currentMonthIncome = 0;
    double prevMonthExpense = 0;
    double prevMonthIncome = 0;

    // Same-day pacing for cashflow velocity comparison
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

    for (var tx in widget.transactions) {
      if (_selectedOwner != null && _selectedOwner!.isNotEmpty && _selectedOwner != 'All Owners' && tx.owner != _selectedOwner) {
        continue;
      }

      if (tx.isConfirmed != 1) continue;
      final dt = DateTime.tryParse(tx.createdAt);

      String labelName = '';
      LabelModel? matchLbl = widget.labels.where((l) => l.id == tx.labelId).firstOrNull;
      if (matchLbl != null) labelName = matchLbl.name.toLowerCase();

      // Skip internal transfers if enabled
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

    // Net Cashflow Velocity / Savings Trajectory Delta vs Last Month (to-date)
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
        'message': 'Your current liquid reserves cover only ${emergencyRunwayMonths.toStringAsFixed(1)} months of living expenses (Target: 3-6 mos).',
        'action': 'Prioritize building your safety net by trimming non-essential outflows.'
      });
    }

    if (topCulpritAmount > 0) {
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

    int healthScore = 70;
    if (currentSavingsRate >= 30) healthScore += 15;
    else if (currentSavingsRate < 0) healthScore -= 25;
    if (emergencyRunwayMonths >= 6) healthScore += 15;
    else if (emergencyRunwayMonths < 2) healthScore -= 15;
    if (netCashflowVelocityDelta > 0) healthScore += 10;
    healthScore = healthScore.clamp(10, 100);

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
      'healthStatus': healthStatus,
      'healthColor': healthColor,
      'emergencyRunway': emergencyRunwayMonths,
      'projectedMonthEndExpense': projectedMonthEndExpense,
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
    final double velocityDelta = analysis['netCashflowVelocityDelta'];
    
    final double needs = analysis['needsExpense'];
    final double wants = analysis['wantsExpense'];
    final double savings = analysis['savingsContribution'];
    final double totalExp = analysis['totalExpense'];

    final double fixed = analysis['fixedOverhead'];
    final double variable = analysis['variableSpending'];

    final List<Map<String, dynamic>> insights = analysis['insights'];

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
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
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
                          icon: Icon(widget.isWide ? Icons.fullscreen_exit : Icons.fullscreen, size: 16),
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
                        icon: const Icon(Icons.visibility_off_outlined, size: 14),
                        tooltip: 'Hide',
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // OWNER DROPDOWN (matching IncomeExpensesByLabelsCard style)
          Container(
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
                    child: DropdownButton<String?>(
                      value: _selectedOwner,
                      dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                      isDense: true,
                      isExpanded: true,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                      hint: Text('All Owners', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Owners', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
                        ),
                        ..._availableOwners.map((owner) => DropdownMenuItem<String?>(
                              value: owner,
                              child: Text(owner, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedOwner = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // HEALTH SCORE SUMMARY BAR
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
            ),
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
                      const SizedBox(height: 4),
                      Text(
                        'Heuristic evaluation based on emergency runway, burn velocity, and allocations.',
                        style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // KEY FINANCIAL VITALS GRID
          Row(
            children: [
              Expanded(
                child: _buildVitalTile(
                  title: 'EMERGENCY RUNWAY',
                  infoTitle: 'Emergency Fund Runway',
                  infoExplanation: 'Calculates how many months of baseline living expenses your current liquid checking and cash reserves can cover.\n\nImportance: Ensures you have a 3 to 6-month safety net to survive unexpected income interruptions without going into debt.',
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
                  infoExplanation: 'Takes your spending velocity up to the current day and extrapolates your total expected outflow across the full month.\n\nImportance: Gives you early warning if you are pacing to overspend your monthly budget before month-end arrives.',
                  value: _formatCurrency(projectedEnd),
                  subtitle: 'Run-rate forecast',
                  icon: Icons.show_chart_rounded,
                  color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // NET CASHFLOW VELOCITY / SAVINGS TRAJECTORY TILE
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
                                'Compares your net cashflow (Income minus Expenses) up to the exact same day in the previous month.\n\nImportance: Tells you instantly whether you are accumulating wealth faster or slower compared to last month\'s momentum.',
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

          // 50 / 30 / 20 RULE BREAKDOWN SECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '50 / 30 / 20 BUDGET BREAKDOWN',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), letterSpacing: 0.8),
              ),
              InkWell(
                onTap: () => _showInfoDialog(
                  context,
                  '50/30/20 Rule Breakdown',
                  'Categorizes your monthly outflows into Needs (50%: Housing, Utilities, Groceries, Debt), Wants (30%: Dining, Shopping), and Savings (20%).\n\nImportance: The gold-standard budgeting framework ensuring balanced lifestyle spending and financial security.',
                ),
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

          // FIXED VS VARIABLE OVERHEAD SECTION
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FIXED VS. VARIABLE BURN RATE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), letterSpacing: 0.8),
              ),
              InkWell(
                onTap: () => _showInfoDialog(
                  context,
                  'Fixed vs. Variable Burn Rate',
                  'Separates mandatory fixed overhead from flexible discretionary spending. Configured in Settings -> Label Management -> Fixed vs. Discretionary.\n\nImportance: Shows your financial agility—high fixed overhead leaves less room to adjust if cashflow tightens.',
                ),
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

          // ALWAYS-VISIBLE SUGGESTIONS & COURSES OF ACTION
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
                              Icon(Icons.bolt_rounded, size: 12, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Action: $action',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
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
      ),
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