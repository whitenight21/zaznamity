// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/liability_model.dart';

class WhatIfScenarioCard extends StatefulWidget {
  final List<String> owners;
  final String? selectedOwner;
  final List<TransactionModel> transactions;
  final List<LiabilityModel> liabilities;
  final double basePrognosis;

  final bool isWide;
  final VoidCallback? onToggleWidth;
  final VoidCallback? onHide;

  const WhatIfScenarioCard({
    super.key,
    required this.owners,
    this.selectedOwner,
    required this.transactions,
    required this.liabilities,
    required this.basePrognosis,
    this.isWide = false,
    this.onToggleWidth,
    this.onHide,
  });

  @override
  State<WhatIfScenarioCard> createState() => _WhatIfScenarioCardState();
}

class _WhatIfScenarioCardState extends State<WhatIfScenarioCard> {
  late String _selectedOwner;
  bool _isZaznamityMode = true;
  String _primaryCurrency = 'USD';

  // Simulation Sliders / Levers
  double _incomeMultiplier = 1.0; // 0.0 to 1.5 (e.g., 0% to 150% of expected income)
  double _expenseSqueezePercent = 0.0; // 0% to 50% reduction in variable expenses
  double _lumpSumExpense = 0.0; // One-time unexpected expense injection (€/$)

  @override
  void initState() {
    super.initState();
    _selectedOwner = widget.selectedOwner ?? 'All Owners';
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD'; // Fixed bracket typo here
      });
    }
  }

  @override
  void didUpdateWidget(covariant WhatIfScenarioCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOwner != oldWidget.selectedOwner) {
      setState(() {
        _selectedOwner = widget.selectedOwner ?? 'All Owners';
      });
    }
    _loadPrefs();
  }

  String _getCurrencySymbol() {
    switch (_primaryCurrency.toUpperCase()) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      case 'CNY': return '¥';
      case 'AUD': return 'A\$';
      case 'CAD': return 'C\$';
      case 'CHF': return 'CHF ';
      case 'HKD': return 'HK\$';
      case 'SGD': return 'S\$';
      default: return '\$';
    }
  }

  String _formatCurrency(double amount) {
    final symbol = _getCurrencySymbol();
    final format = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return format.format(amount);
  }

  // Reset simulation levers
  void _resetScenario() {
    setState(() {
      _incomeMultiplier = 1.0;
      _expenseSqueezePercent = 0.0;
      _lumpSumExpense = 0.0;
    });
  }

  // Compute simulation outcomes dynamically
  Map<String, dynamic> _calculateSimulationResults() {
    final now = DateTime.now();
    final next30Days = now.add(const Duration(days: 30));

    double baseline30DayIncome = 0;
    double baseline30DayExpense = 0;

    for (var tx in widget.transactions) {
      if (_selectedOwner != 'All Owners' && tx.owner != _selectedOwner) continue;
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt != null && dt.isAfter(now) && dt.isBefore(next30Days)) {
        if (tx.type == 'income') {
          baseline30DayIncome += tx.amount;
        } else if (tx.type == 'expense') {
          baseline30DayExpense += tx.amount;
        }
      }
    }

    // Apply simulation modifiers
    double simulatedIncome = baseline30DayIncome * _incomeMultiplier;
    double simulatedExpense = (baseline30DayExpense * (1.0 - (_expenseSqueezePercent / 100.0))) + _lumpSumExpense;
    double simulatedNetShift = simulatedIncome - simulatedExpense;

    // Projected Liquid Balance after simulation
    double startingBalance = widget.basePrognosis;
    double simulatedEndingBalance = startingBalance + simulatedNetShift;

    // Runway depletion check under simulation
    int estimatedRunwayDays = 999;
    if (simulatedNetShift < 0) {
      double dailyBurn = (-simulatedNetShift) / 30.0;
      if (dailyBurn > 0 && startingBalance > 0) {
        estimatedRunwayDays = (startingBalance / dailyBurn).floor();
      } else {
        estimatedRunwayDays = 0;
      }
    }

    return {
      'simulatedIncome': simulatedIncome,
      'simulatedExpense': simulatedExpense,
      'simulatedNetShift': simulatedNetShift,
      'simulatedEndingBalance': simulatedEndingBalance,
      'estimatedRunwayDays': estimatedRunwayDays,
      'netShiftDelta': simulatedNetShift - (baseline30DayIncome - baseline30DayExpense),
    };
  }

  @override
  Widget build(BuildContext context) {
    final results = _calculateSimulationResults();
    final double simulatedNetShift = results['simulatedNetShift'];
    final double endingBalance = results['simulatedEndingBalance'];
    final int runwayDays = results['estimatedRunwayDays'];
    final double netShiftDelta = results['netShiftDelta'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 32;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: _isZaznamityMode
              ? BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.5),
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'WHAT-IF LAB',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reset Button
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        onPressed: _resetScenario,
                        icon: const Icon(Icons.restart_alt_rounded, size: 14),
                        label: const Text('Reset', style: TextStyle(fontSize: 11)),
                      ),
                      if (widget.onToggleWidth != null)
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
                            onPressed: widget.onToggleWidth,
                            icon: Icon(
                              widget.isWide ? Icons.fullscreen_exit : Icons.fullscreen,
                              size: 16,
                            ),
                            tooltip: widget.isWide ? 'Narrow' : 'Wide',
                          ),
                        ),
                      if (widget.onHide != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
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
                              onPressed: widget.onHide,
                              icon: const Icon(Icons.visibility_off_outlined, size: 14),
                              tooltip: 'Hide',
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Owner Filter Dropdown
              Container(
                height: 40,
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
                          value: _selectedOwner,
                          isDense: true,
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                          items: [
                            DropdownMenuItem(value: 'All Owners', child: Text('All Owners', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                            ...widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedOwner = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Preset Quick-Action Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildPresetChip('Late Paycheck (-50% Inc.)', 0.5, 0.0, 0.0),
                  _buildPresetChip('Zero Income Break', 0.0, 0.0, 0.0),
                  _buildPresetChip('Emergency Bill (+500)', 1.0, 0.0, 500.0),
                  _buildPresetChip('Budget Squeeze (20% Cut)', 1.0, 20.0, 0.0),
                ],
              ),
              const SizedBox(height: 14),

              // Simulation Sliders Box
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
                    // Slider 1: Income Shock / Multiplier
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Income Multiplier:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                        Text('${(_incomeMultiplier * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA855F7))),
                      ],
                    ),
                    Slider(
                      value: _incomeMultiplier,
                      min: 0.0,
                      max: 1.5,
                      divisions: 15,
                      activeColor: const Color(0xFFA855F7),
                      inactiveColor: _isZaznamityMode ? Colors.white24 : Colors.grey.shade300,
                      onChanged: (val) => setState(() => _incomeMultiplier = val),
                    ),
                    const SizedBox(height: 4),

                    // Slider 2: Expense Squeeze %
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Expense Squeeze Cut:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                        Text('${_expenseSqueezePercent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                      ],
                    ),
                    Slider(
                      value: _expenseSqueezePercent,
                      min: 0.0,
                      max: 50.0,
                      divisions: 10,
                      activeColor: const Color(0xFF34D399),
                      inactiveColor: _isZaznamityMode ? Colors.white24 : Colors.grey.shade300,
                      onChanged: (val) => setState(() => _expenseSqueezePercent = val),
                    ),
                    const SizedBox(height: 4),

                    // Slider 3: Unexpected Lump Sum Expense
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('One-Time Shock Expense:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                        Text(_formatCurrency(_lumpSumExpense), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
                      ],
                    ),
                    Slider(
                      value: _lumpSumExpense,
                      min: 0.0,
                      max: 2000.0,
                      divisions: 20,
                      activeColor: const Color(0xFFF87171),
                      inactiveColor: _isZaznamityMode ? Colors.white24 : Colors.grey.shade300,
                      onChanged: (val) => setState(() => _lumpSumExpense = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Output Results Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: endingBalance < 0 
                      ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) 
                      : (_isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: endingBalance < 0 ? const Color(0xFFF87171) : (_isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Simulated 30-Day Net Shift:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Text(
                              '${simulatedNetShift >= 0 ? '+' : ''}${_formatCurrency(simulatedNetShift)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: simulatedNetShift >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                              ),
                            ),
                            if (netShiftDelta != 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${netShiftDelta >= 0 ? '+' : ''}${_formatCurrency(netShiftDelta)})',
                                style: TextStyle(fontSize: 9.5, color: netShiftDelta >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Projected Ending Balance:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        Text(
                          _formatCurrency(endingBalance),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: endingBalance >= 0 ? (_isZaznamityMode ? Colors.white : Colors.black87) : const Color(0xFFF87171),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimated Runway:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        Text(
                          runwayDays >= 999 ? 'Stable (> 1 Year)' : '$runwayDays Days',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: runwayDays > 60 ? const Color(0xFF34D399) : (runwayDays > 30 ? Colors.orangeAccent : const Color(0xFFF87171)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetChip(String label, double incMul, double expSqz, double lump) {
    bool isSelected = _incomeMultiplier == incMul && _expenseSqueezePercent == expSqz && _lumpSumExpense == lump;
    return InkWell(
      onTap: () {
        setState(() {
          _incomeMultiplier = incMul;
          _expenseSqueezePercent = expSqz;
          _lumpSumExpense = lump;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFA855F7) 
              : (_isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFA855F7) : (_isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}