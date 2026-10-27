// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/label.dart';
import '../models/transaction_model.dart';

class BudgetProgressCard extends StatefulWidget {
  final List<Map<String, dynamic>> budgets;
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
  final String? selectedOwner;
  final ValueChanged<String?>? onOwnerChanged;
  final Function(int labelId, double limitAmount, String owner) onAddBudget;
  final Function(int budgetId, double newLimit) onUpdateBudgetLimit;
  final Function(int budgetId) onDeleteBudget;
  final bool isWide;
  final VoidCallback onToggleWidth;
  final VoidCallback onHide;

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
    required this.isWide,
    required this.onToggleWidth,
    required this.onHide,
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
      });
    }
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

  void _showAddBudgetDialog(BuildContext context) {
    int? selectedLabelId = widget.labels.isNotEmpty ? widget.labels.first.id : null;
    
    String selectedDialogOwner = (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty)
        ? widget.selectedOwner!
        : (widget.owners.isNotEmpty ? widget.owners.first : '');

    final limitController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add Budget Limit', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedLabelId,
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
                onChanged: (val) {
                  setDialogState(() => selectedLabelId = val);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: widget.owners.contains(selectedDialogOwner) ? selectedDialogOwner : (widget.owners.isNotEmpty ? widget.owners.first : null),
                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Select Owner',
                  labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                  filled: true,
                  fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                ),
                items: widget.owners.map((owner) {
                  return DropdownMenuItem<String>(
                    value: owner,
                    child: Text(owner, style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedDialogOwner = val);
                  }
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: limitController,
                style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Monthly Limit (${_getCurrencySymbol(_selectedCurrency)})',
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
                final limit = double.tryParse(limitController.text);
                if (selectedLabelId != null && limit != null && limit > 0) {
                  widget.onAddBudget(selectedLabelId!, limit, selectedDialogOwner);
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

  @override
  Widget build(BuildContext context) {
    _loadPrefs();
    final currencySymbol = _getCurrencySymbol(_selectedCurrency);
    final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);

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

    List<Map<String, dynamic>> processedBudgets = filteredBudgets.map((b) {
      final labelId = b['label_id'] ?? b['labelId'];
      double limit = ((b['limit_amount'] ?? b['limitAmount'] ?? 0) as num).toDouble();
      final owner = b['owner'] ?? 'Shared';
      
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
            if (txDate.isBefore(DateTime(_selectedMonth.year, _selectedMonth.month, 1))) {
              String monthKey = '${txDate.year}-${txDate.month.toString().padLeft(2, '0')}';
              pastMonthExpenses[monthKey] = (pastMonthExpenses[monthKey] ?? 0) + tx.amount;
            }
          }
        }

        pastMonthExpenses.forEach((monthKey, monthSpent) {
          double monthSurplus = limit - monthSpent;
          if (monthSurplus > 0) {
            rolloverAmount += monthSurplus;
          }
        });

        limit += rolloverAmount;
      }

      totalSpentAll += spent;
      totalLimitAll += limit;

      return {
        'id': b['id'],
        'label_name': labelObj.name,
        'label_color': labelObj.color.startsWith('#') ? labelObj.color : '#${labelObj.color}',
        'owner': owner,
        'spent': spent,
        'limit': limit,
        'remaining': limit - spent,
      };
    }).toList();

    double overallProgress = totalLimitAll > 0 ? (totalSpentAll / totalLimitAll).clamp(0.0, 1.0) : 0.0;
    double overallRemaining = totalLimitAll - totalSpentAll;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 48;
        final double boxWidth = (fullWidth - 12) / 2;

        return Container(
          padding: const EdgeInsets.all(24),
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
                    child: FittedBox(
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
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: SizedBox(
                          height: 32,
                          width: 32,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                              foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
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
                      SizedBox(
                        height: 32,
                        width: 32,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                            foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
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
                              child: DropdownButton<String>(
                                value: widget.selectedOwner ?? 'All Owners',
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                items: [
                                  DropdownMenuItem(value: 'All Owners', child: Text('All Owners', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  ...widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    widget.onOwnerChanged?.call(val == 'All Owners' ? null : val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_budgetDefaultRange == 'Current Month')
                    SizedBox(
                      width: boxWidth,
                      child: InkWell(
                        onTap: () => _selectMonth(context),
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
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  DateFormat('MMM yyyy').format(_selectedMonth),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: boxWidth,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.update_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${DateFormat('MMM d').format(rollingStart)} - ${DateFormat('MMM d').format(now)}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                overflow: TextOverflow.ellipsis,
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
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Text(_currencyFlags[_selectedCurrency] ?? '💵', style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCurrency,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                items: _availableCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCurrency = val);
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
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFFF1F5F9),
                          foregroundColor: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => _showAddBudgetDialog(context),
                        label: const Text('Add Budget', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                  Text(
                    'Total: ${currencyFormat.format(totalSpentAll)} / ${currencyFormat.format(totalLimitAll)}',
                    style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    overallRemaining >= 1 
                        ? 'Left: ${currencyFormat.format(overallRemaining)}' 
                        : 'Over: ${currencyFormat.format(overallRemaining.abs())}',
                    style: TextStyle(
                      color: overallRemaining < 0 ? Colors.red.shade400 : const Color(0xFF34D399),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
                  : (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty)
                      ? _buildBudgetList(processedBudgets, currencyFormat)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: widget.owners.map((owner) {
                            final ownerBudgets = processedBudgets
                                .where((b) => (b['owner'] as String).toLowerCase() == owner.toLowerCase())
                                .toList();
                            if (ownerBudgets.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    owner.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildBudgetList(ownerBudgets, currencyFormat),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetList(List<Map<String, dynamic>> budgets, NumberFormat currencyFormat) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: budgets.length,
      itemBuilder: (context, index) {
        final b = budgets[index];
        final spent = b['spent'] as double;
        final limit = b['limit'] as double;
        final remaining = b['remaining'] as double;
        final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
        final isOverBudget = spent > limit;
        final colorHex = b['label_color'].toString().replaceAll('#', '');
        final cardColor = Color(int.parse('0xFF$colorHex'));

        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: Column(
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
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${currencyFormat.format(spent)} / ${currencyFormat.format(limit)}',
                            style: TextStyle(
                              color: isOverBudget ? Colors.red.shade400 : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                              fontSize: 12,
                              fontWeight: isOverBudget ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          Text(
                            remaining >= 0 ? 'Left: ${currencyFormat.format(remaining)}' : 'Over: ${currencyFormat.format(remaining.abs())}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: remaining >= 0 ? const Color(0xFF34D399) : Colors.red.shade400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => widget.onDeleteBudget(b['id']),
                        child: Icon(Icons.close, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8), size: 16),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverBudget ? Colors.red.shade400 : cardColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}