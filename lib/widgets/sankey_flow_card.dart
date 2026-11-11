// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';
import '../services/privacy_service.dart';
import '../widgets/masked_amount.dart';

class SankeyFlowCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
  final String? selectedOwner;
  final List<String> pools;
  final String? selectedPool;
  final Function(String?)? onPoolChanged;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime?, DateTime?)? onDateRangeChanged;
  final ValueChanged<String?> onOwnerChanged;
  final VoidCallback onClearDateFilter;

  const SankeyFlowCard({
    super.key,
    required this.transactions,
    required this.labels,
    required this.owners,
    this.selectedOwner,
    required this.pools,
    this.selectedPool,
    this.onPoolChanged,
    this.startDate,
    this.endDate,
    this.onDateRangeChanged,
    required this.onOwnerChanged,
    required this.onClearDateFilter,
  });

  @override
  State<SankeyFlowCard> createState() => _SankeyFlowCardState();
}

class _SankeyFlowCardState extends State<SankeyFlowCard> with WidgetsBindingObserver {
  String _flowMode = 'Expenses';
  String _dateRangeSetting = 'Current Month'; // Default changed to Current Month
  bool _isZaznamityMode = true;
  bool _isCollapsed = false;
  String? _isolatedNode; // Interactive Node Isolation state
  String _primaryCurrency = 'USD';

  // Cache for 2-tier
  List<MapEntry<String, double>> _cachedSortedSources = [];
  List<MapEntry<String, double>> _cachedSortedTargets = [];
  List _cachedFlows = [];

  double _cachedDynamicHeight = 408.0;
  String _lastDataCacheKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPrefs();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final setting = prefs.getString('set_sankey_range') ?? 'Current Month';
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final collapsed = prefs.getBool('set_sankeyFlow_collapsed') ?? false;
    final primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';
    final newZaznamityMode = (savedTheme == 'zaznamity');

    if (mounted) {
      if (_isZaznamityMode != newZaznamityMode ||
          _dateRangeSetting != setting ||
          _isCollapsed != collapsed ||
          _primaryCurrency != primaryCurrency) {
        setState(() {
          _dateRangeSetting = setting;
          _isZaznamityMode = newZaznamityMode;
          _isCollapsed = collapsed;
          _primaryCurrency = primaryCurrency;
        });
      }
    }
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_sankeyFlow_collapsed', _isCollapsed);
  }

  bool _isTransferTransaction(TransactionModel tx) {
    final desc = tx.description.toLowerCase();
    final pool = tx.pool.toLowerCase();
    final labelObj = widget.labels.firstWhere(
      (l) => l.id == tx.labelId,
      orElse: () => LabelModel(id: 0, name: '', color: ''),
    );
    final labelName = labelObj.name.toLowerCase();
    
    return desc.contains('transfer to') ||
           desc.contains('transfer from') ||
           desc.contains('transfer fee') ||
           desc.contains('goal contribution') ||
           desc.contains('withdrawal from') ||
           desc.contains('deposit into') ||
           pool.contains('transfer') ||
           pool.contains('goal') ||
           labelName.contains('transfer') ||
           tx.labelId == -999;
  }

  String _formatAmount(double amount) {
    final symbol = _getCurrencySymbol(_primaryCurrency).trim();
    const trailingSymbols = ['€', 'Ft', 'Kč', 'zł', 'CHF'];
    bool isTrailing = trailingSymbols.any((s) => symbol.toLowerCase() == s.toLowerCase());

    final formattedNumber = NumberFormat('#,##0.00', 'en_US').format(amount);

    if (isTrailing) {
      return '$formattedNumber $symbol';
    } else {
      return '$symbol$formattedNumber';
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
      case 'MXN': return 'MX\$';
      case 'CLP': return 'CLP\$';
      case 'COP': return 'COL\$';
      default: return '\$';
    }
  }

  String _computeCacheKey(List<TransactionModel> txs) {
    final txHash = txs.fold<int>(0, (acc, tx) => acc ^ tx.id.hashCode ^ tx.amount.hashCode ^ tx.isConfirmed.hashCode);
    final labelHash = widget.labels.fold<int>(0, (acc, l) => acc ^ l.id.hashCode ^ l.name.hashCode);
    return '${txs.length}-${widget.selectedOwner}-${widget.selectedPool}-${widget.startDate}-${widget.endDate}-$_dateRangeSetting-$_flowMode-$_primaryCurrency-$labelHash-$txHash';
  }

  List<MapEntry<String, double>> _applyTopNGroups(Map<String, double> totals, int maxItems) {
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.length <= maxItems) return sorted;

    final top = sorted.take(maxItems - 1).toList();
    final others = sorted.skip(maxItems - 1);
    double otherSum = others.fold(0.0, (sum, e) => sum + e.value);

    top.add(MapEntry('Other', otherSum));
    return top;
  }

  void _computeDataIfNeeded() {
    final currentKey = _computeCacheKey(widget.transactions);
    if (currentKey == _lastDataCacheKey) return;
    _lastDataCacheKey = currentKey;

    final now = DateTime.now();
    DateTime? effectiveStart = widget.startDate;
    DateTime? effectiveEnd = widget.endDate;

    if (effectiveStart == null && effectiveEnd == null) {
      if (_dateRangeSetting == 'Current Month') {
        effectiveStart = DateTime(now.year, now.month, 1);
      } else if (_dateRangeSetting == '90 Days') {
        effectiveStart = now.subtract(const Duration(days: 90));
      } else {
        effectiveStart = now.subtract(const Duration(days: 30));
      }
    }

    final filteredTransactions = widget.transactions.where((tx) {
      if (tx.isConfirmed != 1) return false;
      if (_isTransferTransaction(tx)) return false;
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && tx.owner != widget.selectedOwner) {
        return false;
      }
      if (widget.selectedPool != null && widget.selectedPool!.isNotEmpty) {
        if (tx.pool.toLowerCase() != widget.selectedPool!.toLowerCase()) {
          return false;
        }
      }
      final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
      if (effectiveStart != null && txDate.isBefore(effectiveStart)) {
        return false;
      }
      if (effectiveEnd != null) {
        final endOfDay = DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day, 23, 59, 59);
        if (txDate.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();

    final Map<String, double> sourceTotals = {};
    final Map<String, double> targetTotals = {};
    final List flows = [];

    for (var tx in filteredTransactions) {
      if (_flowMode == 'Expenses' && tx.type == 'expense') {
        final labelObj = widget.labels.firstWhere(
          (l) => l.id == tx.labelId,
          orElse: () => LabelModel(id: 0, name: 'General', color: '#4338CA'),
        );
        final source = tx.pool.isNotEmpty ? tx.pool.toUpperCase() : 'CHECKING';
        final target = labelObj.name;

        sourceTotals[source] = (sourceTotals[source] ?? 0) + tx.amount;
        targetTotals[target] = (targetTotals[target] ?? 0) + tx.amount;
        flows.add({'source': source, 'target': target, 'amount': tx.amount});
      } else if (_flowMode == 'Income' && tx.type == 'income') {
        final labelObj = widget.labels.firstWhere(
          (l) => l.id == tx.labelId,
          orElse: () => LabelModel(id: 0, name: 'General', color: '#4338CA'),
        );
        final source = tx.owner.isNotEmpty ? tx.owner : 'INCOME';
        final target = labelObj.name;

        sourceTotals[source] = (sourceTotals[source] ?? 0) + tx.amount;
        targetTotals[target] = (targetTotals[target] ?? 0) + tx.amount;
        flows.add({'source': source, 'target': target, 'amount': tx.amount});
      }
    }

    final sortedSources = _applyTopNGroups(sourceTotals, 6);
    final sortedTargets = _applyTopNGroups(targetTotals, 8);

    int maxItems = sortedSources.length > sortedTargets.length ? sortedSources.length : sortedTargets.length;
    double dynamicHeight = (maxItems * 74.8 + 85.0).clamp(408.0, double.infinity);

    _cachedSortedSources = sortedSources;
    _cachedSortedTargets = sortedTargets;
    _cachedFlows = flows;
    _cachedDynamicHeight = dynamicHeight;
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: (widget.startDate != null && widget.endDate != null)
          ? DateTimeRange(start: widget.startDate!, end: widget.endDate!)
          : null,
      builder: (context, child) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 1.0,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: child!,
              ),
            ),
          ),
        );
      },
    );

    if (picked != null && widget.onDateRangeChanged != null) {
      widget.onDateRangeChanged!(picked.start, picked.end);
    }
  }

  void _showDrillDownModal(String nodeName) {
    final now = DateTime.now();
    DateTime? effectiveStart = widget.startDate;
    DateTime? effectiveEnd = widget.endDate;

    if (effectiveStart == null && effectiveEnd == null) {
      if (_dateRangeSetting == 'Current Month') {
        effectiveStart = DateTime(now.year, now.month, 1);
      } else if (_dateRangeSetting == '90 Days') {
        effectiveStart = now.subtract(const Duration(days: 90));
      } else {
        effectiveStart = now.subtract(const Duration(days: 30));
      }
    }

    final matchedTxs = widget.transactions.where((tx) {
      if (tx.isConfirmed != 1) return false;
      if (_isTransferTransaction(tx)) return false;

      final labelObj = widget.labels.firstWhere(
        (l) => l.id == tx.labelId,
        orElse: () => LabelModel(id: 0, name: 'General', color: '#4338CA'),
      );
      final poolStr = tx.pool.isNotEmpty ? tx.pool.toUpperCase() : 'CHECKING';
      final ownerStr = tx.owner.isNotEmpty ? tx.owner : 'OWNER';

      bool matchesNode = (poolStr == nodeName || ownerStr == nodeName || labelObj.name == nodeName);
      if (!matchesNode) return false;

      final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
      if (effectiveStart != null && txDate.isBefore(effectiveStart)) return false;
      if (effectiveEnd != null) {
        final endOfDay = DateTime(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day, 23, 59, 59);
        if (txDate.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Zaznams for "$nodeName"',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: _isZaznamityMode ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: matchedTxs.isEmpty
                    ? Center(
                        child: Text('No transactions found for this node.', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey)),
                      )
                    : ListView.builder(
                        itemCount: matchedTxs.length,
                        itemBuilder: (context, index) {
                          final tx = matchedTxs[index];
                          final labelObj = widget.labels.firstWhere(
                            (l) => l.id == tx.labelId,
                            orElse: () => LabelModel(id: 0, name: 'General', color: '#4338CA'),
                          );
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFA855F7).withValues(alpha: 0.2),
                              child: Icon(tx.type == 'expense' ? Icons.arrow_downward : Icons.arrow_upward, color: const Color(0xFFA855F7), size: 16),
                            ),
                            title: Text(tx.description.isNotEmpty ? tx.description : labelObj.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                            subtitle: Text('${tx.owner} • ${tx.pool.toUpperCase()} • ${tx.createdAt.substring(0, 10)}', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade600)),
                            trailing: MaskedAmount(
                              formattedAmount: '${tx.type == 'expense' ? '-' : '+'}${_formatAmount(tx.amount)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: tx.type == 'expense' ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                              ),
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

  void _showInfoDialog(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))),
          ],
        ),
        content: Text(description, style: TextStyle(fontSize: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155), height: 1.4)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
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
    _computeDataIfNeeded();

    final bool hasDateFilter = widget.startDate != null || widget.endDate != null;

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
                            'SANKEY FLOW TREND ',
                            style: TextStyle(
                              fontSize: 16,
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
                            'Sankey Flow Trend',
                            'This card visualizes by color the flow of money between your financial pools and category labels over a selected date range.\n\n'
                            '• Visualize money flows across 2-tier stages.\n'
                            '• Toggle between pools and flows to analyze your financial trends.\n',
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: boxWidth,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _flowMode = 'Expenses';
                                    _isolatedNode = null;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _flowMode == 'Expenses'
                                        ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Expense',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _flowMode == 'Expenses'
                                          ? Colors.white
                                          : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _flowMode = 'Income';
                                    _isolatedNode = null;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _flowMode == 'Income'
                                        ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Income',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _flowMode == 'Income'
                                          ? Colors.white
                                          : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                    ),
                                  ),
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
                                  onTap: () => _pickDateRange(context),
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
                                                ? '${DateFormat('MM/dd').format(widget.startDate!)} - ${DateFormat('MM/dd').format(widget.endDate!)}'
                                                : 'Select Date Range',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: hasDateFilter
                                                  ? (_isZaznamityMode ? Colors.white : const Color(0xFF1E293B))
                                                  : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                              fontWeight: hasDateFilter ? FontWeight.bold : FontWeight.normal,
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
                                  onTap: widget.onClearDateFilter,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: fullWidth,
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
                            Icon(Icons.account_balance_wallet_outlined, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: widget.selectedPool,
                                  isDense: true,
                                  isExpanded: true,
                                  dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                  hint: Text('All Pools', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('All Pools', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                    ),
                                    ...widget.pools.map(
                                      (pool) => DropdownMenuItem<String?>(
                                        value: pool,
                                        child: Text(pool.toUpperCase(), style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                      ),
                                    ),
                                  ],
                                  onChanged: widget.onPoolChanged,
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

                if (_isolatedNode != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA855F7)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: 'Selected:  ',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFA855F7)),
                            children: [
                              TextSpan(
                                text: _isolatedNode,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), // Label font is white
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _showDrillDownModal(_isolatedNode!),
                              child: const Text(
                                'View Zaznams',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, decoration: TextDecoration.underline),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => setState(() => _isolatedNode = null),
                              child: const Text(
                                'CLEAR',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red), // Underline removed
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                _cachedSortedSources.isEmpty || _cachedSortedTargets.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'No transaction flows match current filters.',
                            style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12),
                          ),
                        ),
                      )
                    : RepaintBoundary(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFE2E8F0)),
                          ),
                          child: SizedBox(
                            height: _cachedDynamicHeight,
                            child: ValueListenableBuilder<bool>(
                              valueListenable: PrivacyService.instance.isPrivacyModeEnabled,
                              builder: (context, isPrivate, child) {
                                return GestureDetector(
                                  onTapDown: (details) {
                                    final localPos = details.localPosition;
                                    final tappedNode = SankeyDiagramPainter.hitTestNode(
                                      localPos,
                                      Size(fullWidth, _cachedDynamicHeight),
                                      _cachedSortedSources,
                                      _cachedSortedTargets,
                                    );
                                    if (tappedNode != null) {
                                      setState(() {
                                        if (_isolatedNode == tappedNode) {
                                          _showDrillDownModal(tappedNode);
                                        } else {
                                          _isolatedNode = tappedNode;
                                        }
                                      });
                                    }
                                  },
                                  child: CustomPaint(
                                    size: Size(double.infinity, _cachedDynamicHeight),
                                    painter: SankeyDiagramPainter(
                                      sources: _cachedSortedSources,
                                      targets: _cachedSortedTargets,
                                      flows: _cachedFlows,
                                      formatCurrency: _formatAmount,
                                      isZaznamityMode: _isZaznamityMode,
                                      isolatedNode: _isolatedNode,
                                      isPrivate: isPrivate,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
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

class SankeyDiagramPainter extends CustomPainter {
  final List<MapEntry<String, double>> sources;
  final List<MapEntry<String, double>> targets;
  final List flows;
  final String Function(double) formatCurrency;
  final bool isZaznamityMode;
  final String? isolatedNode;
  final bool isPrivate;

  static final Map<String, Rect> _lastNodeRects = {};

  SankeyDiagramPainter({
    required this.sources,
    required this.targets,
    required this.flows,
    required this.formatCurrency,
    required this.isZaznamityMode,
    this.isolatedNode,
    required this.isPrivate,
  });

  static String? hitTestNode(Offset pos, Size size, List<MapEntry<String, double>> leftList, List<MapEntry<String, double>> rightList) {
    for (var entry in _lastNodeRects.entries) {
      final hitRect = entry.value.inflate(22.0);
      if (hitRect.contains(pos)) return entry.key;
    }
    return null;
  }

  static const List<Color> _lightPalette = [
    Color(0xFF2563EB),
    Color(0xFFDC2626),
    Color(0xFF16A34A),
    Color(0xFFD97706),
    Color(0xFF9333EA),
    Color(0xFF0D9488),
    Color(0xFFDB2777),
    Color(0xFF4F46E5),
  ];

  Color _getSourceNodeColor(String key, int index) {
    if (isZaznamityMode) {
      return const Color(0xFFA855F7);
    }
    return _lightPalette[index % _lightPalette.length];
  }

  Color _getTargetNodeColor(String tgtKey, int defaultIndex) {
    int targetIdx = targets.indexWhere((e) => e.key == tgtKey);
    if (targetIdx < 0) targetIdx = defaultIndex;

    if (isZaznamityMode) {
      const List<Color> ribbonColors = [
        Color(0xFF2563EB),
        Color(0xFFDC2626),
        Color(0xFF16A34A),
        Color(0xFFD97706),
        Color(0xFF9333EA),
        Color(0xFF0D9488),
        Color(0xFFDB2777),
        Color(0xFF4F46E5),
      ];
      Color baseRibbonColor = ribbonColors[targetIdx % ribboncolorsLength(ribbonColors.length)];
      // Return a darker shade of the ribbon line color
      return HSLColor.fromColor(baseRibbonColor).withLightness((HSLColor.fromColor(baseRibbonColor).lightness - 0.2).clamp(0.0, 1.0)).toColor();
    } else {
      Color baseColor = _lightPalette[targetIdx % _lightPalette.length];
      return HSLColor.fromColor(baseColor).withLightness((HSLColor.fromColor(baseColor).lightness - 0.2).clamp(0.0, 1.0)).toColor();
    }
  }

  int ribboncolorsLength(int len) => len;

  Color _getPathColor(String tgtKey, int defaultIndex, bool isConnected) {
    if (!isConnected) {
      return isZaznamityMode ? Colors.white10 : Colors.black12;
    }

    int targetIdx = targets.indexWhere((e) => e.key == tgtKey);
    if (targetIdx < 0) targetIdx = defaultIndex;

    if (isZaznamityMode) {
      if (isolatedNode != null) {
        return const Color(0xFFA855F7).withValues(alpha: 0.7);
      }
      const List<Color> ribbonColors = [
        Color(0xFF2563EB),
        Color(0xFFDC2626),
        Color(0xFF16A34A),
        Color(0xFFD97706),
        Color(0xFF9333EA),
        Color(0xFF0D9488),
        Color(0xFFDB2777),
        Color(0xFF4F46E5),
      ];
      return ribbonColors[targetIdx % ribbonColors.length].withValues(alpha: 0.3);
    } else {
      Color targetNodeColor = _lightPalette[targetIdx % _lightPalette.length];
      return targetNodeColor.withValues(alpha: isolatedNode != null ? 0.6 : 0.25);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _lastNodeRects.clear();
    final paintRibbon = Paint()..style = PaintingStyle.fill;
    final paintNode = Paint()..style = PaintingStyle.fill;

    double totalSourceVal = sources.fold(0.0, (sum, e) => sum + e.value);
    double totalTargetVal = targets.fold(0.0, (sum, e) => sum + e.value);
    if (totalSourceVal <= 0 || totalTargetVal <= 0) return;

    double nodeWidth = 6.0;
    double leftX = 0.0;
    double rightX = size.width - nodeWidth;
    
    double topPadding = 12.0;
    double bottomPadding = 12.0 + (targets.length * 5.0);
    double usableHeight = size.height - (topPadding + bottomPadding);

    Map<String, Rect> sourceRects = {};
    int srcCount = sources.length;
    double sourceGap = srcCount > 1 ? (usableHeight * 0.04 / (srcCount - 1)).clamp(2.0, 6.0) : 0.0;
    double totalSourceGaps = (srcCount > 1) ? (srcCount - 1) * sourceGap : 0.0;
    
    double maxAllowedSourceNodeSize = usableHeight * 0.45;
    double availableSourceHeight = (usableHeight - totalSourceGaps).clamp(srcCount * 14.0, usableHeight);

    double currentSourceY = topPadding;
    for (var src in sources) {
      double proportionHeight = (src.value / totalSourceVal) * availableSourceHeight;
      if (proportionHeight > maxAllowedSourceNodeSize) proportionHeight = maxAllowedSourceNodeSize;
      double nodeHeight = proportionHeight < 14.0 ? 14.0 : proportionHeight;
      
      sourceRects[src.key] = Rect.fromLTWH(leftX, currentSourceY, nodeWidth, nodeHeight);
      _lastNodeRects[src.key] = sourceRects[src.key]!;
      currentSourceY += nodeHeight + sourceGap;
    }

    Map<String, Rect> targetRects = {};
    int tgtCount = targets.length;
    double targetGap = tgtCount > 1 ? (usableHeight * 0.04 / (tgtCount - 1)).clamp(2.0, 6.0) : 0.0;
    double totalTargetGaps = (tgtCount > 1) ? (tgtCount - 1) * targetGap : 0.0;
    
    double maxAllowedTargetNodeSize = usableHeight * 0.35;
    double availableTargetHeight = (usableHeight - totalTargetGaps).clamp(tgtCount * 14.0, usableHeight);

    double currentTargetY = topPadding;
    for (var tgt in targets) {
      double proportionHeight = (tgt.value / totalTargetVal) * availableTargetHeight;
      if (proportionHeight > maxAllowedTargetNodeSize) proportionHeight = maxAllowedTargetNodeSize;
      double nodeHeight = proportionHeight < 14.0 ? 14.0 : proportionHeight;

      targetRects[tgt.key] = Rect.fromLTWH(rightX, currentTargetY, nodeWidth, nodeHeight);
      _lastNodeRects[tgt.key] = targetRects[tgt.key]!;
      currentTargetY += nodeHeight + targetGap;
    }

    Map<String, double> sourceOffsets = {for (var s in sources) s.key: sourceRects[s.key]!.top};
    Map<String, double> targetOffsets = {for (var t in targets) t.key: targetRects[t.key]!.top};

    int colorIdx = 0;
    for (var flow in flows) {
      String srcKey = flow['source'];
      String tgtKey = flow['target'];
      double amount = flow['amount'];

      Rect? sRect = sourceRects[srcKey];
      Rect? tRect = targetRects[tgtKey];
      if (sRect == null || tRect == null) continue;

      double srcTotal = sources.firstWhere((s) => s.key == srcKey, orElse: () => MapEntry(srcKey, 1.0)).value;
      double tgtTotal = targets.firstWhere((t) => t.key == tgtKey, orElse: () => MapEntry(tgtKey, 1.0)).value;

      double sH = (amount / srcTotal) * sRect.height;
      double tgtH = (amount / tgtTotal) * tRect.height;

      double sTop = sourceOffsets[srcKey]!;
      double tTop = targetOffsets[tgtKey]!;

      sourceOffsets[srcKey] = sTop + sH;
      targetOffsets[tgtKey] = tTop + tgtH;

      bool isConnected = isolatedNode == null || isolatedNode == srcKey || isolatedNode == tgtKey;
      Color ribbonColor = _getPathColor(tgtKey, colorIdx, isConnected);

      Path path = Path();
      path.moveTo(sRect.right, sTop);
      path.cubicTo((sRect.right + tRect.left) / 2, sTop, (sRect.right + tRect.left) / 2, tTop, tRect.left, tTop);
      path.lineTo(tRect.left, tTop + tgtH);
      path.cubicTo((sRect.right + tRect.left) / 2, tTop + tgtH, (sRect.right + tRect.left) / 2, sTop + sH, sRect.right, sTop + sH);
      path.close();

      paintRibbon.color = ribbonColor;
      canvas.drawPath(path, paintRibbon);
      colorIdx++;
    }

    int srcIdx = 0;
    for (var entry in sourceRects.entries) {
      bool isSelected = isolatedNode == null || isolatedNode == entry.key;
      Color nodeColor = _getSourceNodeColor(entry.key, srcIdx);
      paintNode.color = isSelected ? nodeColor : (isZaznamityMode ? Colors.white24 : Colors.grey.shade400);
      canvas.drawRRect(RRect.fromRectAndRadius(entry.value, const Radius.circular(2)), paintNode);

      double val = sources.firstWhere((s) => s.key == entry.key, orElse: () => MapEntry(entry.key, 0.0)).value;
      double pct = totalSourceVal > 0 ? (val / totalSourceVal) * 100 : 0;
      final amountText = isPrivate ? '••••••' : formatCurrency(val);
      TextPainter tp = TextPainter(
        text: TextSpan(
          text: '${entry.key} - $amountText (${pct.toStringAsFixed(0)}%)',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isSelected ? (isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155)) : (isZaznamityMode ? Colors.white38 : Colors.grey.shade500),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.left,
      );
      tp.layout();
      tp.paint(canvas, Offset(entry.value.right + 6, entry.value.top + (entry.value.height / 2) - 8));
      srcIdx++;
    }

    int tgtIdx = 0;
    for (var entry in targetRects.entries) {
      bool isSelected = isolatedNode == null || isolatedNode == entry.key;
      Color nodeColor = _getTargetNodeColor(entry.key, tgtIdx); // Darker shade of line/flow color
      paintNode.color = isSelected ? nodeColor : (isZaznamityMode ? Colors.white24 : Colors.grey.shade400);
      canvas.drawRRect(RRect.fromRectAndRadius(entry.value, const Radius.circular(2)), paintNode);

      double val = targets.firstWhere((t) => t.key == entry.key, orElse: () => MapEntry(entry.key, 0.0)).value;
      double pct = totalTargetVal > 0 ? (val / totalTargetVal) * 100 : 0;
      final amountText = isPrivate ? '••••••' : formatCurrency(val);
      TextPainter tp = TextPainter(
        text: TextSpan(
          text: '${entry.key} - $amountText (${pct.toStringAsFixed(0)}%)',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isSelected ? (isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155)) : (isZaznamityMode ? Colors.white38 : Colors.grey.shade500),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.right,
      );
      tp.layout();
      tp.paint(canvas, Offset(entry.value.left - tp.width - 6, entry.value.top + (entry.value.height / 2) - 8));
      tgtIdx++;
    }
  }

  @override
  bool shouldRepaint(covariant SankeyDiagramPainter oldDelegate) {
    return oldDelegate.isolatedNode != isolatedNode ||
        oldDelegate.sources != sources ||
        oldDelegate.targets != targets ||
        oldDelegate.isZaznamityMode != isZaznamityMode ||
        oldDelegate.isPrivate != isPrivate;
  }
}