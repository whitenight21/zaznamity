// ignore_for_file: deprecated_member_use

import 'dart:convert';
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

  const WhatIfScenarioCard({
    super.key,
    required this.owners,
    this.selectedOwner,
    required this.transactions,
    required this.liabilities,
    required this.basePrognosis,
  });

  @override
  State<WhatIfScenarioCard> createState() => _WhatIfScenarioCardState();
}

class _WhatIfScenarioCardState extends State<WhatIfScenarioCard> {
  bool _isZaznamityMode = true;
  String _primaryCurrency = 'USD';
  bool _isCollapsed = false;

  // Simulation Levers
  double _incomeMultiplier = 1.0; // 0% to 150%
  double _expenseSqueezePercent = 0.0; // 0% to 50%
  double _lumpSumExpense = 0.0; // 0 to 2000
  double _extraDebtPayment = 0.0; // 0 to 1500 (Liability Impact)
  int _horizonDays = 30; // 30, 90, 180, 365

  // Custom Saved Presets
  List<Map<String, dynamic>> _customPresets = [];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final savedPresetsStr = prefs.getString('set_whatIf_custom_presets');
    
    List<Map<String, dynamic>> loadedPresets = [];
    if (savedPresetsStr != null) {
      try {
        final decoded = jsonDecode(savedPresetsStr) as List;
        loadedPresets = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';
        _isCollapsed = prefs.getBool('set_whatIf_collapsed') ?? false;
        _customPresets = loadedPresets;
      });
    }
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_whatIf_collapsed', _isCollapsed);
  }

  Future<void> _saveCustomPreset(String name) async {
    if (name.trim().isEmpty) return;
    final newPreset = {
      'name': name.trim(),
      'incomeMultiplier': _incomeMultiplier,
      'expenseSqueeze': _expenseSqueezePercent,
      'lumpSum': _lumpSumExpense,
      'extraDebt': _extraDebtPayment,
      'horizonDays': _horizonDays,
    };

    setState(() {
      _customPresets.add(newPreset);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('set_whatIf_custom_presets', jsonEncode(_customPresets));
  }

  Future<void> _deleteCustomPreset(int index) async {
    setState(() {
      _customPresets.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('set_whatIf_custom_presets', jsonEncode(_customPresets));
  }

  @override
  void didUpdateWidget(covariant WhatIfScenarioCard oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  void _resetScenario() {
    setState(() {
      _incomeMultiplier = 1.0;
      _expenseSqueezePercent = 0.0;
      _lumpSumExpense = 0.0;
      _extraDebtPayment = 0.0;
      _horizonDays = 30;
    });
  }

  Map<String, dynamic> _calculateSimulationResults() {
    final now = DateTime.now();
    final horizonEnd = now.add(Duration(days: _horizonDays));

    double baselineIncome = 0;
    double baselineExpense = 0;

    for (var tx in widget.transactions) {
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt != null && dt.isAfter(now) && dt.isBefore(horizonEnd)) {
        if (tx.type == 'income') {
          baselineIncome += tx.amount;
        } else if (tx.type == 'expense') {
          baselineExpense += tx.amount;
        }
      }
    }

    double totalLiabilityOutlays = 0;
    double monthsCount = _horizonDays / 30.0;
    for (var lib in widget.liabilities) {
      totalLiabilityOutlays += (lib.monthlyInstallment * monthsCount);
    }

    double simulatedIncome = baselineIncome * _incomeMultiplier;
    double simulatedExpense = (baselineExpense * (1.0 - (_expenseSqueezePercent / 100.0))) + _lumpSumExpense + totalLiabilityOutlays + (_extraDebtPayment * monthsCount);
    double simulatedNetShift = simulatedIncome - simulatedExpense;

    double startingBalance = widget.basePrognosis;
    double simulatedEndingBalance = startingBalance + simulatedNetShift;

    int estimatedRunwayDays = 999;
    if (simulatedNetShift < 0) {
      double dailyBurn = (-simulatedNetShift) / _horizonDays.toDouble();
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
    };
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))),
          ],
        ),
        content: Text(
          content,
          style: TextStyle(fontSize: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569), height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _promptSavePreset(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        title: Text('Save Custom Scenario', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Preset Name (e.g. Sabbatical Plan)',
            hintStyle: TextStyle(color: _isZaznamityMode ? Colors.white54 : Colors.grey),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA855F7), foregroundColor: Colors.white),
            onPressed: () {
              _saveCustomPreset(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _calculateSimulationResults();
    final double simulatedNetShift = results['simulatedNetShift'];
    final double endingBalance = results['simulatedEndingBalance'];
    final int runwayDays = results['estimatedRunwayDays'];

    double healthRatio = 1.0;
    if (runwayDays < 30) healthRatio = 0.15;
    else if (runwayDays < 90) healthRatio = 0.4;
    else if (runwayDays < 180) healthRatio = 0.7;
    
    Color healthColor = const Color(0xFF34D399);
    String healthLabel = 'Robust (> 6 Mos)';
    if (runwayDays < 30) {
      healthColor = const Color(0xFFF87171);
      healthLabel = 'Critical (< 30 Days)';
    } else if (runwayDays < 90) {
      healthColor = Colors.orangeAccent;
      healthLabel = 'Stressed (1-3 Mos)';
    } else if (runwayDays < 180) {
      healthColor = Colors.yellow;
      healthLabel = 'Resilient (3-6 Mos)';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
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
              // TITLE ROW: Title, Info Icon, Owner Badge, Collapse Button
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
                            'WHAT-IF LAB',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _showInfoDialog(
                            context,
                            'WHAT-IF LAB PREDICTIONS',
                            'The What-If Lab simulates how financial shocks, income adjustments, or debt accelerations might impact your future cash trajectory.\n\n• Basis: Projections are computed by extrapolating future scheduled Zaznams (transactions) and existing liabilities stored in your offline database.\n• Predictions vs. Certainty: These calculations represent simulated estimations and trend extrapolations, NOT guaranteed certainties. Real-world outcomes may differ due to unexpected expenses or variable earnings.\n• Disclaimer: This tool is for personal organizational tracking and self-analysis only. It does not constitute professional or expert financial advice.',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(Icons.info_outline_rounded, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
                          ),
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
                      const SizedBox(width: 4),
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

                // NEXT ROW UNDER BADGE: Reset Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _resetScenario,
                      icon: const Icon(Icons.restart_alt_rounded, size: 14),
                      label: const Text('Reset', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // NEXT ROW: Horizon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text('Horizon:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _showInfoDialog(
                            context,
                            'SIMULATION HORIZON',
                            'Selects the timeframe window (30 Days to 1 Year) over which your simulated income shifts, expense cuts, and debt payments are projected and compounded.',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
                          ),
                        ),
                      ],
                    ),
                    ToggleButtons(
                      isSelected: [_horizonDays == 30, _horizonDays == 90, _horizonDays == 180, _horizonDays == 365],
                      onPressed: (index) {
                        setState(() {
                          if (index == 0) _horizonDays = 30;
                          else if (index == 1) _horizonDays = 90;
                          else if (index == 2) _horizonDays = 180;
                          else if (index == 3) _horizonDays = 365;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      selectedColor: Colors.white,
                      fillColor: const Color(0xFFA855F7),
                      color: _isZaznamityMode ? Colors.white70 : Colors.black87,
                      constraints: const BoxConstraints(minHeight: 28, minWidth: 50),
                      children: const [
                        Text('30D', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('90D', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('6M', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('1Y', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

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
                          const Text('Resilience Health:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(healthLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: healthColor)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: healthRatio,
                          backgroundColor: _isZaznamityMode ? Colors.white24 : Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Simulated Net Shift (${_horizonDays}D):', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(
                            '${simulatedNetShift >= 0 ? '+' : ''}${_formatCurrency(simulatedNetShift)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: simulatedNetShift >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                            ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Presets & Saved:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    InkWell(
                      onTap: () => _promptSavePreset(context),
                      child: const Text('+ Save Current', style: TextStyle(fontSize: 11, color: Color(0xFFA855F7), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildPresetChip('Late Paycheck (-50% Inc.)', 0.5, 0.0, 0.0, 0.0, 30),
                    _buildPresetChip('Zero Income Break', 0.0, 0.0, 0.0, 0.0, 30),
                    _buildPresetChip('Emergency Bill (+500)', 1.0, 0.0, 500.0, 0.0, 30),
                    _buildPresetChip('Debt Acceleration (+300/mo)', 1.0, 0.0, 0.0, 300.0, 90),
                    for (int i = 0; i < _customPresets.length; i++)
                      _buildCustomPresetChip(_customPresets[i], i),
                  ],
                ),
                const SizedBox(height: 14),

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
                      // Slider 1: Income Multiplier
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text('Income Multiplier:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _showInfoDialog(
                                  context,
                                  'INCOME MULTIPLIER',
                                  'How to use: Slide to scale expected incoming earnings (0% to 150%).\n\nRelevance & Usefulness: Essential for simulating delayed paychecks, bonus cuts, salary raises, or sudden freelance income dry-spells to see how your runway holds up.',
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
                                ),
                              ),
                            ],
                          ),
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

                      // Slider 2: Expense Squeeze Cut
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text('Expense Squeeze Cut:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _showInfoDialog(
                                  context,
                                  'EXPENSE SQUEEZE CUT',
                                  'How to use: Slide to percentage-reduce variable spending (0% to 50%).\n\nRelevance & Usefulness: Helps you evaluate the protective buffer gained by tightening your belt and cutting discretionary spending during tight financial periods.',
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
                                ),
                              ),
                            ],
                          ),
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

                      // Slider 3: One-Time Shock Expense
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text('One-Time Shock Expense:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _showInfoDialog(
                                  context,
                                  'ONE-TIME SHOCK EXPENSE',
                                  'How to use: Slide to inject an unexpected cash outflow amount (e.g., car repairs, medical bills, appliance replacement).\n\nRelevance & Usefulness: Tests immediate liquidity stress to confirm whether your emergency savings can absorb sudden unexpected life events.',
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
                                ),
                              ),
                            ],
                          ),
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
                      const SizedBox(height: 4),

                      // Slider 4: Extra Debt Principal / Mo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text('Extra Debt Principal / Mo:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _showInfoDialog(
                                  context,
                                  'EXTRA DEBT PRINCIPAL / MO',
                                  'How to use: Slide to allocate extra monthly cash toward paying down liability principal.\n\nRelevance & Usefulness: Lets you weigh the trade-off between accelerated debt freedom versus keeping that cash liquid in your safety buffer.',
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
                                ),
                              ),
                            ],
                          ),
                          Text(_formatCurrency(_extraDebtPayment), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        ],
                      ),
                      Slider(
                        value: _extraDebtPayment,
                        min: 0.0,
                        max: 1000.0,
                        divisions: 20,
                        activeColor: Colors.blueAccent,
                        inactiveColor: _isZaznamityMode ? Colors.white24 : Colors.grey.shade300,
                        onChanged: (val) => setState(() => _extraDebtPayment = val),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetChip(String label, double incMul, double expSqz, double lump, double extraDebt, int horizon) {
    bool isSelected = _incomeMultiplier == incMul && _expenseSqueezePercent == expSqz && _lumpSumExpense == lump && _extraDebtPayment == extraDebt && _horizonDays == horizon;
    return InkWell(
      onTap: () {
        setState(() {
          _incomeMultiplier = incMul;
          _expenseSqueezePercent = expSqz;
          _lumpSumExpense = lump;
          _extraDebtPayment = extraDebt;
          _horizonDays = horizon;
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

  Widget _buildCustomPresetChip(Map<String, dynamic> preset, int index) {
    double inc = preset['incomeMultiplier'] ?? 1.0;
    double sqz = preset['expenseSqueeze'] ?? 0.0;
    double lump = preset['lumpSum'] ?? 0.0;
    double debt = preset['extraDebt'] ?? 0.0;
    int horiz = preset['horizonDays'] ?? 30;

    bool isSelected = _incomeMultiplier == inc && _expenseSqueezePercent == sqz && _lumpSumExpense == lump && _extraDebtPayment == debt && _horizonDays == horiz;

    return GestureDetector(
      onLongPress: () => _deleteCustomPreset(index),
      child: InkWell(
        onTap: () {
          setState(() {
            _incomeMultiplier = inc;
            _expenseSqueezePercent = sqz;
            _lumpSumExpense = lump;
            _extraDebtPayment = debt;
            _horizonDays = horiz;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFFA855F7) 
                : (_isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFA855F7) : (_isZaznamityMode ? Colors.white24 : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                preset['name'] ?? 'Custom',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155)),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _deleteCustomPreset(index),
                child: Icon(Icons.close, size: 10, color: isSelected ? Colors.white70 : Colors.redAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}