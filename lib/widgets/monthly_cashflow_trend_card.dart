// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class MonthlyCashflowTrendCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
  final List<String> pools;
  final String? selectedOwner;
  final String? selectedPool;
  final Function(String?)? onOwnerChanged;
  final Function(String?)? onPoolChanged;
  final Function(String monthKey, String type, String? owner)? onJumpToHistory;

  const MonthlyCashflowTrendCard({
    super.key,
    required this.transactions,
    this.labels = const [],
    required this.owners,
    required this.pools,
    this.selectedOwner,
    this.selectedPool,
    this.onOwnerChanged,
    this.onPoolChanged,
    this.onJumpToHistory,
  });

  @override
  State<MonthlyCashflowTrendCard> createState() => _MonthlyCashflowTrendCardState();
}

class _MonthlyCashflowTrendCardState extends State<MonthlyCashflowTrendCard> {
  String _selectedTimeframe = 'All time';
  bool _showNetTrendLine = true;
  bool _excludeTransfers = true;
  bool _isZaznamityMode = true;

  List<BarChartGroupData> _cachedBarGroups = [];
  List<FlSpot> _cachedNetSpots = [];
  List<String> _cachedSortedKeys = [];
  List<String> _cachedMonthLabels = [];
  double _cachedMaxY = 1000.0;
  double _cachedMinY = -1000.0;
  double _cachedSavingsRate = 0.0;

  int? _lastTxLength;
  String? _lastOwner;
  String? _lastPool;
  String? _lastTimeframe;
  bool? _lastExcludeTransfers;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    if (mounted) {
      setState(() {
        _selectedTimeframe = prefs.getString('set_cashFlow_range') ?? 'All time';
        _excludeTransfers = prefs.getBool('exclude_transfers_insights') ?? true;
        _isZaznamityMode = (savedTheme == 'zaznamity');
      });
    }
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

  void _computeChartDataIfNeeded() {
    if (_lastTxLength == widget.transactions.length &&
        _lastOwner == widget.selectedOwner &&
        _lastPool == widget.selectedPool &&
        _lastTimeframe == _selectedTimeframe &&
        _lastExcludeTransfers == _excludeTransfers) {
      return;
    }

    final filteredTxs = widget.transactions.where((tx) {
      if (tx.isConfirmed != 1) return false;

      if (_excludeTransfers && widget.labels.isNotEmpty) {
        final matchLbl = widget.labels.where((l) => l.id == tx.labelId).firstOrNull;
        if (matchLbl != null && matchLbl.name.toLowerCase() == 'transfer') {
          return false;
        }
      }

      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && tx.owner != widget.selectedOwner) {
        return false;
      }
      if (widget.selectedPool != null && widget.selectedPool!.isNotEmpty) {
        if (tx.pool.toLowerCase() != widget.selectedPool!.toLowerCase()) {
          return false;
        }
      }
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null) return false;

      if (_selectedTimeframe == 'This Year') {
        if (txDate.year != DateTime.now().year) return false;
      } else if (_selectedTimeframe == 'Last 12 Months' || _selectedTimeframe == '90 Days') {
        final days = _selectedTimeframe == '90 Days' ? 90 : 365;
        final cutoff = DateTime.now().subtract(Duration(days: days));
        if (txDate.isBefore(cutoff)) return false;
      } else if (_selectedTimeframe == 'Current Month') {
        final now = DateTime.now();
        if (txDate.year != now.year || txDate.month != now.month) return false;
      } else if (_selectedTimeframe == 'Last 30 Days') {
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        if (txDate.isBefore(cutoff)) return false;
      }
      return true;
    }).toList();

    final Map<String, Map<String, double>> monthlyData = {};
    double totalIncomeSum = 0;
    double totalExpenseSum = 0;

    for (var tx in filteredTxs) {
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt == null) continue;
      final key = DateFormat('yyyy-MM').format(dt);
      
      monthlyData.putIfAbsent(key, () => {'income': 0.0, 'expense': 0.0});
      if (tx.type == 'income') {
        monthlyData[key]!['income'] = (monthlyData[key]!['income'] ?? 0) + tx.amount;
        totalIncomeSum += tx.amount;
      } else if (tx.type == 'expense') {
        monthlyData[key]!['expense'] = (monthlyData[key]!['expense'] ?? 0) + tx.amount;
        totalExpenseSum += tx.amount;
      }
    }

    double savingsRate = 0.0;
    if (totalIncomeSum > 0) {
      savingsRate = ((totalIncomeSum - totalExpenseSum) / totalIncomeSum) * 100;
    }

    final sortedKeys = monthlyData.keys.toList()..sort();

    List<BarChartGroupData> barGroups = [];
    List<FlSpot> netSpots = [];
    List<String> monthLabels = [];

    double maxY = 1000.0;
    double minY = -1000.0;

    for (int i = 0; i < sortedKeys.length; i++) {
      String mKey = sortedKeys[i];
      double inc = monthlyData[mKey]!['income'] ?? 0.0;
      double exp = monthlyData[mKey]!['expense'] ?? 0.0;
      double net = inc - exp;

      if (inc > maxY) maxY = inc;
      if (-exp < minY) minY = -exp;
      if (net > maxY) maxY = net;
      if (net < minY) minY = net;

      monthLabels.add(DateFormat('MMM yyyy').format(DateTime.parse('$mKey-01')));

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: inc,
              fromY: -exp,
              color: Colors.transparent,
              width: 14,
              rodStackItems: [
                BarChartRodStackItem(-exp, 0, const Color(0xFFEF4444)),
                BarChartRodStackItem(0, inc, const Color(0xFF10B981)),
              ],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3), bottom: Radius.circular(3)),
            ),
          ],
        ),
      );

      netSpots.add(FlSpot(i.toDouble(), net));
    }

    _cachedBarGroups = barGroups;
    _cachedNetSpots = netSpots;
    _cachedSortedKeys = sortedKeys;
    _cachedMonthLabels = monthLabels;
    _cachedMaxY = maxY;
    _cachedMinY = minY;
    _cachedSavingsRate = savingsRate;

    _lastTxLength = widget.transactions.length;
    _lastOwner = widget.selectedOwner;
    _lastPool = widget.selectedPool;
    _lastTimeframe = _selectedTimeframe;
    _lastExcludeTransfers = _excludeTransfers;
  }

  @override
  Widget build(BuildContext context) {
    _computeChartDataIfNeeded();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 32;
        final double boxWidth = (fullWidth - 12) / 2;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: _isZaznamityMode
              ? BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
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
                  Text(
                    'CASH FLOW TREND',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                      letterSpacing: 0.8,
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
                                value: widget.selectedOwner,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                hint: Text('All Owners', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                items: [
                                  DropdownMenuItem<String>(value: null, child: Text('All Owners', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  ...widget.owners.map((o) => DropdownMenuItem<String>(value: o, child: Text(o, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
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
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedTimeframe,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                items: ['All time', 'Current Month', 'Last 30 Days', 'This Year', 'Last 12 Months']
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedTimeframe = val);
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

              LayoutBuilder(
                builder: (context, rowConstraints) {
                  final double rowWidth = rowConstraints.maxWidth;
                  final double w25 = (rowWidth - 16) * 0.24;
                  final double w50 = (rowWidth - 16) * 0.48;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: w25,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 48,
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isZaznamityMode
                                    ? const Color(0xFF1E1333)
                                    : (_cachedSavingsRate >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isZaznamityMode
                                      ? Colors.white12
                                      : (_cachedSavingsRate >= 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.savings_outlined,
                                        size: 11,
                                        color: _cachedSavingsRate >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Savings',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'rate: ${_cachedSavingsRate.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _cachedSavingsRate >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -4,
                              child: InkWell(
                                onTap: () => _showInfoDialog(
                                  context,
                                  'Savings Rate',
                                  'Savings rate calculates the percentage of total income that is retained as net savings ((Total Income - Total Expenses) / Total Income) over the selected timeframe.',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(
                        width: w25,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _showNetTrendLine = !_showNetTrendLine),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 48,
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _showNetTrendLine
                                      ? (_isZaznamityMode ? const Color(0xFFA855F7).withValues(alpha: 0.25) : const Color(0xFF582F95).withValues(alpha: 0.15))
                                      : (_isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _showNetTrendLine
                                        ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                        : (_isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.show_chart_rounded,
                                          size: 11,
                                          color: _showNetTrendLine
                                              ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                              : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Net Line',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      _showNetTrendLine ? 'Visible' : 'Hidden',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: _showNetTrendLine
                                            ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                            : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -4,
                              child: InkWell(
                                onTap: () => _showInfoDialog(
                                  context,
                                  'Net Trend Line',
                                  'The net trend line connects monthly net cashflow points (Income minus Expenses), providing a visual trajectory of whether your monthly savings balance is expanding or contracting over time.',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(
                        width: w50,
                        child: Container(
                          height: 48,
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
                                  child: DropdownButton<String>(
                                    value: widget.selectedPool,
                                    isDense: true,
                                    isExpanded: true,
                                    dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                    hint: Text('All Pools', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                    items: [
                                      DropdownMenuItem<String>(value: null, child: Text('All Pools', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                      ...widget.pools.map((p) => DropdownMenuItem<String>(value: p, child: Text(p.toUpperCase(), style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
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
                  );
                },
              ),
              const SizedBox(height: 16),

              _cachedSortedKeys.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text('No transaction history found for this view.', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12)),
                      ),
                    )
                  : SizedBox(
                      height: 310,
                      child: Stack(
                        children: [
                          BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: _cachedMaxY * 1.25,
                              minY: _cachedMinY * 1.25,
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchCallback: (FlTouchEvent event, barTouchResponse) {
                                  if (event is FlTapUpEvent &&
                                      barTouchResponse != null &&
                                      barTouchResponse.spot != null &&
                                      widget.onJumpToHistory != null) {
                                    final groupIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                                    if (groupIndex >= 0 && groupIndex < _cachedSortedKeys.length) {
                                      final monthKey = _cachedSortedKeys[groupIndex];
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                          title: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'View Zaznams',
                                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _cachedMonthLabels[groupIndex],
                                                style: TextStyle(fontSize: 16, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          content: Text('Display in All Zaznams:', style: TextStyle(color: _isZaznamityMode ? Colors.white70 : const Color(0xFF334155))),
                                          actions: [
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFEF4444),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              ),
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                widget.onJumpToHistory!(monthKey, 'expense', widget.selectedOwner);
                                              },
                                              child: const Text('Expenses'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF10B981),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              ),
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                widget.onJumpToHistory!(monthKey, 'income', widget.selectedOwner);
                                              },
                                              child: const Text('Income'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      int index = value.toInt();
                                      if (index >= 0 && index < _cachedMonthLabels.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Transform.rotate(
                                            angle: -1.5708,
                                            child: Text(
                                              _cachedMonthLabels[index],
                                              style: TextStyle(fontSize: 9, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        );
                                      }
                                      return const Text('');
                                    },
                                    reservedSize: 50,
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 45,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        '\$${value.toInt()}',
                                        style: TextStyle(fontSize: 9, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8)),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: (_cachedMaxY - _cachedMinY) > 0 ? (_cachedMaxY - _cachedMinY) / 5 : 1000,
                                getDrawingHorizontalLine: (value) => FlLine(color: _isZaznamityMode ? Colors.white10 : const Color(0xFFE2E8F0), strokeWidth: 1),
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: _cachedBarGroups,
                            ),
                          ),
                          if (_showNetTrendLine)
                            IgnorePointer(
                              child: LineChart(
                                LineChartData(
                                  maxY: _cachedMaxY * 1.25,
                                  minY: _cachedMinY * 1.25,
                                  lineTouchData: const LineTouchData(enabled: false),
                                  titlesData: const FlTitlesData(show: false),
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: _cachedNetSpots,
                                      isCurved: true,
                                      color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                                      barWidth: 2.5,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: true),
                                    ),
                                  ],
                                ),
                              ),
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