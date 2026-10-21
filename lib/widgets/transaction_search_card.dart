// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class TransactionSearchCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
  final List<String> pools;
  
  final Function(int) onDeleteTransaction;
  final Function(TransactionModel) onEditTransaction;
  final Function(TransactionModel) onConfirmTransaction;
  
  final bool isWide;
  final VoidCallback onToggleWidth;
  final VoidCallback onHide;

  const TransactionSearchCard({
    super.key,
    required this.transactions,
    required this.labels,
    required this.owners,
    this.pools = const [],
    required this.onDeleteTransaction,
    required this.onEditTransaction,
    required this.onConfirmTransaction,
    required this.isWide,
    required this.onToggleWidth,
    required this.onHide,
  });

  @override
  State<TransactionSearchCard> createState() => _TransactionSearchCardState();
}

class _TransactionSearchCardState extends State<TransactionSearchCard> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  Timer? _debounceTimer;

  int? _selectedLabelId;
  String? _selectedOwner;
  String? _selectedType;
  String? _selectedPool;
  String? _selectedCurrency;
  List<String> _availableCurrencies = ['USD'];

  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedLimit = '50';
  String _debouncedQuery = '';
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

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      default: return '\$';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCurrencyPrefs();
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
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _debouncedQuery = val.trim().toLowerCase();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDateFilter = _startDate != null || _endDate != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 48;
        final double boxWidth = (fullWidth - 12) / 2;

        final double? minAmount = double.tryParse(_minAmountController.text);
        final double? maxAmount = double.tryParse(_maxAmountController.text);

        final bool hasActiveFilter = _debouncedQuery.isNotEmpty ||
            _selectedLabelId != null ||
            _selectedOwner != null ||
            _selectedType != null ||
            _selectedPool != null ||
            _selectedCurrency != null ||
            _startDate != null ||
            _endDate != null ||
            minAmount != null ||
            maxAmount != null;

        final filteredTransactions = !hasActiveFilter
            ? <TransactionModel>[]
            : widget.transactions.where((tx) {
                if (_debouncedQuery.isNotEmpty) {
                  final desc = tx.description.toLowerCase();
                  if (!desc.contains(_debouncedQuery)) return false;
                }
                if (_selectedLabelId != null && tx.labelId != _selectedLabelId) return false;
                if (_selectedOwner != null && tx.owner != _selectedOwner) return false;
                if (_selectedType != null && tx.type != _selectedType) return false;
                if (_selectedPool != null && tx.pool != _selectedPool) return false;
                
                if (_selectedCurrency != null && tx.currencyCode != _selectedCurrency) {
                  return false;
                }

                if (minAmount != null && tx.amount < minAmount) return false;
                if (maxAmount != null && tx.amount > maxAmount) return false;

                final txDate = DateTime.tryParse(tx.createdAt);
                if (txDate != null) {
                  if (_startDate != null) {
                    final startClean = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
                    if (txDate.isBefore(startClean)) return false;
                  }
                  if (_endDate != null) {
                    final endClean = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
                    if (txDate.isAfter(endClean)) return false;
                  }
                }

                return true;
              }).toList();

        final int totalFound = filteredTransactions.length;
        int displayLimit = totalFound;
        if (_selectedLimit != 'All') {
          displayLimit = int.tryParse(_selectedLimit) ?? 50;
        }
        final displayedTransactions = filteredTransactions.take(displayLimit).toList();

        return Container(
          padding: const EdgeInsets.all(24.0),
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
                  borderRadius: BorderRadius.circular(20.0),
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
                        'SEARCH ZAZNAMS',
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

              // Row 1: Owners & All Types
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
                              child: DropdownButton<String?>(
                                value: _selectedOwner,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                hint: Text('All Owners', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                items: [
                                  DropdownMenuItem<String?>(value: null, child: Text('All Owners', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  ...widget.owners.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
                                ],
                                onChanged: (val) => setState(() => _selectedOwner = val),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                          Icon(Icons.swap_vert_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedType,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                hint: Text('All Types', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                items: [
                                  DropdownMenuItem<String?>(value: null, child: Text('All Types', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  DropdownMenuItem<String?>(value: 'income', child: Text('Income', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  DropdownMenuItem<String?>(value: 'expense', child: Text('Expense', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                ],
                                onChanged: (val) => setState(() => _selectedType = val),
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

              // Row 2: All Labels & All Pools
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
                                hint: Text('All Labels', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                items: [
                                  DropdownMenuItem<int?>(value: null, child: Text('All Labels', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  ...widget.labels.map((l) => DropdownMenuItem<int?>(value: l.id, child: Text(l.name, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
                                ],
                                onChanged: (val) => setState(() => _selectedLabelId = val),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                                hint: Text('All Pools', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                items: [
                                  DropdownMenuItem<String?>(value: null, child: Text('All Pools', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  ...widget.pools.map((p) => DropdownMenuItem<String?>(value: p, child: Text(p, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
                                ],
                                onChanged: (val) => setState(() => _selectedPool = val),
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

              // Row 3: Currency Dropdown & Date Range Picker
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
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedCurrency,
                          isDense: true,
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                          hint: Row(
                            children: [
                              Icon(Icons.public, size: 14, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                              const SizedBox(width: 6),
                              Text('All Currencies', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                            ],
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null, 
                              child: Row(
                                children: [
                                  Icon(Icons.public, size: 14, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                  const SizedBox(width: 6),
                                  Text('All Currencies', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                ],
                              ),
                            ),
                            ..._availableCurrencies.map((c) => DropdownMenuItem<String?>(
                              value: c, 
                              child: Row(
                                children: [
                                  Text(_currencyFlags[c] ?? '💵', style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(c, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                ],
                              ),
                            )),
                          ],
                          onChanged: (val) => setState(() => _selectedCurrency = val),
                        ),
                      ),
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
                              color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.horizontal(
                                left: const Radius.circular(10),
                                right: hasDateFilter ? Radius.zero : const Radius.circular(10),
                              ),
                              border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                    initialDateRange: (_startDate != null && _endDate != null)
                                        ? DateTimeRange(start: _startDate!, end: _endDate!)
                                        : null,
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _startDate = picked.start;
                                      _endDate = picked.end;
                                    });
                                  }
                                },
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
                                          _startDate != null && _endDate != null
                                              ? '${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}'
                                              : 'Date Range',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: hasDateFilter
                                                ? (_isZaznamityMode ? Colors.white : const Color(0xFF1E293B))
                                                : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                            fontWeight: hasDateFilter
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!hasDateFilter)
                                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (hasDateFilter) ...[
                          const SizedBox(width: 1),
                          Container(
                            height: 44,
                            width: 36,
                            decoration: BoxDecoration(
                              color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFE2E8F0),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                              border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                }),
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                child: const Center(
                                  child: Icon(Icons.clear, size: 14, color: Color(0xFFDC2626)),
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

              // Row 4: Min Amount & Max Amount Text Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: boxWidth,
                    child: TextField(
                      controller: _minAmountController,
                      style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.attach_money_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                        hintText: 'Min Amount',
                        hintStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8), fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: boxWidth,
                    child: TextField(
                      controller: _maxAmountController,
                      style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.attach_money_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                        hintText: 'Max Amount',
                        hintStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8), fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 5: Search Description Bar
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search description keywords...',
                  hintStyle: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search, size: 18, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF64748B)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                  filled: true,
                  fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 12),

              // Results Count & Pagination Limit Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${displayedTransactions.length} of $totalFound found',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  Row(
                    children: [
                      Text('Show: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLimit,
                          isDense: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF475569)),
                          items: ['50', '100', '150', '200', 'All']
                              .map((lim) => DropdownMenuItem(value: lim, child: Text(lim, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedLimit = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Results List Container
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFE2E8F0)),
                ),
                child: !hasActiveFilter
                    ? Center(
                        child: Text(
                          'Select filters or type keywords above to show results.',
                          style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8)),
                        ),
                      )
                    : displayedTransactions.isEmpty
                        ? Center(
                            child: Text(
                              'No matching transactions found.',
                              style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.separated(
                            cacheExtent: 1000,
                            itemCount: displayedTransactions.length,
                            separatorBuilder: (context, index) => Divider(color: _isZaznamityMode ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
                            itemBuilder: (context, index) {
                              final tx = displayedTransactions[index];
                              final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
                              final formattedDate = DateFormat('MMM d, yyyy hh:mm a').format(txDate);
                              
                              final labelObj = widget.labels.firstWhere(
                                (l) => l.id == tx.labelId,
                                orElse: () => LabelModel(id: 0, name: 'General', color: '#4338CA'),
                              );

                              final currencyCode = tx.currencyCode.isNotEmpty ? tx.currencyCode : 'USD';
                              final flag = _currencyFlags[currencyCode] ?? '🇺🇸';
                              final symbol = _getCurrencySymbol(currencyCode);

                              final isIncome = tx.type == 'income';
                              final amountString = '${isIncome ? '+' : '-'}$symbol${tx.amount.toStringAsFixed(2)}';
                              final isConfirmed = tx.isConfirmed == 1;
                              final isFuture = txDate.isAfter(DateTime.now());

                              return Container(
                                decoration: BoxDecoration(
                                  color: isFuture ? (_isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF1F5F9)) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.description.isNotEmpty ? tx.description : 'Unnamed Transaction',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 2,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(formattedDate, style: TextStyle(fontSize: 9, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                              Text('•', style: TextStyle(fontSize: 9, color: _isZaznamityMode ? Colors.white24 : const Color(0xFF94A3B8))),
                                              Text(tx.owner, style: TextStyle(fontSize: 9, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF4338CA), fontWeight: FontWeight.w500)),
                                              Text('•', style: TextStyle(fontSize: 9, color: _isZaznamityMode ? Colors.white24 : const Color(0xFF94A3B8))),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: _isZaznamityMode ? const Color(0xFF3F2F17) : const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  labelObj.name,
                                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFFCD34D) : const Color(0xFFD97706)),
                                                ),
                                              ),
                                              Text('•', style: TextStyle(fontSize: 9, color: _isZaznamityMode ? Colors.white24 : const Color(0xFF94A3B8))),
                                              Text('$flag $currencyCode', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          amountString,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isIncome ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isFuture ? 'SCHEDULED' : (isConfirmed ? 'CONFIRMED' : 'SCHEDULED'),
                                          style: TextStyle(
                                            fontSize: 7,
                                            fontWeight: FontWeight.bold,
                                            color: isFuture
                                                ? (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))
                                                : (isConfirmed ? const Color(0xFF34D399) : const Color(0xFFFCD34D)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    Wrap(
                                      spacing: 2,
                                      alignment: WrapAlignment.end,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        if (!isConfirmed)
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _isZaznamityMode ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                                              foregroundColor: _isZaznamityMode ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              minimumSize: Size.zero,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            ),
                                            onPressed: () => widget.onConfirmTransaction(tx),
                                            child: const Text('Confirm', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                          icon: Icon(Icons.edit, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                          tooltip: 'Edit',
                                          onPressed: () => widget.onEditTransaction(tx),
                                        ),
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                          icon: const Icon(Icons.delete, size: 14, color: Color(0xFFEF4444)),
                                          tooltip: 'Delete',
                                          onPressed: () => widget.onDeleteTransaction(tx.id!),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}