// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/label.dart';
import '../models/transaction_model.dart';

class NewZaznamCard extends StatefulWidget {
  final List<LabelModel> labels;
  final List<String> pools;
  final List<String> owners;
  final List<TransactionModel> transactions;
  final String? selectedGlobalOwner;
  final Function(
    String description,
    double amount,
    String type,
    int? labelId,
    String owner,
    String pool,
    bool isRecurring,
    String frequency,
    int dayOfMonth,
    List<int> excludedWeekdays,
    List<int> excludedMonths,
    DateTime? repeatUntilDate,
    DateTime date,
    String currencyCode,
  ) onSubmit;
  final VoidCallback? onHide;
  final VoidCallback? onToggleWidth;
  final bool isWide;

  const NewZaznamCard({
    super.key,
    required this.labels,
    required this.pools,
    required this.owners,
    required this.transactions,
    this.selectedGlobalOwner,
    required this.onSubmit,
    this.onHide,
    this.onToggleWidth,
    this.isWide = false,
  });

  @override
  State<NewZaznamCard> createState() => _NewZaznamCardState();
}

class _NewZaznamCardState extends State<NewZaznamCard> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  String _type = 'expense';
  int? _selectedLabelId;
  late String _owner;
  String? _selectedPool;
  bool _isRecurring = false;
  
  String _frequency = 'Monthly';
  int _dayOfMonth = 1;
  DateTime? _repeatUntilDate;

  String _selectedCurrency = 'USD';
  List<String> _availableCurrencies = ['USD'];
  bool _isZaznamityMode = true;

  final Map<String, String> _currencyFlags = {
    'USD': '🇺🇸',
    'EUR': '🇪🇺',
    'JPY': '🇯🇵',
    'GBP': '🇬🇧',
    'CNY': '🇨🇳',
    'AUD': '🇦🇺',
    'CAD': '🇨🇦',
    'CHF': '🇨🇭',
    'HKD': '🇭🇰',
    'SGD': '🇸🇬',
  };

  final List<int> _excludedWeekdays = []; 
  final List<int> _excludedMonths = [];   

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  double _currentInputAmount = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.pools.isNotEmpty) {
      _selectedPool = widget.pools.first;
    }
    _owner = _resolveOwner();
    _dayOfMonth = _selectedDate.day;
    _loadCurrencyPrefs();
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    setState(() {
      _currentInputAmount = double.tryParse(_amountController.text) ?? 0.0;
    });
  }

  Future<void> _loadCurrencyPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final primary = prefs.getString('primaryCurrency') ?? 'USD';
    final sec1 = prefs.getString('secondaryCurrency1');
    final sec2 = prefs.getString('secondaryCurrency2');
    final sec3 = prefs.getString('secondaryCurrency3');

    List<String> currencies = [primary];
    if (sec1 != null) currencies.add(sec1);
    if (sec2 != null) currencies.add(sec2);
    if (sec3 != null) currencies.add(sec3);

    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _availableCurrencies = currencies;
        _selectedCurrency = primary;
      });
    }
  }

  String _resolveOwner() {
    if (widget.selectedGlobalOwner != null && widget.owners.contains(widget.selectedGlobalOwner)) {
      return widget.selectedGlobalOwner!;
    }
    return widget.owners.isNotEmpty ? widget.owners.first : '';
  }

  @override
  void didUpdateWidget(covariant NewZaznamCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.pools.contains(_selectedPool) && widget.pools.isNotEmpty) {
      _selectedPool = widget.pools.first;
    }

    if (widget.selectedGlobalOwner != oldWidget.selectedGlobalOwner || widget.owners != oldWidget.owners) {
      setState(() {
        _owner = _resolveOwner();
      });
    }

    if (widget.owners.isNotEmpty && !widget.owners.contains(_owner)) {
      _owner = widget.owners.first;
    }
    _loadCurrencyPrefs();
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _clearForm() {
    setState(() {
      _descController.clear();
      _amountController.clear();
      _type = 'expense';
      _selectedLabelId = null;
      _owner = _resolveOwner();
      _selectedPool = widget.pools.isNotEmpty ? widget.pools.first : 'checking';
      _isRecurring = false;
      _frequency = 'Monthly';
      _selectedDate = DateTime.now();
      _dayOfMonth = _selectedDate.day;
      _selectedTime = TimeOfDay.now();
      _repeatUntilDate = null;
      _excludedWeekdays.clear();
      _excludedMonths.clear();
      _currentInputAmount = 0.0;
    });
  }

  String _getCurrencySymbol(String code) {
    switch (code) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      default: return '\$';
    }
  }

  bool _isBudgetExceeded() {
    if (_type != 'expense' || _selectedLabelId == null) return false;
    
    double spentSoFar = 0;
    final now = DateTime.now();
    for (var tx in widget.transactions) {
      if (tx.isConfirmed == 1 && tx.type == 'expense' && tx.labelId == _selectedLabelId) {
        final dt = DateTime.tryParse(tx.createdAt);
        if (dt != null && dt.year == now.year && dt.month == now.month) {
          spentSoFar += tx.amount;
        }
      }
    }
    
    const double categoryBudgetLimit = 500.0;
    return (spentSoFar + _currentInputAmount) > categoryBudgetLimit;
  }

  @override
  Widget build(BuildContext context) {
    final bool budgetExceeded = _isBudgetExceeded();

    return LayoutBuilder(
      builder: (context, constraints) {
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
                        'NEW ZAZNAM',
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
                      if (widget.onToggleWidth != null)
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
                      if (widget.onHide != null)
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

              // Row 1: Date & Time Selectors
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                            _dayOfMonth = picked.day;
                          });
                        }
                      },
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
                                DateFormat('MM/dd/yyyy').format(_selectedDate),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (picked != null) setState(() => _selectedTime = picked);
                      },
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
                            Icon(Icons.access_time_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _selectedTime.format(context),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Owners & Expense/Income Dropdown
              Row(
                children: [
                  Expanded(
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
                              child: DropdownButton<String?>(
                                value: widget.owners.contains(_owner) ? _owner : (widget.owners.isNotEmpty ? widget.owners.first : null),
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                items: widget.owners.map((o) => DropdownMenuItem<String?>(
                                  value: o,
                                  child: Text(o, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                )).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _owner = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
                          Icon(Icons.swap_vert_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _type,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                items: [
                                  DropdownMenuItem(value: 'income', child: Text('Income (+)', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  DropdownMenuItem(value: 'expense', child: Text('Expense (-)', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                ],
                                onChanged: (val) => setState(() => _type = val ?? 'expense'),
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

              // Row 3: All Labels & Pool
              Row(
                children: [
                  Expanded(
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
                          Icon(Icons.label_outline_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                value: _selectedLabelId,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                hint: Text('Select Label', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                items: widget.labels.map((l) => DropdownMenuItem<int?>(value: l.id, child: Text(l.name, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))).toList(),
                                onChanged: (val) => setState(() => _selectedLabelId = val),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
                          Icon(Icons.layers_outlined, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedPool,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                hint: Text('Select Pool', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                items: widget.pools.map((p) => DropdownMenuItem<String?>(value: p, child: Text(p.toUpperCase(), style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))).toList(),
                                onChanged: (val) => setState(() => _selectedPool = val ?? widget.pools.first),
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

              // Row 4: Amount & Description
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _amountController,
                      style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '0.00 (${_getCurrencySymbol(_selectedCurrency)})',
                        hintStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8), fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: TextField(
                      controller: _descController,
                      style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Description',
                        hintStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8), fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                ],
              ),

              // Budget Threshold Warning Banner
              if (budgetExceeded) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF3F1722) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isZaznamityMode ? Colors.red.shade800 : const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Warning: This entry exceeds your recommended monthly budget threshold for this category!',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.red.shade200 : const Color(0xFFB91C1C)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Row 5: Currency & Recurring Button
              Row(
                children: [
                  Expanded(
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
                          Text(_currencyFlags[_selectedCurrency] ?? '💵', style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCurrency,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                items: _availableCurrencies.map((c) {
                                  return DropdownMenuItem(
                                    value: c,
                                    child: Text('$c (${_getCurrencySymbol(c)})', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                  );
                                }).toList(),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecurring 
                              ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                              : (_isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9)),
                          foregroundColor: _isRecurring 
                              ? Colors.white 
                              : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155)),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: () => setState(() => _isRecurring = !_isRecurring),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isRecurring ? Icons.check_circle_rounded : Icons.repeat_rounded, 
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text(
                                'Recurring',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (_isRecurring) ...[
                const SizedBox(height: 12),
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
                      Text('RECURRENCE SETTINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('FREQUENCY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  initialValue: _frequency,
                                  isExpanded: true,
                                  dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                  style: TextStyle(fontSize: 12, color: _isZaznamityMode ? Colors.white : Colors.black87),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                                    filled: true,
                                    fillColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                  ),
                                  items: [
                                    DropdownMenuItem(value: 'Daily', child: Text('Daily', style: TextStyle(fontSize: 12, color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                    DropdownMenuItem(value: 'Weekly', child: Text('Weekly', style: TextStyle(fontSize: 12, color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                    DropdownMenuItem(value: 'Monthly', child: Text('Monthly', style: TextStyle(fontSize: 12, color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                    DropdownMenuItem(value: 'Yearly', child: Text('Yearly', style: TextStyle(fontSize: 12, color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  ],
                                  onChanged: (val) => setState(() => _frequency = val ?? 'Monthly'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('REPEAT UNTIL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _repeatUntilDate ?? _selectedDate.add(const Duration(days: 90)),
                                      firstDate: _selectedDate,
                                      lastDate: DateTime(2035),
                                    );
                                    if (picked != null) setState(() => _repeatUntilDate = picked);
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                                      filled: true,
                                      fillColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                      suffixIcon: const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _repeatUntilDate != null ? DateFormat('MM/dd/yyyy').format(_repeatUntilDate!) : 'Select end date',
                                        style: TextStyle(fontSize: 12, color: _repeatUntilDate != null ? (_isZaznamityMode ? Colors.white : Colors.black) : Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      if (_frequency == 'Monthly') ...[
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('WHICH DAY OF MONTH', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              initialValue: _dayOfMonth,
                              isExpanded: true,
                              dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                              style: TextStyle(fontSize: 12, color: _isZaznamityMode ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                                filled: true,
                                fillColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                              ),
                              items: List.generate(31, (index) => index + 1).map((day) => DropdownMenuItem(
                                value: day,
                                child: Text('$day${_getDaySuffix(day)} of the month', style: TextStyle(fontSize: 12, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                              )).toList(),
                              onChanged: (val) => setState(() => _dayOfMonth = val ?? 1),
                            ),
                          ],
                        ),
                      ],

                      if (_frequency == 'Daily' || _frequency == 'Weekly') ...[
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EXCLUDE DAYS OF THE WEEK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              children: [
                                {'label': 'Mon', 'val': 1},
                                {'label': 'Tue', 'val': 2},
                                {'label': 'Wed', 'val': 3},
                                {'label': 'Thu', 'val': 4},
                                {'label': 'Fri', 'val': 5},
                                {'label': 'Sat', 'val': 6},
                                {'label': 'Sun', 'val': 7},
                              ].map((dayMap) {
                                final val = dayMap['val'] as int;
                                final isSelected = _excludedWeekdays.contains(val);
                                return FilterChip(
                                  label: Text(dayMap['label'] as String, style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFFA855F7),
                                  backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFE2E8F0),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _excludedWeekdays.add(val);
                                      } else {
                                        _excludedWeekdays.remove(val);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],

                      if (_frequency == 'Monthly' || _frequency == 'Yearly') ...[
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EXCLUDE MONTHS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                {'label': 'Jan', 'val': 1},
                                {'label': 'Feb', 'val': 2},
                                {'label': 'Mar', 'val': 3},
                                {'label': 'Apr', 'val': 4},
                                {'label': 'May', 'val': 5},
                                {'label': 'Jun', 'val': 6},
                                {'label': 'Jul', 'val': 7},
                                {'label': 'Aug', 'val': 8},
                                {'label': 'Sep', 'val': 9},
                                {'label': 'Oct', 'val': 10},
                                {'label': 'Nov', 'val': 11},
                                {'label': 'Dec', 'val': 12},
                              ].map((monthMap) {
                                final val = monthMap['val'] as int;
                                final isSelected = _excludedMonths.contains(val);
                                return FilterChip(
                                  label: Text(monthMap['label'] as String, style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFFA855F7),
                                  backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFE2E8F0),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _excludedMonths.add(val);
                                      } else {
                                        _excludedMonths.remove(val);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Save Zaznam Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final amount = double.tryParse(_amountController.text) ?? 0.0;
                    if (amount <= 0) return;

                    final targetDay = _frequency == 'Monthly' ? _dayOfMonth : _selectedDate.day;
                    
                    DateTime baseDate = _selectedDate;
                    try {
                      baseDate = DateTime(_selectedDate.year, _selectedDate.month, targetDay, _selectedTime.hour, _selectedTime.minute);
                    } catch (_) {
                      baseDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, _selectedTime.hour, _selectedTime.minute);
                    }

                    widget.onSubmit(
                      _descController.text,
                      amount,
                      _type,
                      _selectedLabelId,
                      _owner,
                      _selectedPool ?? (widget.pools.isNotEmpty ? widget.pools.first : 'checking'),
                      _isRecurring,
                      _frequency,
                      targetDay,
                      _excludedWeekdays,
                      _excludedMonths,
                      _repeatUntilDate,
                      baseDate,
                      _selectedCurrency,
                    );

                    _clearForm();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/ZaznamityLogo_onlyZwhite.png',
                        height: 27,
                        width: 27,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      const Text('Save Zaznam  ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Image.asset(
                        'assets/ZaznamityLogo_onlyZwhite.png',
                        height: 27,
                        width: 27,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
}