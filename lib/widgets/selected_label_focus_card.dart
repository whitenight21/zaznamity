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

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _singleLabelDefaultRange = prefs.getString('set_singleLabel_range') ?? '';
      final themeStr = prefs.getString('app_theme') ?? 'zaznamity';
      _isZaznamityMode = (themeStr == 'zaznamity');
    });
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
      if (zaznamityActive != _isZaznamityMode && mounted) {
        setState(() {
          _isZaznamityMode = zaznamityActive;
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

    final sortedFilteredTxs = List<TransactionModel>.from(filteredTxs)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a.createdAt) ?? DateTime(0);
        final dateB = DateTime.tryParse(b.createdAt) ?? DateTime(0);
        return dateB.compareTo(dateA);
      });
    final recentTransactions = sortedFilteredTxs.take(5).toList();

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
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF3B1E63),
                      Color(0xFF160D25),
                      Color(0xFF000000),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
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
                        'SINGLE-LABEL ANALYSIS',
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
                      '\$${net.toStringAsFixed(2)}',
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
                      Text('+\$${inflow.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
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
                      Text('-\$${outflow.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
                      const SizedBox(height: 2),
                      Text('${outflowPercentage.toStringAsFixed(1)}% of total', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              if (recentTransactions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'LAST 5 ZAZNAMS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B), letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: ListView.builder(
                    cacheExtent: 1000,
                    itemCount: recentTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = recentTransactions[index];
                      final txDate = DateTime.tryParse(tx.createdAt);
                      final formattedTxDate = txDate != null ? DateFormat('MM/dd').format(txDate) : '';
                      final isIncome = tx.type == 'income';
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    formattedTxDate,
                                    style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      tx.description.isNotEmpty ? tx.description : 'No description',
                                      style: TextStyle(fontSize: 12, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${isIncome ? '+' : '-'}\$${tx.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isIncome ? const Color(0xFF34D399) : const Color(0xFFF87171),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}