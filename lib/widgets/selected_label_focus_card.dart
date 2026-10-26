// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class SelectedLabelFocusCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? selectedOwner;
  final int? selectedLabelId;
  final Function(int?) onLabelChanged;
  final Function(String?) onOwnerChanged;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final VoidCallback onClearDateFilter;
  
  final bool isWide;
  final VoidCallback onToggleWidth;
  final VoidCallback onHide;
  final Function(int? labelId, String? owner, DateTime? start, DateTime? end)? onJumpToHistory;

  const SelectedLabelFocusCard({
    super.key,
    required this.transactions,
    required this.labels,
    required this.owners,
    this.startDate,
    this.endDate,
    this.selectedOwner,
    this.selectedLabelId,
    required this.onLabelChanged,
    required this.onOwnerChanged,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onClearDateFilter,
    required this.isWide,
    required this.onToggleWidth,
    required this.onHide,
    this.onJumpToHistory,
  });

  @override
  State<SelectedLabelFocusCard> createState() => _SelectedLabelFocusCardState();
}

class _SelectedLabelFocusCardState extends State<SelectedLabelFocusCard> {
  String _singleLabelDefaultRange = '';
  bool _isZaznamityMode = true;
  String _primaryCurrency = 'USD';
  final NumberFormat _currencyFormatter = NumberFormat('#,##0.00', 'en_US');
  final Map<String, bool> _multiLabelFixedCategories = {};

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    final fixedMap = <String, bool>{};
    for (var label in widget.labels) {
      fixedMap[label.name] = prefs.getBool('set_multilabel_fixed_${label.name}') ?? false;
    }

    setState(() {
      _singleLabelDefaultRange = prefs.getString('set_singleLabel_range') ?? '';
      final themeStr = prefs.getString('app_theme') ?? 'zaznamity';
      _isZaznamityMode = (themeStr == 'zaznamity');
      _primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';
      _multiLabelFixedCategories.addAll(fixedMap);
    });
  }

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      case 'CZK': return 'Kč';
      default: return '\$';
    }
  }

  String _formatAmount(double amount) {
    final symbol = _getCurrencySymbol(_primaryCurrency);
    return '$symbol${_currencyFormatter.format(amount)}';
  }

  bool _isFixedExpenseLabelByName(String labelName) {
    if (_multiLabelFixedCategories.containsKey(labelName)) {
      return _multiLabelFixedCategories[labelName] == true;
    }
    final lower = labelName.toLowerCase();
    return lower.contains('rent') ||
        lower.contains('housing') ||
        lower.contains('utility') ||
        lower.contains('utilities') ||
        lower.contains('insurance') ||
        lower.contains('loan') ||
        lower.contains('mortgage') ||
        lower.contains('bill');
  }

  DateTime? _getComputedStartDate() {
    if (widget.startDate != null) return widget.startDate!;
    if (_singleLabelDefaultRange.isEmpty) return null;
    final now = DateTime.now();
    switch (_singleLabelDefaultRange) {
      case '7 Days':
        return now.subtract(const Duration(days: 7));
      case '15 Days':
        return now.subtract(const Duration(days: 15));
      case '30 Days':
        return now.subtract(const Duration(days: 30));
      case 'Current Month':
        return DateTime(now.year, now.month, 1);
      default:
        return null;
    }
  }

  DateTime? _getComputedEndDate() {
    if (widget.endDate != null) return widget.endDate!;
    if (_getComputedStartDate() == null) return null;
    return DateTime.now();
  }

  void _showInfoModal(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))),
          ],
        ),
        content: Text(description, style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), height: 1.4)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA855F7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString('app_theme') ?? 'zaznamity';
      final zaznamityActive = (themeStr == 'zaznamity');
      final curr = prefs.getString('primaryCurrency') ?? 'USD';
      if ((zaznamityActive != _isZaznamityMode || curr != _primaryCurrency) && mounted) {
        setState(() {
          _isZaznamityMode = zaznamityActive;
          _primaryCurrency = curr;
        });
      }
    });

    final effectiveStartDate = _getComputedStartDate();
    final effectiveEndDate = _getComputedEndDate();

    final filteredTxs = widget.transactions.where((tx) {
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null) return true;
      
      if (effectiveStartDate != null) {
        final startClean = DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day);
        if (txDate.isBefore(startClean)) return false;
      }

      if (effectiveEndDate != null) {
        final endClean = DateTime(effectiveEndDate.year, effectiveEndDate.month, effectiveEndDate.day, 23, 59, 59);
        if (txDate.isAfter(endClean)) return false;
      }

      if (widget.selectedLabelId != null && tx.labelId != widget.selectedLabelId) return false;
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners' && tx.owner != widget.selectedOwner) return false;
      return true;
    }).toList();

    double inflow = 0;
    double outflow = 0;
    for (var tx in filteredTxs) {
      if (tx.isConfirmed == 1) {
        if (tx.type == 'income') {
          inflow += tx.amount;
        } else {
          outflow += tx.amount;
        }
      }
    }
    double net = inflow - outflow;

    final allCardFilteredTxs = widget.transactions.where((tx) {
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null) return true;
      
      if (effectiveStartDate != null) {
        final startClean = DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day);
        if (txDate.isBefore(startClean)) return false;
      }

      if (effectiveEndDate != null) {
        final endClean = DateTime(effectiveEndDate.year, effectiveEndDate.month, effectiveEndDate.day, 23, 59, 59);
        if (txDate.isAfter(endClean)) return false;
      }

      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners' && tx.owner != widget.selectedOwner) return false;
      return true;
    }).toList();

    double totalGlobalInflow = 0;
    double totalGlobalOutflow = 0;
    for (var tx in allCardFilteredTxs) {
      if (tx.isConfirmed == 1) {
        if (tx.type == 'income') {
          totalGlobalInflow += tx.amount;
        } else {
          totalGlobalOutflow += tx.amount;
        }
      }
    }

    double outflowPercentage = totalGlobalOutflow > 0 ? (outflow / totalGlobalOutflow) * 100 : 0.0;
    double inflowPercentage = totalGlobalInflow > 0 ? (inflow / totalGlobalInflow) * 100 : 0.0;

    // Projected Label Burn & Recurring Projection Calculation
    final now = DateTime.now();
    final currentMonthTxs = widget.transactions.where((tx) {
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null || tx.isConfirmed != 1) return false;
      if (txDate.year == now.year && txDate.month == now.month) {
        if (widget.selectedLabelId != null && tx.labelId != widget.selectedLabelId) return false;
        if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners' && tx.owner != widget.selectedOwner) return false;
        return true;
      }
      return false;
    }).toList();

    double currentMonthLabelOutflow = 0;
    for (var tx in currentMonthTxs) {
      if (tx.type == 'expense') currentMonthLabelOutflow += tx.amount;
    }

    // Global monthly total outflow for contribution share
    double globalCurrentMonthOutflow = 0;
    for (var tx in widget.transactions) {
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null || tx.isConfirmed != 1 || tx.type != 'expense') continue;
      if (txDate.year == now.year && txDate.month == now.month) {
        if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners' && tx.owner != widget.selectedOwner) continue;
        globalCurrentMonthOutflow += tx.amount;
      }
    }

    double labelBurnContributionShare = globalCurrentMonthOutflow > 0 ? (currentMonthLabelOutflow / globalCurrentMonthOutflow) * 100 : 0.0;

    int currentDay = now.day;
    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    double projectedMonthEndSpend = currentDay > 0 ? (currentMonthLabelOutflow / currentDay) * daysInMonth : currentMonthLabelOutflow;

    // Label name resolution & Fixed/Discretionary tag determination
    String selectedLabelName = 'Selected Label';
    if (widget.selectedLabelId != null) {
      final matchLbl = widget.labels.where((l) => l.id == widget.selectedLabelId).firstOrNull;
      if (matchLbl != null) selectedLabelName = matchLbl.name;
    }
    bool isFixedLabel = _isFixedExpenseLabelByName(selectedLabelName);

    // Analytics: Average Transaction Size & Frequency Metrics
    double avgTransactionSize = filteredTxs.isNotEmpty ? (inflow + outflow) / filteredTxs.length : 0.0;
    int durationDays = effectiveStartDate != null && effectiveEndDate != null 
        ? effectiveEndDate.difference(effectiveStartDate).inDays + 1 
        : 30;
    if (durationDays < 1) durationDays = 1;
    double frequencyPerWeek = (filteredTxs.length / durationDays) * 7;

    // Analytics: Top Spending/Income Contributors (Breakdown by Description)
    Map<String, double> descriptionTotals = {};
    for (var tx in filteredTxs) {
      if (tx.isConfirmed == 1 && tx.description.isNotEmpty) {
        descriptionTotals[tx.description] = (descriptionTotals[tx.description] ?? 0.0) + tx.amount;
      }
    }
    var topContributors = descriptionTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var top3Contributors = topContributors.take(3).toList();

    // Analytics: Period-over-Period (MoM) Trend Indicator
    double previousPeriodNet = 0.0;
    if (effectiveStartDate != null && effectiveEndDate != null) {
      final prevStart = effectiveStartDate.subtract(Duration(days: durationDays));
      final prevEnd = effectiveStartDate.subtract(const Duration(days: 1));
      
      for (var tx in widget.transactions) {
        final txDate = DateTime.tryParse(tx.createdAt);
        if (txDate == null) continue;
        if (txDate.isAfter(prevStart.subtract(const Duration(seconds: 1))) && txDate.isBefore(prevEnd.add(const Duration(days: 1)))) {
          if (widget.selectedLabelId != null && tx.labelId != widget.selectedLabelId) continue;
          if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners' && tx.owner != widget.selectedOwner) continue;
          if (tx.isConfirmed == 1) {
            previousPeriodNet += (tx.type == 'income' ? tx.amount : -tx.amount);
          }
        }
      }
    }
    double momDifference = previousPeriodNet != 0 ? ((net - previousPeriodNet) / previousPeriodNet.abs()) * 100 : 0.0;

    final bool hasDateFilter = effectiveStartDate != null || effectiveEndDate != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 48;
        final double boxWidth = (fullWidth - 12) / 2;

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
                        'LABEL ANALYSIS',
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
                              backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF1F5F9),
                              foregroundColor: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B),
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
                            backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF1F5F9),
                            foregroundColor: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B),
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
                        color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
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
                                value: widget.selectedOwner,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                isDense: true,
                                isExpanded: true,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                hint: Text('All Owners', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF94A3B8))),
                                items: [
                                  DropdownMenuItem<String?>(value: null, child: Text('All Owners', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  ...widget.owners.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
                                ],
                                onChanged: widget.onOwnerChanged,
                              ),
                            ),
                          ),
                        ],
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
                              color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.horizontal(
                                left: const Radius.circular(10),
                                right: hasDateFilter ? Radius.zero : const Radius.circular(10),
                              ),
                              border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onSelectStartDate,
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
                                          hasDateFilter
                                              ? '${effectiveStartDate != null ? DateFormat('MM/dd').format(effectiveStartDate) : '...'} - ${effectiveEndDate != null ? DateFormat('MM/dd').format(effectiveEndDate) : '...'}'
                                              : 'Select Date Range',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: hasDateFilter ? (_isZaznamityMode ? Colors.white : const Color(0xFF334155)) : (_isZaznamityMode ? Colors.white54 : const Color(0xFF94A3B8)),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _isZaznamityMode ? Colors.white38 : const Color(0xFF94A3B8)),
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
                              color: _isZaznamityMode ? const Color(0xFF3D256B) : const Color(0xFFE2E8F0),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                              border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onClearDateFilter,
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                child: const Center(
                                  child: Icon(Icons.clear, size: 14, color: Color(0xFFF87171)),
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
                        color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
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
                                value: widget.selectedLabelId,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                isDense: true,
                                isExpanded: true,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                hint: Text('All Labels', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF94A3B8))),
                                items: [
                                  DropdownMenuItem<int?>(value: null, child: Text('All Labels', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  ...widget.labels.map((l) => DropdownMenuItem<int?>(value: l.id, child: Text(l.name, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
                                ],
                                onChanged: widget.onLabelChanged,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: boxWidth,
                    child: InkWell(
                      onTap: () {
                        if (widget.onJumpToHistory != null) {
                          widget.onJumpToHistory!(
                            widget.selectedLabelId, 
                            (widget.selectedOwner == 'All Owners' ? null : widget.selectedOwner), 
                            effectiveStartDate, 
                            effectiveEndDate,
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Display below all',
                              style: TextStyle(
                                color: _isZaznamityMode ? const Color(0xFFC084FC) : const Color(0xFF582F95),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${filteredTxs.length} Zaznams',
                                  style: TextStyle(
                                    color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(Icons.arrow_forward_ios, size: 10, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'NET BALANCE',
                          style: TextStyle(
                            color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _showInfoModal(
                            context,
                            'Net Balance Mechanics',
                            'The net cash flow resulting from total inflows minus total outflows filtered for the selected single label and date range.',
                          ),
                          child: Icon(Icons.info_outline, size: 13, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatAmount(net),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('INFLOWS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), letterSpacing: 0.5)),
                          const SizedBox(width: 3),
                          InkWell(
                            onTap: () => _showInfoModal(
                              context,
                              'Inflows & Share',
                              'Total incoming transaction amounts associated with this label, accompanied by its percentage share of global inflows.',
                            ),
                            child: Icon(Icons.info_outline, size: 12, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('+${_formatAmount(inflow)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                      const SizedBox(height: 2),
                      Text('${inflowPercentage.toStringAsFixed(1)}% of total', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF64748B))),
                    ],
                  ),
                  Container(height: 35, width: 1, color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('OUTFLOWS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), letterSpacing: 0.5)),
                          const SizedBox(width: 3),
                          InkWell(
                            onTap: () => _showInfoModal(
                              context,
                              'Outflows & Share',
                              'Total outgoing spending associated with this label, alongside its percentage share of global portfolio outflows.',
                            ),
                            child: Icon(Icons.info_outline, size: 12, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('-${_formatAmount(outflow)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
                      const SizedBox(height: 2),
                      Text('${outflowPercentage.toStringAsFixed(1)}% of total', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 20),

              // NEW SECTION: Forecasted Label Burn & Recurring Projection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'LABEL BURN & FORECAST',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _showInfoModal(
                          context,
                          'Label Burn & Forecast',
                          'Projects expected total spend for the remainder of the month based on current day-to-day run-rate velocity.\n\n'
                          'Tag: Displays whether the label is classified as Fixed (mandatory overhead) or Discretionary (flexible spending).\n\n'
                          'Contribution: Shows what percentage this label contributes to your overall monthly outflow.',
                        ),
                        child: Icon(Icons.info_outline, size: 12, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isFixedLabel 
                          ? (_isZaznamityMode ? const Color(0xFF3B1E63) : const Color(0xFFE2E8F0))
                          : (_isZaznamityMode ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFDBEAFE)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isFixedLabel ? 'FIXED' : 'DISCRETIONARY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: isFixedLabel
                            ? (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))
                            : (_isZaznamityMode ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Projected Month-End', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(_formatAmount(projectedMonthEndSpend), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                      ],
                    ),
                    Container(height: 25, width: 1, color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                    Column(
                      children: [
                        Text('Burn Contribution', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text('${labelBurnContributionShare.toStringAsFixed(1)}% of burn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              
              // SECTION 1: Average Transaction Size & Frequency Metrics Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'TRANSACTION DYNAMICS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _showInfoModal(
                          context,
                          'Transaction Dynamics',
                          'Shows the average size per transaction and the frequency rate (transactions per week) over the selected date span.',
                        ),
                        child: Icon(Icons.info_outline, size: 12, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  Text(
                    'Count: ${filteredTxs.length}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Average Size', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(_formatAmount(avgTransactionSize), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                      ],
                    ),
                    Container(height: 25, width: 1, color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                    Column(
                      children: [
                        Text('Frequency Rate', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text('${frequencyPerWeek.toStringAsFixed(1)} / week', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // SECTION 2: Top Spending/Income Contributors Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'TOP CONTRIBUTORS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _showInfoModal(
                          context,
                          'Top Contributors',
                          'Aggregates and highlights the top 3 description drivers ranked by total amount within this label.',
                        ),
                        child: Icon(Icons.info_outline, size: 12, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                ),
                child: top3Contributors.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Center(
                          child: Text('No transactions recorded', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: _isZaznamityMode ? Colors.white38 : const Color(0xFF94A3B8))),
                        ),
                      )
                    : Column(
                        children: top3Contributors.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatAmount(entry.value),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),

              const SizedBox(height: 14),

              // SECTION 3: Period-over-Period (MoM) Trend Indicator Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'PERIOD TREND (MoM)',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _showInfoModal(
                          context,
                          'Period-over-Period Trend',
                          'Compares net cash flow of the current selected date range against the exact preceding timeframe span.',
                        ),
                        child: Icon(Icons.info_outline, size: 12, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Previous Period Net:', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B))),
                    Row(
                      children: [
                        Text(
                          _formatAmount(previousPeriodNet),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: momDifference >= 0 ? const Color(0xFF34D399).withValues(alpha: 0.2) : const Color(0xFFF87171).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${momDifference >= 0 ? '▲ +' : '▼ '}${momDifference.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: momDifference >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                            ),
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
}