// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

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
  String _tierMode = '2-tier'; // '2-tier' or '3-tier'
  String _dateRangeSetting = '30 Days';
  bool _isZaznamityMode = true;
  bool _isCollapsed = false;
  String? _isolatedNode; // Interactive Node Isolation state

  // Cache for 2-tier
  List<MapEntry<String, double>> _cachedSortedSources = [];
  List<MapEntry<String, double>> _cachedSortedTargets = [];
  List<Map<String, dynamic>> _cachedFlows = [];

  // Cache for 3-tier
  List<MapEntry<String, double>> _cachedTier1 = [];
  List<MapEntry<String, double>> _cachedTier2 = [];
  List<MapEntry<String, double>> _cachedTier3 = [];
  List<Map<String, dynamic>> _cachedFlowsA = []; // Tier 1 -> Tier 2
  List<Map<String, dynamic>> _cachedFlowsB = []; // Tier 2 -> Tier 3

  double _cachedDynamicHeight = 510.0;

  int? _lastTxLength;
  String? _lastOwner;
  String? _lastPool;
  DateTime? _lastStartDate;
  DateTime? _lastEndDate;
  String? _lastFlowMode;
  String? _lastTierMode;

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
    final setting = prefs.getString('set_sankey_range') ?? '30 Days';
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final collapsed = prefs.getBool('set_sankeyFlow_collapsed') ?? false;
    final tier = prefs.getString('set_sankey_tier') ?? '2-tier';
    final newZaznamityMode = (savedTheme == 'zaznamity');

    if (mounted) {
      if (_isZaznamityMode != newZaznamityMode ||
          _dateRangeSetting != setting ||
          _isCollapsed != collapsed ||
          _tierMode != tier) {
        setState(() {
          _dateRangeSetting = setting;
          _isZaznamityMode = newZaznamityMode;
          _isCollapsed = collapsed;
          _tierMode = tier;
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

  Future<void> _setTierMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tierMode = mode;
      _isolatedNode = null;
    });
    await prefs.setString('set_sankey_tier', mode);
  }

  void _computeDataIfNeeded() {
    _loadPrefs(); // Poll prefs dynamically on rebuild to instantly react to global theme switches across all cards

    if (_lastTxLength == widget.transactions.length &&
        _lastOwner == widget.selectedOwner &&
        _lastPool == widget.selectedPool &&
        _lastStartDate == widget.startDate &&
        _lastEndDate == widget.endDate &&
        _lastFlowMode == _flowMode &&
        _lastTierMode == _tierMode) {
      return;
    }

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
        final endOfDay = DateTime(
          effectiveEnd.year,
          effectiveEnd.month,
          effectiveEnd.day,
          23,
          59,
          59,
        );
        if (txDate.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();

    if (_tierMode == '2-tier') {
      final Map<String, double> sourceTotals = {};
      final Map<String, double> targetTotals = {};
      final List<Map<String, dynamic>> flows = [];

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

      final sortedSources = sourceTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final sortedTargets = targetTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      int maxItems = sortedSources.length > sortedTargets.length ? sortedSources.length : sortedTargets.length;
      
      double dynamicHeight = (maxItems * 74.8 + 85.0);
      if (dynamicHeight < 408.0) dynamicHeight = 408.0;

      _cachedSortedSources = sortedSources;
      _cachedSortedTargets = sortedTargets;
      _cachedFlows = flows;
      _cachedDynamicHeight = dynamicHeight;
    } else {
      final Map<String, double> t1Totals = {};
      final Map<String, double> t2Totals = {};
      final Map<String, double> t3Totals = {};
      final List<Map<String, dynamic>> flowsA = [];
      final List<Map<String, dynamic>> flowsB = [];

      for (var tx in filteredTransactions) {
        if (_flowMode == 'Expenses' && tx.type == 'expense') {
          final labelObj = widget.labels.firstWhere(
            (l) => l.id == tx.labelId,
            orElse: () => LabelModel(id: 0, name: 'General', color: '#4338CA'),
          );
          final t1 = tx.owner.isNotEmpty ? tx.owner : 'OWNER';
          final t2 = tx.pool.isNotEmpty ? tx.pool.toUpperCase() : 'CHECKING';
          final t3 = labelObj.name;

          t1Totals[t1] = (t1Totals[t1] ?? 0) + tx.amount;
          t2Totals[t2] = (t2Totals[t2] ?? 0) + tx.amount;
          t3Totals[t3] = (t3Totals[t3] ?? 0) + tx.amount;

          flowsA.add({'source': t1, 'target': t2, 'amount': tx.amount});
          flowsB.add({'source': t2, 'target': t3, 'amount': tx.amount});
        } else if (_flowMode == 'Income' && tx.type == 'income') {
          final labelObj = widget.labels.firstWhere(
            (l) => l.id == tx.labelId,
            orElse: () => LabelModel(id: 0, name: 'General', color: '#4338CA'),
          );
          final t1 = labelObj.name;
          final t2 = tx.pool.isNotEmpty ? tx.pool.toUpperCase() : 'CHECKING';
          final t3 = tx.owner.isNotEmpty ? tx.owner : 'INCOME';

          t1Totals[t1] = (t1Totals[t1] ?? 0) + tx.amount;
          t2Totals[t2] = (t2Totals[t2] ?? 0) + tx.amount;
          t3Totals[t3] = (t3Totals[t3] ?? 0) + tx.amount;

          flowsA.add({'source': t1, 'target': t2, 'amount': tx.amount});
          flowsB.add({'source': t2, 'target': t3, 'amount': tx.amount});
        }
      }

      final sortedT1 = t1Totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final sortedT2 = t2Totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final sortedT3 = t3Totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      int maxItems = [sortedT1.length, sortedT2.length, sortedT3.length].reduce((a, b) => a > b ? a : b);
      
      double dynamicHeight = (maxItems * 74.8 + 85.0);
      if (dynamicHeight < 442.0) dynamicHeight = 442.0;

      _cachedTier1 = sortedT1;
      _cachedTier2 = sortedT2;
      _cachedTier3 = sortedT3;
      _cachedFlowsA = flowsA;
      _cachedFlowsB = flowsB;
      _cachedDynamicHeight = dynamicHeight;
    }

    _lastTxLength = widget.transactions.length;
    _lastOwner = widget.selectedOwner;
    _lastPool = widget.selectedPool;
    _lastStartDate = widget.startDate;
    _lastEndDate = widget.endDate;
    _lastFlowMode = _flowMode;
    _lastTierMode = _tierMode;
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
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
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
      if (_flowMode == 'Expenses' && tx.type != 'expense') return false;
      if (_flowMode == 'Income' && tx.type != 'income') return false;

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
                            trailing: Text(
                              '${tx.type == 'expense' ? '-' : '+'}${currencyFormat.format(tx.amount)}',
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

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
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
                            'SANKEY FLOW TREND',
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
                            'Sankey Flow Guide',
                            'Visualize money flows across the 2-tier or 3-tier lifecycle stages.\n\n• Percentage Share Badges: Displays % contribution next to each node.\n• View Zaznams: Tap any node to inspect those exact filtered Zaznams.',
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
                // Row 1: Flow Switch [Expense] [Income] & Date Range Picker
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
                // Row 2: Tier Switcher [2-tier] [3-tier] & Pool Dropdown
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
                                onTap: () => _setTierMode('2-tier'),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _tierMode == '2-tier'
                                        ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '2-tier',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _tierMode == '2-tier'
                                          ? Colors.white
                                          : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _setTierMode('3-tier'),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _tierMode == '3-tier'
                                        ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '3-tier',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _tierMode == '3-tier'
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
                        Text(
                          'Selected Node:  $_isolatedNode',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFA855F7)),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _showDrillDownModal(_isolatedNode!),
                              child: const Text(
                                'View Zaznams',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, decoration: TextDecoration.underline),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => setState(() => _isolatedNode = null),
                              child: const Text(
                                'CLEAR',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                (_tierMode == '2-tier' && (_cachedSortedSources.isEmpty || _cachedSortedTargets.isEmpty)) ||
                        (_tierMode == '3-tier' && (_cachedTier1.isEmpty || _cachedTier2.isEmpty || _cachedTier3.isEmpty))
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
                            child: GestureDetector(
                              onTapDown: (details) {
                                final localPos = details.localPosition;
                                final tappedNode = SankeyDiagramPainter.hitTestNode(
                                  localPos,
                                  Size(fullWidth, _cachedDynamicHeight),
                                  _tierMode == '2-tier' ? _cachedSortedSources : _cachedTier1,
                                  _tierMode == '2-tier' ? _cachedSortedTargets : _cachedTier3,
                                  middleNodes: _tierMode == '3-tier' ? _cachedTier2 : null,
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
                                  tierMode: _tierMode,
                                  sources: _cachedSortedSources,
                                  targets: _cachedSortedTargets,
                                  tier1: _cachedTier1,
                                  tier2: _cachedTier2,
                                  tier3: _cachedTier3,
                                  flows: _cachedFlows,
                                  flowsA: _cachedFlowsA,
                                  flowsB: _cachedFlowsB,
                                  currencyFormat: currencyFormat,
                                  isZaznamityMode: _isZaznamityMode,
                                  isolatedNode: _isolatedNode,
                                ),
                              ),
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
  final String tierMode;
  final List<MapEntry<String, double>> sources;
  final List<MapEntry<String, double>> targets;
  final List<MapEntry<String, double>> tier1;
  final List<MapEntry<String, double>> tier2;
  final List<MapEntry<String, double>> tier3;
  final List<Map<String, dynamic>> flows;
  final List<Map<String, dynamic>> flowsA;
  final List<Map<String, dynamic>> flowsB;
  final NumberFormat currencyFormat;
  final bool isZaznamityMode;
  final String? isolatedNode;

  static final Map<String, Rect> _lastNodeRects = {};

  SankeyDiagramPainter({
    required this.tierMode,
    required this.sources,
    required this.targets,
    required this.tier1,
    required this.tier2,
    required this.tier3,
    required this.flows,
    required this.flowsA,
    required this.flowsB,
    required this.currencyFormat,
    required this.isZaznamityMode,
    this.isolatedNode,
  });

  static String? hitTestNode(Offset pos, Size size, List<MapEntry<String, double>> leftList, List<MapEntry<String, double>> rightList, {List<MapEntry<String, double>>? middleNodes}) {
    for (var entry in _lastNodeRects.entries) {
      final hitRect = entry.value.inflate(22.0);
      if (hitRect.contains(pos)) return entry.key;
    }
    return null;
  }

  // Colorful palette for light (non-zaznamity) mode
  static const List<Color> _lightPalette = [
    Color(0xFF2563EB), // Blue
    Color(0xFFDC2626), // Red
    Color(0xFF16A34A), // Green
    Color(0xFFD97706), // Amber
    Color(0xFF9333EA), // Purple
    Color(0xFF0D9488), // Teal
    Color(0xFFDB2777), // Pink
    Color(0xFF4F46E5), // Indigo
  ];

  Color _getNodeColor(String key, int index, bool isSource) {
    if (isZaznamityMode) {
      return isSource ? const Color(0xFFA855F7) : const Color(0xFF7C3AED);
    }
    return _lightPalette[index % _lightPalette.length];
  }

  Color _getPathColor(String tgtKey, List<MapEntry<String, double>> targetList, int defaultIndex, bool isConnected) {
    if (!isConnected) {
      return isZaznamityMode ? Colors.white10 : Colors.black12;
    }

    // Find index of target node to match its exact color palette
    int targetIdx = targetList.indexWhere((e) => e.key == tgtKey);
    if (targetIdx < 0) targetIdx = defaultIndex;

    if (isZaznamityMode) {
      if (isolatedNode != null) {
        return const Color(0xFFA855F7).withValues(alpha: 0.7);
      }
      const List<Color> ribbonColors = [
        Color(0xFFA855F7),
        Color(0xFFC4B5FD),
        Color(0xFF7C3AED),
        Color(0xFF9333EA),
      ];
      return ribbonColors[targetIdx % ribbonColors.length].withValues(alpha: 0.3);
    } else {
      // Use exact color of the target category node with a feint alpha (0.25)
      Color targetNodeColor = _lightPalette[targetIdx % _lightPalette.length];
      return targetNodeColor.withValues(alpha: isolatedNode != null ? 0.6 : 0.25);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _lastNodeRects.clear();
    final paintRibbon = Paint()..style = PaintingStyle.fill;
    final paintNode = Paint()..style = PaintingStyle.fill;

    if (tierMode == '2-tier') {
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

        double srcH = (amount / sources.firstWhere((s) => s.key == srcKey).value) * sRect.height;
        double tgtH = (amount / targets.firstWhere((t) => t.key == tgtKey).value) * tRect.height;

        double sTop = sourceOffsets[srcKey]!;
        double tTop = targetOffsets[tgtKey]!;

        sourceOffsets[srcKey] = sTop + srcH;
        targetOffsets[tgtKey] = tTop + tgtH;

        bool isConnected = isolatedNode == null || isolatedNode == srcKey || isolatedNode == tgtKey;
        // Path color matches the target category node color
        Color ribbonColor = _getPathColor(tgtKey, targets, colorIdx, isConnected);

        Path path = Path();
        path.moveTo(sRect.right, sTop);
        path.cubicTo((sRect.right + tRect.left) / 2, sTop, (sRect.right + tRect.left) / 2, tTop, tRect.left, tTop);
        path.lineTo(tRect.left, tTop + tgtH);
        path.cubicTo((sRect.right + tRect.left) / 2, tTop + tgtH, (sRect.right + tRect.left) / 2, sTop + srcH, sRect.right, sTop + srcH);
        path.close();

        paintRibbon.color = ribbonColor;
        canvas.drawPath(path, paintRibbon);
        colorIdx++;
      }

      // Pools (sources)
      int srcIdx = 0;
      for (var entry in sourceRects.entries) {
        bool isSelected = isolatedNode == null || isolatedNode == entry.key;
        Color nodeColor = _getNodeColor(entry.key, srcIdx, true);
        paintNode.color = isSelected ? nodeColor : (isZaznamityMode ? Colors.white24 : Colors.grey.shade400);
        canvas.drawRRect(RRect.fromRectAndRadius(entry.value, const Radius.circular(2)), paintNode);

        double val = sources.firstWhere((s) => s.key == entry.key).value;
        double pct = (val / totalSourceVal) * 100;
        TextPainter tp = TextPainter(
          text: TextSpan(
            text: '${entry.key} - ${currencyFormat.format(val)} (${pct.toStringAsFixed(0)}%)',
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

      // Labels (targets)
      int tgtIdx = 0;
      for (var entry in targetRects.entries) {
        bool isSelected = isolatedNode == null || isolatedNode == entry.key;
        Color nodeColor = _getNodeColor(entry.key, tgtIdx, false);
        paintNode.color = isSelected ? nodeColor : (isZaznamityMode ? Colors.white24 : Colors.grey.shade400);
        canvas.drawRRect(RRect.fromRectAndRadius(entry.value, const Radius.circular(2)), paintNode);

        double val = targets.firstWhere((t) => t.key == entry.key).value;
        double pct = (val / totalTargetVal) * 100;
        TextPainter tp = TextPainter(
          text: TextSpan(
            text: '${entry.key} - ${currencyFormat.format(val)} (${pct.toStringAsFixed(0)}%)',
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
    } else {
      // 3-tier view
      double totalT1 = tier1.fold(0.0, (sum, e) => sum + e.value);
      double totalT2 = tier2.fold(0.0, (sum, e) => sum + e.value);
      double totalT3 = tier3.fold(0.0, (sum, e) => sum + e.value);
      if (totalT1 <= 0 || totalT2 <= 0 || totalT3 <= 0) return;

      double nodeWidth = 6.0;
      double col1X = 0.0;
      double col2X = size.width / 2 - nodeWidth / 2;
      double col3X = size.width - nodeWidth;
      
      double topPadding = 12.0;
      double bottomPadding = 12.0 + (tier3.length * 5.0);
      double usableHeight = size.height - (topPadding + bottomPadding);

      Map<String, Rect> t1Rects = {};
      double currentY1 = topPadding;
      for (var item in tier1) {
        double h = (item.value / totalT1) * (usableHeight - tier1.length * 4);
        if (h < 14.0) h = 14.0;
        t1Rects[item.key] = Rect.fromLTWH(col1X, currentY1, nodeWidth, h);
        _lastNodeRects[item.key] = t1Rects[item.key]!;
        currentY1 += h + 4;
      }

      Map<String, Rect> t2Rects = {};
      double currentY2 = topPadding;
      for (var item in tier2) {
        double h = (item.value / totalT2) * (usableHeight - tier2.length * 4);
        if (h < 14.0) h = 14.0;
        t2Rects[item.key] = Rect.fromLTWH(col2X, currentY2, nodeWidth, h);
        _lastNodeRects[item.key] = t2Rects[item.key]!;
        currentY2 += h + 4;
      }

      Map<String, Rect> t3Rects = {};
      double currentY3 = topPadding;
      for (var item in tier3) {
        double h = (item.value / totalT3) * (usableHeight - tier3.length * 4);
        if (h < 14.0) h = 14.0;
        t3Rects[item.key] = Rect.fromLTWH(col3X, currentY3, nodeWidth, h);
        _lastNodeRects[item.key] = t3Rects[item.key]!;
        currentY3 += h + 4;
      }

      Map<String, double> t1Off = {for (var i in tier1) i.key: t1Rects[i.key]!.top};
      Map<String, double> t2OffA = {for (var i in tier2) i.key: t2Rects[i.key]!.top};
      Map<String, double> t2OffB = {for (var i in tier2) i.key: t2Rects[i.key]!.top};
      Map<String, double> t3Off = {for (var i in tier3) i.key: t3Rects[i.key]!.top};

      int flowIdxA = 0;
      for (var flow in flowsA) {
        String src = flow['source'];
        String tgt = flow['target'];
        double amt = flow['amount'];
        Rect? sR = t1Rects[src];
        Rect? tR = t2Rects[tgt];
        if (sR == null || tR == null) continue;

        double sH = (amt / tier1.firstWhere((x) => x.key == src).value) * sR.height;
        double tH = (amt / tier2.firstWhere((x) => x.key == tgt).value) * tR.height;
        double sTop = t1Off[src]!;
        double tTop = t2OffA[tgt]!;
        t1Off[src] = sTop + sH;
        t2OffA[tgt] = tTop + tH;

        bool isConnected = isolatedNode == null || isolatedNode == src || isolatedNode == tgt;
        // Tier 1 -> Tier 2 path color matches Tier 2 node color
        paintRibbon.color = _getPathColor(tgt, tier2, flowIdxA, isConnected);

        Path p = Path();
        p.moveTo(sR.right, sTop);
        p.cubicTo((sR.right + tR.left) / 2, sTop, (sR.right + tR.left) / 2, tTop, tR.left, tTop);
        p.lineTo(tR.left, tTop + tH);
        p.cubicTo((sR.right + tR.left) / 2, tTop + tH, (sR.right + tR.left) / 2, sTop + sH, sR.right, sTop + sH);
        p.close();
        canvas.drawPath(p, paintRibbon);
        flowIdxA++;
      }

      int flowIdxB = 0;
      for (var flow in flowsB) {
        String src = flow['source'];
        String tgt = flow['target'];
        double amt = flow['amount'];
        Rect? sR = t2Rects[src];
        Rect? tR = t3Rects[tgt];
        if (sR == null || tR == null) continue;

        double sH = (amt / tier2.firstWhere((x) => x.key == src).value) * sR.height;
        double tH = (amt / tier3.firstWhere((x) => x.key == tgt).value) * tR.height;
        double sTop = t2OffB[src]!;
        double tTop = t3Off[tgt]!;
        t2OffB[src] = sTop + sH;
        t3Off[tgt] = tTop + tH;

        bool isConnected = isolatedNode == null || isolatedNode == src || isolatedNode == tgt;
        // Tier 2 -> Tier 3 path color matches Tier 3 (category) node color
        paintRibbon.color = _getPathColor(tgt, tier3, flowIdxB, isConnected);

        Path p = Path();
        p.moveTo(sR.right, sTop);
        p.cubicTo((sR.right + tR.left) / 2, sTop, (sR.right + tR.left) / 2, tTop, tR.left, tTop);
        p.lineTo(tR.left, tTop + tH);
        p.cubicTo((sR.right + tR.left) / 2, tTop + tH, (sR.right + tR.left) / 2, sTop + sH, sR.right, sTop + sH);
        p.close();
        canvas.drawPath(p, paintRibbon);
        flowIdxB++;
      }

      // Tier 1 nodes (Owners / Sources)
      int t1Idx = 0;
      for (var entry in t1Rects.entries) {
        paintNode.color = isZaznamityMode ? const Color(0xFFA855F7) : _lightPalette[t1Idx % _lightPalette.length];
        canvas.drawRRect(RRect.fromRectAndRadius(entry.value, const Radius.circular(2)), paintNode);
        double val = tier1.firstWhere((x) => x.key == entry.key).value;
        double pct = (val / totalT1) * 100;
        TextPainter tp = TextPainter(
          text: TextSpan(
            text: '${entry.key} (${pct.toStringAsFixed(0)}%)',
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.black87),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(entry.value.right + 4, entry.value.top + (entry.value.height / 2) - 6));
        t1Idx++;
      }

      // Tier 2 nodes (Pools) - Label on the left side
      int t2Idx = 0;
      for (var entry in t2Rects.entries) {
        paintNode.color = isZaznamityMode ? const Color(0xFF9333EA) : _lightPalette[(t2Idx + 2) % _lightPalette.length];
        canvas.drawRRect(RRect.fromRectAndRadius(entry.value, const Radius.circular(2)), paintNode);
        double val = tier2.firstWhere((x) => x.key == entry.key).value;
        double pct = (val / totalT2) * 100;
        TextPainter tp = TextPainter(
          text: TextSpan(
            text: '${entry.key} (${pct.toStringAsFixed(0)}%)',
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.black87),
          ),
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.right,
        );
        tp.layout();
        tp.paint(canvas, Offset(entry.value.left - tp.width - 4, entry.value.top + (entry.value.height / 2) - 6));
        t2Idx++;
      }

      // Tier 3 nodes (Categories / Targets)
      int t3Idx = 0;
      for (var entry in t3Rects.entries) {
        paintNode.color = isZaznamityMode ? const Color(0xFF7C3AED) : _lightPalette[(t3Idx + 4) % _lightPalette.length];
        canvas.drawRRect(RRect.fromRectAndRadius(entry.value, const Radius.circular(2)), paintNode);
        double val = tier3.firstWhere((x) => x.key == entry.key).value;
        double pct = (val / totalT3) * 100;
        TextPainter tp = TextPainter(
          text: TextSpan(
            text: '${entry.key} - ${currencyFormat.format(val)} (${pct.toStringAsFixed(0)}%)',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155)),
          ),
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.right,
        );
        tp.layout();
        tp.paint(canvas, Offset(entry.value.left - tp.width - 6, entry.value.top + (entry.value.height / 2) - 8));
        t3Idx++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant SankeyDiagramPainter oldDelegate) {
    return oldDelegate.isolatedNode != isolatedNode ||
        oldDelegate.tierMode != tierMode ||
        oldDelegate.sources != sources ||
        oldDelegate.targets != targets ||
        oldDelegate.tier1 != tier1 ||
        oldDelegate.tier2 != tier2 ||
        oldDelegate.tier3 != tier3 ||
        oldDelegate.isZaznamityMode != isZaznamityMode;
  }
}