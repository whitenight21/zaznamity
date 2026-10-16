// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TransferFundsCard extends StatefulWidget {
  final List<String> pools;
  final List<String> owners;
  final String? selectedGlobalOwner;
  final Function(
    String fromPool,
    String toPool,
    String fromOwner,
    String toOwner,
    double amount,
    String description,
    DateTime date,
    String fromCurrency,
    String toCurrency,
    double exchangeRate,
  ) onTransfer;
  final VoidCallback? onHide;
  final VoidCallback? onToggleWidth;
  final bool isWide;

  const TransferFundsCard({
    super.key,
    required this.pools,
    required this.owners,
    this.selectedGlobalOwner,
    required this.onTransfer,
    this.onHide,
    this.onToggleWidth,
    this.isWide = false,
  });

  @override
  State<TransferFundsCard> createState() => _TransferFundsCardState();
}

class _TransferFundsCardState extends State<TransferFundsCard> {
  late String _fromPool;
  late String _toPool;
  late String _fromOwner;
  late String _toOwner;
  
  String _fromCurrency = 'USD';
  String _toCurrency = 'USD';
  List<String> _availableCurrencies = ['USD'];
  
  final _amountController = TextEditingController();
  final _rateController = TextEditingController(text: '1.0');
  final _feeController = TextEditingController(text: '0.0');
  final _descController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  double _enteredAmount = 0.0;
  double _transferFee = 0.0;
  double _exchangeRate = 1.0;
  bool _isFetchingRate = false;
  String _rateTimestamp = 'Just now';

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

  @override
  void initState() {
    super.initState();
    _fromPool = widget.pools.isNotEmpty ? widget.pools.first : 'checking';
    _toPool = widget.pools.length > 1 ? widget.pools[1] : _fromPool;
    
    final initialOwner = _resolveOwner();
    _fromOwner = initialOwner;
    _toOwner = initialOwner;
    _loadCurrencyPrefs();

    _amountController.addListener(_updateCalculations);
    _feeController.addListener(_updateCalculations);
    _rateController.addListener(_updateCalculations);
  }

  void _updateCalculations() {
    setState(() {
      _enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
      _transferFee = double.tryParse(_feeController.text) ?? 0.0;
      _exchangeRate = double.tryParse(_rateController.text) ?? 1.0;
    });
  }

  Future<void> _loadCurrencyPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final primary = prefs.getString('primaryCurrency') ?? 'USD';
    final sec1 = prefs.getString('secondaryCurrency1');
    final sec2 = prefs.getString('secondaryCurrency2');
    final sec3 = prefs.getString('secondaryCurrency3');

    List<String> currencies = [primary];
    if (sec1 != null) currencies.add(sec1);
    if (sec2 != null) currencies.add(sec2);
    if (sec3 != null) currencies.add(sec3);

    setState(() {
      _availableCurrencies = currencies;
      _fromCurrency = primary;
      _toCurrency = primary;
    });
    _fetchExchangeRate(primary, primary);
  }

  Future<void> _fetchExchangeRate(String from, String to) async {
    final now = DateTime.now();
    final formattedDate = '${DateFormat('MMM d').format(now)}, ${DateFormat('HH:mm').format(now)}';

    if (from == to) {
      setState(() {
        _exchangeRate = 1.0;
        _rateController.text = '1.0';
        _rateTimestamp = formattedDate;
      });
      return;
    }

    setState(() => _isFetchingRate = true);

    double? rate;
    try {
      final response = await http.get(
        Uri.parse('https://api.exchangerate-api.com/v4/latest/$from'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>?;
        if (rates != null && rates[to] != null) {
          rate = (rates[to] as num).toDouble();
        }
      }
    } catch (_) {}

    if (rate == null) {
      rate = _getOfflineFallbackRate(from, to);
    }

    if (mounted) {
      setState(() {
        _exchangeRate = rate ?? 1.0;
        _rateController.text = _exchangeRate.toStringAsFixed(4);
        _isFetchingRate = false;
        _rateTimestamp = formattedDate;
      });
    }
  }

  double _getOfflineFallbackRate(String from, String to) {
    const Map<String, double> ratesToUSD = {
      'USD': 1.0,
      'EUR': 0.92,
      'GBP': 0.79,
      'JPY': 150.5,
      'CAD': 1.36,
      'AUD': 1.52,
      'CHF': 0.89,
      'CNY': 7.23,
      'HKD': 7.82,
      'SGD': 1.35,
    };

    final double toUSDFrom = ratesToUSD[from.toUpperCase()] ?? 1.0;
    final double toUSDTo = ratesToUSD[to.toUpperCase()] ?? 1.0;

    return toUSDTo / toUSDFrom;
  }

  String _resolveOwner() {
    if (widget.selectedGlobalOwner != null && widget.owners.contains(widget.selectedGlobalOwner)) {
      return widget.selectedGlobalOwner!;
    }
    return widget.owners.isNotEmpty ? widget.owners.first : 'Mathias';
  }

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      default: return '\$';
    }
  }

  @override
  void didUpdateWidget(covariant TransferFundsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pools.isNotEmpty) {
      if (!widget.pools.contains(_fromPool)) _fromPool = widget.pools.first;
      if (!widget.pools.contains(_toPool)) _toPool = widget.pools.first;
    }

    if (widget.selectedGlobalOwner != oldWidget.selectedGlobalOwner || widget.owners != oldWidget.owners) {
      setState(() {
        final syncedOwner = _resolveOwner();
        _fromOwner = syncedOwner;
        _toOwner = syncedOwner;
      });
    }

    if (widget.owners.isNotEmpty) {
      if (!widget.owners.contains(_fromOwner)) _fromOwner = widget.owners.first;
      if (!widget.owners.contains(_toOwner)) _toOwner = widget.owners.first;
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateCalculations);
    _feeController.removeListener(_updateCalculations);
    _rateController.removeListener(_updateCalculations);
    _amountController.dispose();
    _rateController.dispose();
    _feeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double netSourceAmount = (_enteredAmount - _transferFee).clamp(0.0, double.infinity);
    final double netDestinationAmount = netSourceAmount * _exchangeRate;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 48;
        final double boxWidth = (fullWidth - 36) / 2;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
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
                      child: const Text(
                        'TRANSFER FUNDS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF582F95),
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
                                backgroundColor: const Color(0xFFF1F5F9),
                                foregroundColor: const Color(0xFF64748B),
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
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF64748B),
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
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF582F95)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                DateFormat('MM/dd/yyyy').format(_selectedDate),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
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
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF582F95)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _selectedTime.format(context),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
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

              // Headers for Owners
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: boxWidth,
                    child: const Text('FROM OWNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 36),
                  SizedBox(
                    width: boxWidth,
                    child: const Text('TO OWNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Row 2: Owners with single arrow icon in center
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: boxWidth,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _fromOwner,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                items: widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                                onChanged: (val) => setState(() => _fromOwner = val ?? widget.owners.first),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 36, child: Center(child: Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF582F95)))),
                  SizedBox(
                    width: boxWidth,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _toOwner,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                items: widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                                onChanged: (val) => setState(() => _toOwner = val ?? widget.owners.first),
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

              // Row 3: Currencies placed directly under Owners
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: boxWidth,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Text(_currencyFlags[_fromCurrency] ?? '💵', style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _fromCurrency,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                items: _availableCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _fromCurrency = val);
                                    _fetchExchangeRate(_fromCurrency, _toCurrency);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 36, child: Center(child: Icon(Icons.currency_exchange, size: 18, color: Color(0xFF582F95)))),
                  SizedBox(
                    width: boxWidth,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Text(_currencyFlags[_toCurrency] ?? '💵', style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _toCurrency,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                items: _availableCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _toCurrency = val);
                                    _fetchExchangeRate(_fromCurrency, _toCurrency);
                                  }
                                },
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

              // Row 4: Pools with single arrow icon in center
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: boxWidth,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.layers_outlined, size: 16, color: Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _fromPool,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                items: widget.pools.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
                                onChanged: (val) => setState(() => _fromPool = val ?? widget.pools.first),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 36, child: Center(child: Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF582F95)))),
                  SizedBox(
                    width: boxWidth,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.layers_outlined, size: 16, color: Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _toPool,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                items: widget.pools.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
                                onChanged: (val) => setState(() => _toPool = val ?? widget.pools.first),
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

              // Row 5: Transfer Fee, Exchange Rate, and Net Preview
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _feeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Transfer Fee',
                        labelStyle: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        hintText: '0.00',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _rateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: _isFetchingRate ? 'Fetching rate...' : 'Exchange Rate',
                        labelStyle: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        counterText: 'As of: $_rateTimestamp',
                        counterStyle: const TextStyle(fontSize: 7.5, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'NET PREVIEW',
                        labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_getCurrencySymbol(_toCurrency)}${netDestinationAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 6: Amount & Description
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '0.00 (${_getCurrencySymbol(_fromCurrency)})',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: TextField(
                      controller: _descController,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Description',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Row 7: Transfer Funds Action Button with white transfer symbols
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF582F95),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final amount = double.tryParse(_amountController.text) ?? 0.0;
                    final rate = double.tryParse(_rateController.text) ?? 1.0;
                    if (amount <= 0) return;
                    
                    final fullDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                      _selectedTime.hour,
                      _selectedTime.minute,
                    );
                    
                    widget.onTransfer(
                      _fromPool,
                      _toPool,
                      _fromOwner,
                      _toOwner,
                      amount,
                      _descController.text,
                      fullDate,
                      _fromCurrency,
                      _toCurrency,
                      rate,
                    );
                    
                    _amountController.clear();
                    _feeController.text = '0.0';
                    _descController.clear();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.swap_horiz, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(' Transfer Funds ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                      SizedBox(width: 6),
                      Icon(Icons.swap_horiz, size: 18, color: Colors.white),
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
}