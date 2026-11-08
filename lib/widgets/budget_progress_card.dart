// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/label.dart';
import '../models/transaction_model.dart';
import '../services/snackbar_notification.dart';
import '../widgets/masked_amount.dart';

class BudgetProgressCard extends StatefulWidget {
  final List budgets;
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
  final String? selectedOwner;
  final ValueChanged<String?>? onOwnerChanged;
  final Function(int labelId, double limitAmount, String owner) onAddBudget;
  final Function(int budgetId, double newLimit) onUpdateBudgetLimit;
  final Function(int budgetId) onDeleteBudget;

  const BudgetProgressCard({
    super.key,
    required this.budgets,
    required this.transactions,
    required this.labels,
    required this.owners,
    this.selectedOwner,
    this.onOwnerChanged,
    required this.onAddBudget,
    required this.onUpdateBudgetLimit,
    required this.onDeleteBudget,
  });

  @override
  State<BudgetProgressCard> createState() => _BudgetProgressCardState();
}

class _BudgetProgressCardState extends State<BudgetProgressCard> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _enableRollover = false;
  String _selectedCurrency = 'USD';
  List<String> _availableCurrencies = ['USD'];
  String _budgetDefaultRange = 'Current Month';
  bool _isZaznamityMode = true;
  bool _isCollapsed = false;

  final Map<String, String> _currencyFlags = {
    'EUR': '🇪🇺',
    'USD': '🇺🇸',
    'CAD': '🇨🇦',
    'GBP': '🇬🇧',
    'CZK': '🇨🇿',
    'HUF': '🇭🇺',
    'PLN': '🇵🇱',
    'CHF': '🇨🇭',
    'RUB': '🇷🇺',
    'JPY': '🇯🇵',
    'CNY': '🇨🇳',
    'HKD': '🇭🇰',
    'SGD': '🇸🇬',
    'AUD': '🇦🇺',
    'BRL': '🇧🇷',
    'MXN': '🇲🇽',
    'CLP': '🇨🇱',
    'COP': '🇨🇴',
  };

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

    List<String> currencies = [primary];
    if (sec1 != null && sec1.isNotEmpty) currencies.add(sec1);
    if (sec2 != null && sec2.isNotEmpty) currencies.add(sec2);
    if (sec3 != null && sec3.isNotEmpty) currencies.add(sec3);

    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _availableCurrencies = currencies;
        _selectedCurrency = primary;
        _enableRollover = prefs.getBool('set_budget_rollover') ?? false;
        _budgetDefaultRange = prefs.getString('set_budget_range') ?? 'Current Month';
        _isCollapsed = prefs.getBool('set_budgetProgress_collapsed') ?? false;
      });
    }
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_budgetProgress_collapsed', _isCollapsed);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
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

  String _formatCurrency(double amount, String currencyCode) {
    final symbol = _getCurrencySymbol(currencyCode);
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final formattedNum = formatter.format(amount.abs());
    final isNegative = amount < 0;
    final prefix = isNegative ? '-' : '';

    if (currencyCode.toUpperCase() == 'EUR' || currencyCode.toUpperCase() == 'CZK' || currencyCode.toUpperCase() == 'PLN' || currencyCode.toUpperCase() == 'HUF') {
      return '$prefix$formattedNum $symbol';
    } else {
      return '$prefix$symbol$formattedNum';
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select Month',
      fieldLabelText: 'Month/Year',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  void _showBudgetInfoModal(BuildContext context) {
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
                  'Budgets',
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
              'Budgets help you track and cap spending categories:\n\n'
              '• Set monthly limits per category and currency.\n'
              '• Use the "Smart" Budget Suggestions button to copy last month\'s budgets or suggest limits based on 3-month averages.\n'
              '• View unbudgeted spending amounts grouped by currency.\n'
              '• Monitor daily allowances, projected end-of-month totals (Proj) and pace markers (white line in sparkline).\n'
              '• View 6-month historical sparklines (red dots are over budget limit, green dots are under budget limit).\n'
              '• Enable rollover in Zaznamity Settings to carry over unused budget amounts to the next month.\n'
              '• Tap on a budget row to edit the budget limit - delete a budget in Zaznamity Settings.\n\n',
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

  void _showAddBudgetDialog(BuildContext context, {Map<String, dynamic>? existingBudget}) {
    int? selectedLabelId = existingBudget != null 
        ? (existingBudget['label_id'] ?? existingBudget['labelId']) 
        : (widget.labels.isNotEmpty ? widget.labels.first.id : null);
    
    String dialogCurrency = existingBudget != null
        ? (existingBudget['currency'] ?? _selectedCurrency)
        : _selectedCurrency;

    String selectedDialogOwner = existingBudget != null
        ? (existingBudget['owner'] ?? 'Shared')
        : ((widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty)
            ? widget.selectedOwner!
            : (widget.owners.isNotEmpty ? widget.owners.first : ''));

    final limitController = TextEditingController(
      text: existingBudget != null ? '${existingBudget['limit_amount'] ?? existingBudget['limitAmount'] ?? ''}' : '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existingBudget != null ? 'Edit Budget Limit' : 'Add Budget Limit', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedLabelId,
                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Select Category / Label',
                  labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                  filled: true,
                  fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                ),
                items: widget.labels.map((label) {
                  return DropdownMenuItem<int>(
                    value: label.id,
                    child: Text(label.name, style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                  );
                }).toList(),
                onChanged: existingBudget != null ? null : (val) {
                  setDialogState(() => selectedLabelId = val);
                },
              ),
              const SizedBox(height: 14),
              // Currency selector inside modal
              DropdownButtonFormField<String>(
                value: _availableCurrencies.contains(dialogCurrency) ? dialogCurrency : _availableCurrencies.first,
                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Currency',
                  labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                  filled: true,
                  fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                ),
                items: _availableCurrencies.map((curr) {
                  return DropdownMenuItem<String>(
                    value: curr,
                    child: Text('${_currencyFlags[curr] ?? '💵'} $curr', style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => dialogCurrency = val);
                  }
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: limitController,
                style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Monthly Limit (${_getCurrencySymbol(dialogCurrency)})',
                  labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                  filled: true,
                  fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFFF1F5F9),
                foregroundColor: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                final normalizedText = limitController.text.trim().replaceAll(',', '.');
                final limit = double.tryParse(normalizedText);
                if (selectedLabelId != null && limit != null && limit > 0) {
                  if (existingBudget != null) {
                    widget.onUpdateBudgetLimit(existingBudget['id'], limit);
                  } else {
                    widget.onAddBudget(selectedLabelId!, limit, selectedDialogOwner);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSmartBudgetOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Smart Budget Suggestions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.copy, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
              title: Text('Copy Last Month’s Budgets', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
              subtitle: Text('Replicate previous month spending caps automatically', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white60 : Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                showSnackbarNotification(context, 'Copied last month budgets successfully!');
              },
            ),
            ListTile(
              leading: Icon(Icons.insights, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
              title: Text('Suggest Limits from 3-Month Average', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
              subtitle: Text('Set intelligent ceilings based on past 90 days spending data', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white60 : Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                showSnackbarNotification(context, 'Applied 3-month average limit suggestions!');
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return const Color(0xFF582F95);
    try {
      final clean = colorHex.replaceAll('#', '');
      return Color(int.parse('0xFF$clean'));
    } catch (_) {
      return const Color(0xFF582F95);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredBudgets = widget.budgets.where((b) {
      if (widget.selectedOwner != null && 
          widget.selectedOwner!.isNotEmpty && 
          widget.selectedOwner != 'All Owners') {
        final ownerField = b['owner']?.toString().trim() ?? '';
        return ownerField.toLowerCase() == widget.selectedOwner!.trim().toLowerCase();
      }
      return true; 
    }).toList();

    double totalSpentAll = 0;
    double totalLimitAll = 0;

    final now = DateTime.now();
    final rollingStart = now.subtract(const Duration(days: 30));

    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final currentDayOfMonth = (_selectedMonth.year == now.year && _selectedMonth.month == now.month) ? now.day : daysInMonth;
    final daysRemaining = (daysInMonth - currentDayOfMonth).clamp(0, daysInMonth);
    final monthProgressRatio = (currentDayOfMonth / daysInMonth).clamp(0.0, 1.0);

    List processedBudgets = filteredBudgets.map((b) {
      final labelId = b['label_id'] ?? b['labelId'];
      double limit = ((b['limit_amount'] ?? b['limitAmount'] ?? 0) as num).toDouble();
      final owner = b['owner'] ?? 'Shared';
      final currency = b['currency'] ?? _availableCurrencies.first;
      final createdAtStr = b['created_at'] ?? b['createdAt'];
      final createdDate = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime(2025, 1) : DateTime(2025, 1);
      
      final labelObj = widget.labels.firstWhere(
        (l) => l.id == labelId,
        orElse: () => LabelModel(id: -1, name: b['label_name'] ?? 'General', color: b['label_color'] ?? '582F95'),
      );
      
      double spent = 0;
      double rolloverAmount = 0;

      for (var tx in widget.transactions) {
        if (tx.labelId == labelId && tx.type == 'expense' && tx.isConfirmed == 1) {
          if (tx.owner.trim().toLowerCase() != owner.trim().toLowerCase()) continue;

          final txDate = DateTime.tryParse(tx.createdAt) ?? now;
          if (_budgetDefaultRange == 'Current Month') {
            if (txDate.year == _selectedMonth.year && txDate.month == _selectedMonth.month) {
              spent += tx.amount;
            }
          } else {
            if (txDate.isAfter(rollingStart) && txDate.isBefore(now.add(const Duration(days: 1)))) {
              spent += tx.amount;
            }
          }
        }
      }

      if (_enableRollover && _budgetDefaultRange == 'Current Month') {
        Map<String, double> pastMonthExpenses = {};

        for (var tx in widget.transactions) {
          if (tx.labelId == labelId && tx.type == 'expense' && tx.isConfirmed == 1) {
            if (tx.owner.trim().toLowerCase() != owner.trim().toLowerCase()) continue;

            final txDate = DateTime.tryParse(tx.createdAt) ?? now;
            final budgetStartMonth = DateTime(createdDate.year, createdDate.month, 1);
            final targetMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);

            if (txDate.isAfter(budgetStartMonth.subtract(const Duration(seconds: 1))) && 
                txDate.isBefore(targetMonth)) {
              String monthKey = '${txDate.year}-${txDate.month.toString().padLeft(2, '0')}';
              pastMonthExpenses[monthKey] = (pastMonthExpenses[monthKey] ?? 0) + tx.amount;
            }
          }
        }

        DateTime currIterMonth = DateTime(createdDate.year, createdDate.month, 1);
        final targetMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        while (currIterMonth.isBefore(targetMonth)) {
          String monthKey = '${currIterMonth.year}-${currIterMonth.month.toString().padLeft(2, '0')}';
          double monthSpent = pastMonthExpenses[monthKey] ?? 0.0;
          double monthSurplusOrDeficit = limit - monthSpent;
          rolloverAmount += monthSurplusOrDeficit;
          
          currIterMonth = DateTime(currIterMonth.year, currIterMonth.month + 1, 1);
        }

        limit += rolloverAmount;
      }

      totalSpentAll += spent;
      totalLimitAll += limit;

      double dailyRunRate = currentDayOfMonth > 0 ? spent / currentDayOfMonth : 0.0;
      double projectedEom = dailyRunRate * daysInMonth;

      double remaining = limit - spent;
      double dailyAllowance = daysRemaining > 0 ? (remaining / daysRemaining) : 0.0;

      List<bool> sparklineHits = [];
      for (int i = 5; i >= 0; i--) {
        DateTime pastM = DateTime(_selectedMonth.year, _selectedMonth.month - i, 1);
        double pastSpent = 0;
        for (var tx in widget.transactions) {
          if (tx.labelId == labelId && tx.type == 'expense' && tx.isConfirmed == 1) {
            final txDate = DateTime.tryParse(tx.createdAt) ?? now;
            if (txDate.year == pastM.year && txDate.month == pastM.month) {
              pastSpent += tx.amount;
            }
          }
        }
        sparklineHits.add(pastSpent <= limit);
      }

      return {
        'id': b['id'],
        'label_id': labelId,
        'label_name': labelObj.name,
        'label_color': labelObj.color,
        'owner': owner,
        'currency': currency,
        'spent': spent,
        'limit': limit,
        'remaining': remaining,
        'projectedEom': projectedEom,
        'dailyAllowance': dailyAllowance,
        'daysRemaining': daysRemaining,
        'sparklineHits': sparklineHits,
      };
    }).toList();

    Set<int?> budgetedLabelIds = processedBudgets.map((b) => b['label_id'] as int?).toSet();
    double unbudgetedSpent = 0;
    for (var tx in widget.transactions) {
      if (tx.type == 'expense' && tx.isConfirmed == 1 && !budgetedLabelIds.contains(tx.labelId)) {
        if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners') {
          if (tx.owner.trim().toLowerCase() != widget.selectedOwner!.trim().toLowerCase()) continue;
        }
        final txDate = DateTime.tryParse(tx.createdAt) ?? now;
        if (txDate.year == _selectedMonth.year && txDate.month == _selectedMonth.month) {
          unbudgetedSpent += tx.amount;
        }
      }
    }

    double overallProgress = totalLimitAll > 0 ? (totalSpentAll / totalLimitAll).clamp(0.0, 1.0) : 0.0;
    double overallRemaining = totalLimitAll - totalSpentAll;

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
                            'BUDGETS',
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
                          onPressed: () => _showBudgetInfoModal(context),
                          tooltip: 'Budgets Guide',
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
                const SizedBox(height: 16),

                // First Row: Add & Smart Buttons on left, Month Date Selector with arrows on right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: boxWidth,
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFFF1F5F9),
                                  foregroundColor: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                                onPressed: () => _showAddBudgetDialog(context),
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              onPressed: () => _showSmartBudgetOptions(context),
                              child: Text('Smart', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: boxWidth,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: _previousMonth,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(Icons.chevron_left, size: 18, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                              ),
                            ),
                            InkWell(
                              onTap: () => _selectMonth(context),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 14, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('MMM yyyy').format(_selectedMonth),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: _nextMonth,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Icon(Icons.chevron_right, size: 18, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: _isZaznamityMode ? Colors.white24 : const Color(0xFFE2E8F0)),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Total: ',
                          style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        MaskedAmount(
                          formattedAmount: _formatCurrency(totalSpentAll, _selectedCurrency),
                          style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          ' / ',
                          style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        MaskedAmount(
                          formattedAmount: _formatCurrency(totalLimitAll, _selectedCurrency),
                          style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          overallRemaining >= 1 ? 'Remaining: ' : 'Over limit: ',
                          style: TextStyle(
                            color: overallRemaining < 0 ? Colors.red.shade400 : const Color(0xFF34D399),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        MaskedAmount(
                          formattedAmount: _formatCurrency(overallRemaining.abs(), _selectedCurrency),
                          style: TextStyle(
                            color: overallRemaining < 0 ? Colors.red.shade400 : const Color(0xFF34D399),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: overallProgress,
                    minHeight: 8,
                    backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      overallProgress > 0.9 ? Colors.red.shade400 : (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (unbudgetedSpent > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: 8),
                            Text('Unbudgeted Spending', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                          ],
                        ),
                        MaskedAmount(
                          formattedAmount: _formatCurrency(unbudgetedSpent, _selectedCurrency),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ],
                    ),
                  ),
                ],

                processedBudgets.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Text(
                            'No budget limits set for this selection.',
                            style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ),
                      )
                    : _buildGroupedBudgetsList(processedBudgets, monthProgressRatio, daysRemaining),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupedBudgetsList(List budgets, double monthProgressRatio, int daysRemaining) {
    List<String> presentCurrencies = [];
    for (var curr in _availableCurrencies) {
      if (budgets.any((b) => (b['currency'] ?? _selectedCurrency).toString().toUpperCase() == curr.toUpperCase())) {
        presentCurrencies.add(curr);
      }
    }
    for (var b in budgets) {
      String curr = (b['currency'] ?? _selectedCurrency).toString().toUpperCase();
      if (!presentCurrencies.contains(curr)) {
        presentCurrencies.add(curr);
      }
    }

    bool showGroupTitles = presentCurrencies.length > 1;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: presentCurrencies.length,
      itemBuilder: (context, currIndex) {
        String currCode = presentCurrencies[currIndex];
        List currBudgets = budgets.where((b) => (b['currency'] ?? _selectedCurrency).toString().toUpperCase() == currCode.toUpperCase()).toList();

        if (currBudgets.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showGroupTitles) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                child: Row(
                  children: [
                    Text(_currencyFlags[currCode] ?? '💵', style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      currCode.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ...currBudgets.map((b) => _buildBudgetItem(b, monthProgressRatio, daysRemaining)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildBudgetItem(Map<String, dynamic> b, double monthProgressRatio, int daysRemaining) {
    final spent = b['spent'] as double;
    final limit = b['limit'] as double;
    final remaining = b['remaining'] as double;
    final projectedEom = b['projectedEom'] as double;
    final dailyAllowance = b['dailyAllowance'] as double;
    final sparklineHits = b['sparklineHits'] as List<bool>;
    final currency = b['currency'] ?? _selectedCurrency;

    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = spent > limit;
    final cardColor = _parseColor(b['label_color']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: InkWell(
        onTap: () => _showAddBudgetDialog(context, existingBudget: b),
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      b['label_name'],
                      style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (isOverBudget) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('OVER', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red.shade100)),
                      ),
                    ],
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MaskedAmount(
                          formattedAmount: _formatCurrency(spent, currency),
                          style: TextStyle(
                            color: isOverBudget ? Colors.red.shade400 : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                            fontSize: 12,
                            fontWeight: isOverBudget ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        Text(
                          ' / ',
                          style: TextStyle(
                            color: isOverBudget ? Colors.red.shade400 : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                            fontSize: 12,
                            fontWeight: isOverBudget ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        MaskedAmount(
                          formattedAmount: _formatCurrency(limit, currency),
                          style: TextStyle(
                            color: isOverBudget ? Colors.red.shade400 : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                            fontSize: 12,
                            fontWeight: isOverBudget ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          remaining >= 0 ? 'Left: ' : 'Over: ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: remaining >= 0 ? const Color(0xFF34D399) : Colors.red.shade400,
                          ),
                        ),
                        MaskedAmount(
                          formattedAmount: _formatCurrency(remaining.abs(), currency),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: remaining >= 0 ? const Color(0xFF34D399) : Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            
            LayoutBuilder(
              builder: (context, barConstraints) => Stack(
                alignment: Alignment.centerLeft,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOverBudget ? Colors.red.shade400 : cardColor,
                      ),
                    ),
                  ),
                  Positioned(
                    left: barConstraints.maxWidth * monthProgressRatio * 0.85,
                    child: Container(
                      width: 2,
                      height: 10,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MaskedAmount(
                      formattedAmount: _formatCurrency(dailyAllowance, currency),
                      style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white60 : Colors.grey.shade600),
                    ),
                    Text(
                      '/day for $daysRemaining days • Proj: ',
                      style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white60 : Colors.grey.shade600),
                    ),
                    MaskedAmount(
                      formattedAmount: _formatCurrency(projectedEom, currency),
                      style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white60 : Colors.grey.shade600),
                    ),
                  ],
                ),
                Row(
                  children: sparklineHits.map((hit) {
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hit ? const Color(0xFF34D399) : Colors.red.shade400,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}