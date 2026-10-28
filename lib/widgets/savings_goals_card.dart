// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/savings_goal_model.dart';
import '../models/label.dart';

class SavingsGoalsCard extends StatefulWidget {
  final List<SavingsGoalModel> goals;
  final List<LabelModel> labels;
  final List<String> owners;
  final List<String> pools;
  final String? selectedOwner;
  final Function(SavingsGoalModel) onSaveGoal;
  final Function(int goalId, double amountToAdd, String owner, String fromPool, String goalName, String currency) onAddFundsToGoal;
  final Function(int goalId, double amountToRemove, String owner, String toPool, String goalName, String currency) onRemoveFundsFromGoal;
  final Function(int goalId) onDeleteGoal;
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
    required this.onDeleteGoal,
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
    _loadPrefs();
  }

  String? _getCompletionForecastText(SavingsGoalModel goal, double monthlyContribution) {
    if (goal.currentAmount >= goal.targetAmount) {
      return 'Goal completed!';
    }
    
    if (monthlyContribution <= 0) {
      return null;
    }

    double remaining = goal.targetAmount - goal.currentAmount;
    if (remaining <= 0) return 'On track';

    int monthsNeeded = (remaining / monthlyContribution).ceil();
    DateTime projectedDate = DateTime.now().add(Duration(days: monthsNeeded * 30));
    String formattedDate = DateFormat('MMMM yyyy').format(projectedDate);

    return 'On track to complete by $formattedDate';
  }

  void _checkMilestoneCelebration(double previousAmount, double newAmount, SavingsGoalModel goal) {
    double target = goal.targetAmount;
    if (target <= 0) return;

    double prevPct = (previousAmount / target) * 100;
    double newPct = (newAmount / target) * 100;

    List<double> milestones = [25.0, 50.0, 75.0, 100.0];
    for (var m in milestones) {
      if (prevPct < m && newPct >= m) {
        _showMilestoneDialog(goal.name, m);
        break;
      }
    }
  }

  void _showMilestoneDialog(String goalName, double milestonePct) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.celebration_rounded, color: Color(0xFF34D399), size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Milestone Reached! (${milestonePct.toStringAsFixed(0)}%)',
                style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Fantastic progress! You have reached ${milestonePct.toStringAsFixed(0)}% of your savings goal for "$goalName". Keep up the great momentum!',
          style: TextStyle(fontSize: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569)),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome!'),
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
                  'Savings Goals Guide',
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
              'Savings goals help you earmark funds for target milestones:\n\n'
              '• Add and remove funds dynamically from active pools.\n'
              '• Set automated standing monthly transfers for hands-free progress.\n'
              '• Priority ordering helps cascade excess savings into top-priority goals first.\n'
              '• Milestone celebration effects trigger automatically upon hitting 25%, 50%, 75%, and 100%.\n'
              '• Edit and delete savings goals anytime in Settings.',
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
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
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
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
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
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
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
                final val = double.tryParse(amountController.text);
                if (val != null && val > 0) {
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
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
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
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
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
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
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
                final val = double.tryParse(amountController.text);
                if (val != null && val > 0) {
                  widget.onRemoveFundsFromGoal(goal.id!, val, selectedDialogOwner, selectedDialogPool, goal.name, selectedCurrency);
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

  void _showCreateGoalDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController targetController = TextEditingController();
    final TextEditingController contributionController = TextEditingController();
    
    String selectedCurrency = _userCurrencies.first;
    String dialogOwner = widget.owners.isNotEmpty ? widget.owners.first : 'Shared';
    bool isAutoTransfer = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Create New Savings Goal', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95), fontWeight: FontWeight.bold, fontSize: 16)),
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
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
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
                    labelText: 'Goal Name (e.g. New Car)',
                    labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
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
                        decoration: InputDecoration(
                          labelText: 'Target Amount',
                          labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
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
                          labelText: 'Contribute monthly (opt.)',
                          labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                          filled: true,
                          fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Auto Standing Transfer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : Colors.black87)),
                    Switch(
                      value: isAutoTransfer,
                      activeColor: const Color(0xFFA855F7),
                      onChanged: (val) => setDialogState(() => isAutoTransfer = val),
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
                final target = double.tryParse(targetController.text);
                if (name.isNotEmpty && target != null && target > 0) {
                  final newGoal = SavingsGoalModel(
                    name: name,
                    targetAmount: target,
                    currentAmount: 0.0,
                    owner: dialogOwner,
                  );
                  widget.onSaveGoal(newGoal);
                  setState(() {});
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Savings Goal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedGoals = List<SavingsGoalModel>.from(widget.goals)
      ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));

    return LayoutBuilder(
      builder: (context, constraints) {
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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFFF1F5F9),
                          foregroundColor: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _showCreateGoalDialog,
                        label: const Text('Add Savings Goal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                sortedGoals.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'No savings goals set.',
                            style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedGoals.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final goal = sortedGoals[index];
                          final double progress = goal.targetAmount > 0 
                              ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0) 
                              : 0.0;
                          
                          final bool isCompleted = goal.currentAmount >= goal.targetAmount;
                          final activeSymbol = _getCurrencySymbol(_userCurrencies.first);
                          final activeFlag = _getCurrencyFlag(_userCurrencies.first);
                          final currencyFormat = NumberFormat.currency(symbol: activeSymbol, decimalDigits: 2);
                          // Fallback monthly assumption or calculation if model lacks property
                          final forecastText = _getCompletionForecastText(goal, 150.0);

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
                                          if (isCompleted) ...[
                                            InkWell(
                                              onTap: () => widget.onCompleteGoal(goal.id!),
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade600,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.check, size: 12, color: Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
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
                                                  '(${goal.owner})',
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
                                    Row(
                                      children: [
                                        Text(
                                          'Target: ${currencyFormat.format(goal.targetAmount)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => widget.onDeleteGoal(goal.id!),
                                          child: Icon(Icons.close, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8), size: 16),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (forecastText != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF34D399).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.trending_up_rounded,
                                          size: 12,
                                          color: Color(0xFF34D399),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          forecastText,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF34D399),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 10,
                                    backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFE2E8F0),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Saved: ${currencyFormat.format(goal.currentAmount)}',
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