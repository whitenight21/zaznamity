// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/savings_goal_model.dart';
import '../models/label.dart';
import '../services/snackbar_notification.dart';

class SavingsGoalsCard extends StatefulWidget {
  final List<SavingsGoalModel> goals;
  final List<LabelModel> labels;
  final List<String> owners;
  final List<String> pools;
  final String? selectedOwner;
  final Function(SavingsGoalModel) onSaveGoal;
  final Function(int goalId, double amountToAdd, String owner, String fromPool, String goalName, String currency) onAddFundsToGoal;
  final Function(int goalId, double amountToRemove, String owner, String toPool, String goalName, String currency) onRemoveFundsFromGoal;
  final Function(int goalId) onCompleteGoal;

  const SavingsGoalsCard({
    super.key,
    required this.goals,
    required this.labels,
    required this.owners,
    required this.pools,
    this.selectedOwner,
    required this.onSaveGoal,
    required this.onAddFundsToGoal,
    required this.onRemoveFundsFromGoal,
    required this.onCompleteGoal,
  });

  @override
  State<SavingsGoalsCard> createState() => _SavingsGoalsCardState();
}

class _SavingsGoalsCardState extends State<SavingsGoalsCard> {
  List<String> _userCurrencies = ['USD'];
  bool _isZaznamityMode = true;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final primary = prefs.getString('primaryCurrency') ?? 'USD';
    final sec1 = prefs.getString('secondaryCurrency1');
    final sec2 = prefs.getString('secondaryCurrency2');
    final sec3 = prefs.getString('secondaryCurrency3');

    final List<String> list = [primary];
    if (sec1 != null && sec1.isNotEmpty) list.add(sec1);
    if (sec2 != null && sec2.isNotEmpty) list.add(sec2);
    if (sec3 != null && sec3.isNotEmpty) list.add(sec3);

    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _userCurrencies = list;
        _isCollapsed = prefs.getBool('set_savingsGoals_collapsed') ?? false;
      });
    }
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_savingsGoals_collapsed', _isCollapsed);
  }

  double _parseNum(String text) {
    if (text.isEmpty) return 0.0;
    return double.tryParse(text.trim().replaceAll(',', '.')) ?? 0.0;
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

  /// Formats currency with thousands comma and positions symbol trailing/leading based on currency type
  String _formatCurrency(double amount, [String? currencyCode]) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final formattedNumber = formatter.format(amount);
    final code = currencyCode ?? _userCurrencies.first;
    final symbol = _getCurrencySymbol(code).trim();

    // List of common trailing currency symbols/codes
    const trailingSymbols = ['€', 'Ft', 'Kč', 'zł', 'CHF'];
    bool isTrailing = trailingSymbols.any((s) => symbol.toLowerCase() == s.toLowerCase());

    if (isTrailing) {
      return '$formattedNumber $symbol';
    } else {
      return '$symbol$formattedNumber';
    }
  }

  String _getCurrencyFlag(String code) {
    switch (code.toUpperCase()) {
      case 'EUR': return '🇪🇺';
      case 'USD': return '🇺🇸';
      case 'CAD': return '🇨🇦';
      case 'GBP': return '🇬🇧';
      case 'CZK': return '🇨🇿';
      case 'HUF': return '🇭🇺';
      case 'PLN': return '🇵🇱';
      case 'CHF': return '🇨🇭';
      case 'RUB': return '🇷🇺';
      case 'JPY': return '🇯🇵';
      case 'CNY': return '🇨🇳';
      case 'HKD': return '🇭🇰';
      case 'SGD': return '🇸🇬';
      case 'AUD': return '🇦🇺';
      case 'BRL': return '🇧🇷';
      case 'MXN': return '🇲🇽';
      case 'CLP': return '🇨🇱';
      case 'COP': return '🇨🇴';
      default: return '🇺🇸';
    }
  }

  @override
  void didUpdateWidget(covariant SavingsGoalsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.goals != oldWidget.goals) {
      setState(() {}); 
    }
  }

  Map<String, dynamic> _evaluateGoalPaceAndForecast(SavingsGoalModel goal) {
    if (goal.currentAmount >= goal.targetAmount) {
      return {'text': 'Goal completed!', 'status': 'completed', 'neededPerMonth': 0.0};
    }

    double remaining = goal.targetAmount - goal.currentAmount;
    if (remaining <= 0) {
      return {'text': 'On track', 'status': 'ontrack', 'neededPerMonth': 0.0};
    }

    DateTime now = DateTime.now();
    DateTime? targetDate = goal.targetDate != null ? DateTime.tryParse(goal.targetDate!) : null;

    double neededPerMonth = goal.monthlyContribution;
    if (targetDate != null) {
      int totalMonths = (targetDate.year - now.year) * 12 + targetDate.month - now.month;
      if (totalMonths <= 0) totalMonths = 1;
      neededPerMonth = remaining / totalMonths;
    }

    if (goal.monthlyContribution <= 0) {
      return {'text': 'No installment set', 'status': 'behind', 'neededPerMonth': neededPerMonth};
    }

    int monthsNeeded = (remaining / goal.monthlyContribution).ceil();
    DateTime projectedDate = DateTime(now.year, now.month + monthsNeeded, now.day);
    String formattedDate = DateFormat('MMMM yyyy').format(projectedDate);

    if (targetDate != null) {
      if (projectedDate.isAfter(targetDate)) {
        return {'text': 'Late (est. $formattedDate)', 'status': 'late', 'neededPerMonth': neededPerMonth};
      } else {
        return {'text': 'On track by $formattedDate', 'status': 'ontrack', 'neededPerMonth': neededPerMonth};
      }
    }

    return {'text': 'On track by $formattedDate', 'status': 'ontrack', 'neededPerMonth': neededPerMonth};
  }

  void _checkMilestoneCelebration(double previousAmount, double newAmount, SavingsGoalModel goal) {
    double target = goal.targetAmount;
    if (target <= 0) return;

    double prevPct = (previousAmount / target) * 100;
    double newPct = (newAmount / target) * 100;

    List<double> milestones = [25.0, 50.0, 75.0, 100.0];
    for (var m in milestones) {
      if (prevPct < m && newPct >= m) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showSnackbarNotification(
              context,
              '🎉 Milestone Reached! ${m.toStringAsFixed(0)}% of "${goal.name}" achieved!',
              isError: false,
            );
          }
        });
        break;
      }
    }
  }

  void _showCompletionDialog(SavingsGoalModel goal) {
    final bool isReady = goal.currentAmount >= goal.targetAmount;
    final primaryCurr = _userCurrencies.first;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isReady ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: isReady ? Colors.green : Colors.amber, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isReady ? 'Complete Savings Goal?' : 'Goal Not Yet Complete',
                style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          isReady 
              ? 'Marking this goal as complete will finalize it and disburse or remove the savings funds from your active pool balance.'
              : 'You have not reached your target amount yet (${_formatCurrency(goal.currentAmount, primaryCurr)} / ${_formatCurrency(goal.targetAmount, primaryCurr)}). You can still complete it if desired.',
          style: TextStyle(fontSize: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              widget.onCompleteGoal(goal.id!);
            },
            child: const Text('Confirm Complete'),
          ),
        ],
      ),
    );
  }

  void _showSavingsGoalInfoModal(BuildContext context) {
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
                  'Savings Goals',
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
              'Savings Goals help you build toward milestones, future purchases, bills or any financial targets:\n\n'
              '• Due-Date Pace & Forecasts: Track whether you are ahead or behind your monthly target installment.\n'
              '• Emergency Fund Template: Quickly spin up 3–6 months burn-rate safety buffers.\n'
              '• Scheduled Transfers: Turn monthly installments into automated recurring transfers for accurate cash flow runway.\n'
              '• Withdraw Funds: Move funds from a goal and return them to your pool balance if needed.\n'
              '• Milestone Notifications: Receive instant alerts as you cross 25%, 50%, 75%, and 100%.\n'
              '• Goal Completion: Mark a goal as complete when you reach your target and disburse the funds.\n'
              '• Edit & Update: Change the goal name, target amount, due date, or monthly installment at any time in Zaznamity Settings.\n'
              '• Smart Insights / 50/30/20 Integration: Savings goal installments feed directly into your financial health breakdown.',
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

  void _showAddFundsDialog(SavingsGoalModel goal) {
    final TextEditingController amountController = TextEditingController();
    String selectedDialogOwner = widget.owners.isNotEmpty ? widget.owners.first : 'Shared';
    String selectedDialogPool = widget.pools.isNotEmpty ? widget.pools.first : 'checking';
    String selectedCurrency = _userCurrencies.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Funds to "${goal.name}"', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95), fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: widget.owners.contains(selectedDialogOwner) ? selectedDialogOwner : widget.owners.first,
                      dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                      style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Owner',
                        labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                      ),
                      items: widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedDialogOwner = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _userCurrencies.contains(selectedCurrency) ? selectedCurrency : _userCurrencies.first,
                          isDense: true,
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                          items: _userCurrencies.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text('$c (${_getCurrencySymbol(c)})', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedCurrency = val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: amountController,
                      style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount to Add',
                        labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: widget.pools.contains(selectedDialogPool) ? selectedDialogPool : widget.pools.first,
                      dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                      style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'From Pool',
                        labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                      ),
                      items: widget.pools.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase(), style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedDialogPool = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                final val = _parseNum(amountController.text);
                if (val > 0) {
                  _checkMilestoneCelebration(goal.currentAmount, goal.currentAmount + val, goal);
                  widget.onAddFundsToGoal(goal.id!, val, selectedDialogOwner, selectedDialogPool, goal.name, selectedCurrency);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Funds', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveFundsDialog(SavingsGoalModel goal) {
    final TextEditingController amountController = TextEditingController();
    String selectedDialogOwner = widget.owners.isNotEmpty ? widget.owners.first : 'Shared';
    String selectedDialogPool = widget.pools.isNotEmpty ? widget.pools.first : 'checking';
    String selectedCurrency = _userCurrencies.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Remove Funds from "${goal.name}"', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95), fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Available to remove: ${_formatCurrency(goal.currentAmount, selectedCurrency)}', style: TextStyle(fontSize: 12, color: _isZaznamityMode ? Colors.white60 : Colors.grey)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: widget.owners.contains(selectedDialogOwner) ? selectedDialogOwner : widget.owners.first,
                      dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                      style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Owner',
                        labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                      ),
                      items: widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedDialogOwner = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _userCurrencies.contains(selectedCurrency) ? selectedCurrency : _userCurrencies.first,
                          isDense: true,
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                          items: _userCurrencies.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text('$c (${_getCurrencySymbol(c)})', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedCurrency = val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: amountController,
                      style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount to Remove',
                        labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: widget.pools.contains(selectedDialogPool) ? selectedDialogPool : widget.pools.first,
                      dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                      style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'To Pool',
                        labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                      ),
                      items: widget.pools.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase(), style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedDialogPool = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                final val = _parseNum(amountController.text);
                if (val > 0) {
                  final removeAmt = val > goal.currentAmount ? goal.currentAmount : val;
                  widget.onRemoveFundsFromGoal(goal.id!, removeAmt, selectedDialogOwner, selectedDialogPool, goal.name, selectedCurrency);
                  Navigator.pop(context);
                }
              },
              child: const Text('Remove Funds', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGoalDialog({bool isEmergencyFundTemplate = false}) {
    final TextEditingController nameController = TextEditingController(text: isEmergencyFundTemplate ? 'Emergency Fund' : '');
    final TextEditingController targetController = TextEditingController(text: isEmergencyFundTemplate ? '3000' : '');
    final TextEditingController contributionController = TextEditingController(text: isEmergencyFundTemplate ? '500' : '');
    final TextEditingController paymentDayController = TextEditingController(text: '1');
    
    String selectedCurrency = _userCurrencies.first;
    String dialogOwner = widget.owners.isNotEmpty ? widget.owners.first : 'Shared';
    String selectedPriority = 'Medium';
    bool scheduledTransfer = false;
    DateTime? selectedDueDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void updateSuggestedContribution() {
            if (selectedDueDate != null) {
              final target = _parseNum(targetController.text);
              if (target > 0) {
                final now = DateTime.now();
                int monthsDifference = (selectedDueDate!.year - now.year) * 12 + selectedDueDate!.month - now.month;
                if (monthsDifference <= 0) monthsDifference = 1;
                double suggested = target / monthsDifference;
                contributionController.text = suggested.toStringAsFixed(2);
              }
            }
          }

          return AlertDialog(
            backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEmergencyFundTemplate ? 'Emergency Fund Template (3 Mos)' : 'Create New Goal', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95), fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: widget.owners.contains(dialogOwner) ? dialogOwner : widget.owners.first,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Owner',
                            labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            filled: true,
                            fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                          ),
                          items: widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)))).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => dialogOwner = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _userCurrencies.contains(selectedCurrency) ? selectedCurrency : _userCurrencies.first,
                              isDense: true,
                              isExpanded: true,
                              dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                              items: _userCurrencies.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text('$c (${_getCurrencySymbol(c)})', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedCurrency = val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Goal Name',
                      labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                      filled: true,
                      fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: targetController,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => updateSuggestedContribution(),
                          decoration: InputDecoration(
                            labelText: 'Target Amount',
                            labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            filled: true,
                            fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: contributionController,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Monthly Installment',
                            labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            filled: true,
                            fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: paymentDayController,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Payment Day (1-31)',
                            labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            filled: true,
                            fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedPriority,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(fontSize: 12, color: _isZaznamityMode ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Priority',
                            labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            filled: true,
                            fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                          ),
                          items: ['High', 'Medium', 'Low'].map((p) => DropdownMenuItem(value: p, child: Text(p, style: TextStyle(fontSize: 12, color: _isZaznamityMode ? Colors.white : Colors.black87)))).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedPriority = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: Text('Scheduled Automatic Transfer', style: TextStyle(fontSize: 12, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                    value: scheduledTransfer,
                    activeColor: const Color(0xFFA855F7),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() => scheduledTransfer = val),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedDueDate == null ? 'Due Date: Optional' : 'Due Date: ${DateFormat('yyyy-MM-dd').format(selectedDueDate!)}',
                        style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 180)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2045),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDueDate = picked;
                              updateSuggestedContribution();
                            });
                          }
                        },
                        child: Text('Select Due Date', style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () {
                  final name = nameController.text.trim();
                  final target = _parseNum(targetController.text);
                  final contribution = _parseNum(contributionController.text);
                  if (name.isNotEmpty && target > 0) {
                    final newGoal = SavingsGoalModel(
                      name: name,
                      targetAmount: target,
                      currentAmount: isEmergencyFundTemplate ? 0.0 : 0.0,
                      monthlyContribution: contribution,
                      targetDate: selectedDueDate?.toIso8601String(),
                      owner: dialogOwner,
                    );
                    widget.onSaveGoal(newGoal);
                    Navigator.pop(context);
                  }
                },
                child: Text(isEmergencyFundTemplate ? 'Save Emergency Fund' : 'Add Goal', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredGoals = widget.goals.where((g) {
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners') {
        return g.owner.trim().toLowerCase() == widget.selectedOwner!.trim().toLowerCase();
      }
      return true;
    }).toList();

    Map<String, Map<String, double>> currencyTotals = {};
    for (var goal in filteredGoals) {
      String curr = _userCurrencies.first;
      currencyTotals.putIfAbsent(curr, () => {'saved': 0.0, 'target': 0.0});
      currencyTotals[curr]!['saved'] = currencyTotals[curr]!['saved']! + goal.currentAmount;
      currencyTotals[curr]!['target'] = currencyTotals[curr]!['target']! + goal.targetAmount;
    }

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
                            'SAVINGS GOALS',
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
                          onPressed: () => _showSavingsGoalInfoModal(context),
                          tooltip: 'Savings Goals Guide',
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

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: boxWidth,
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () => _showCreateGoalDialog(isEmergencyFundTemplate: true),
                          icon: const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFA855F7)),
                          label: Text('Emergency Fund', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: boxWidth,
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFFF1F5F9),
                            foregroundColor: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _showCreateGoalDialog(isEmergencyFundTemplate: false),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Add Goal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (currencyTotals.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Savings Progress', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95))),
                        const SizedBox(height: 6),
                        ...currencyTotals.entries.map((entry) {
                          final saved = entry.value['saved']!;
                          final target = entry.value['target']!;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${_getCurrencyFlag(entry.key)} ${entry.key}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                Text('${_formatCurrency(saved, entry.key)} / ${_formatCurrency(target, entry.key)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFF34D399) : const Color(0xFF059669))),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                filteredGoals.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'No savings goals set for this selection.',
                            style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredGoals.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final goal = filteredGoals[index];
                          final double progress = goal.targetAmount > 0 
                              ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0) 
                              : 0.0;
                          
                          final bool isCompleted = goal.currentAmount >= goal.targetAmount;
                          final activeCurr = _userCurrencies.first;
                          final activeFlag = _getCurrencyFlag(activeCurr);
                          
                          final evaluation = _evaluateGoalPaceAndForecast(goal);
                          final forecastText = evaluation['text'] as String;
                          final neededPerMonth = evaluation['neededPerMonth'] as double;
                          final status = evaluation['status'] as String;

                          final dueDateStr = goal.targetDate != null ? DateFormat('yyyy-MM-dd').format(DateTime.parse(goal.targetDate!)) : null;
                          bool isAheadOrOnTrack = goal.monthlyContribution >= neededPerMonth;

                          return Container(
                            padding: const EdgeInsets.all(16),
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
                                    Expanded(
                                      child: Row(
                                        children: [
                                          InkWell(
                                            onTap: () => _showCompletionDialog(goal),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: isCompleted ? Colors.green.shade600 : Colors.grey.shade600,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.check, size: 12, color: Colors.white),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(activeFlag, style: const TextStyle(fontSize: 16)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  goal.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '(${goal.owner})${dueDateStr != null ? ' • Due: $dueDateStr' : ''}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Target: ${_formatCurrency(goal.targetAmount, activeCurr)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: status == 'late' 
                                            ? Colors.red.shade900.withValues(alpha: 0.2)
                                            : const Color(0xFF34D399).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            status == 'late' ? Icons.warning_amber_rounded : Icons.trending_up_rounded,
                                            size: 12,
                                            color: status == 'late' ? Colors.redAccent : const Color(0xFF34D399),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            forecastText,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: status == 'late' ? Colors.redAccent : const Color(0xFF34D399),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Needed: ${_formatCurrency(neededPerMonth, activeCurr)}/mo • ${isAheadOrOnTrack ? '🟢 On Track' : '🔴 Behind'}',
                                      style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white60 : Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 10,
                                    backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFE2E8F0),
                                    valueColor: const SavedProgressColorAnimation(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Saved: ${_formatCurrency(goal.currentAmount, activeCurr)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Color(0xFF34D399),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${(progress * 100).toStringAsFixed(1)}%)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 28,
                                          width: 28,
                                          child: IconButton(
                                            style: IconButton.styleFrom(
                                              backgroundColor: const Color(0xFFEF4444),
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.zero,
                                            ),
                                            icon: const Icon(Icons.remove, size: 16),
                                            tooltip: 'Remove funds from goal',
                                            onPressed: () => _showRemoveFundsDialog(goal),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        SizedBox(
                                          height: 28,
                                          width: 28,
                                          child: IconButton(
                                            style: IconButton.styleFrom(
                                              backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.zero,
                                            ),
                                            icon: const Icon(Icons.add, size: 16),
                                            tooltip: 'Add funds to goal',
                                            onPressed: () => _showAddFundsDialog(goal),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class SavedProgressColorAnimation extends AlwaysStoppedAnimation<Color> {
  const SavedProgressColorAnimation() : super(const Color(0xFF34D399));
}