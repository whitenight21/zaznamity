import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

class MonthlyCashflowTrendCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<String> owners;
  final List<String> pools;
  final String? selectedOwner;
  final String? selectedPool;
  final Function(String?)? onOwnerChanged;
  final Function(String?)? onPoolChanged;
  final Function(String monthKey, String type)? onJumpToHistory;
  final bool isWide;
  final VoidCallback? onToggleWidth;
  final VoidCallback? onHide;

  const MonthlyCashflowTrendCard({
    super.key,
    required this.transactions,
    required this.owners,
    required this.pools,
    this.selectedOwner,
    this.selectedPool,
    this.onOwnerChanged,
    this.onPoolChanged,
    this.onJumpToHistory,
    this.isWide = false,
    this.onToggleWidth,
    this.onHide,
  });

  @override
  State<MonthlyCashflowTrendCard> createState() => _MonthlyCashflowTrendCardState();
}

class _MonthlyCashflowTrendCardState extends State<MonthlyCashflowTrendCard> {
  String _selectedTimeframe = 'All time';
  bool _showNetTrendLine = true;

  // --- Memoization Cache Fields ---
  List<BarChartGroupData> _cachedBarGroups = [];
  List<FlSpot> _cachedNetSpots = [];
  List<String> _cachedSortedKeys = [];
  List<String> _cachedMonthLabels = [];
  double _cachedMaxY = 1000.0;
  double _cachedMinY = -1000.0;

  int? _lastTxLength;
  String? _lastOwner;
  String? _lastPool;
  String? _lastTimeframe;

  void _computeChartDataIfNeeded() {
    if (_lastTxLength == widget.transactions.length &&
        _lastOwner == widget.selectedOwner &&
        _lastPool == widget.selectedPool &&
        _lastTimeframe == _selectedTimeframe) {
      return;
    }

    final filteredTxs = widget.transactions.where((tx) {
      if (tx.isConfirmed != 1) return false;
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
      } else if (_selectedTimeframe == 'Last 12 Months') {
        final twelveMonthsAgo = DateTime.now().subtract(const Duration(days: 365));
        if (txDate.isBefore(twelveMonthsAgo)) return false;
      }
      return true;
    }).toList();

    final Map<String, Map<String, double>> monthlyData = {};
    for (var tx in filteredTxs) {
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt == null) continue;
      final key = DateFormat('yyyy-MM').format(dt);
      
      monthlyData.putIfAbsent(key, () => {'income': 0.0, 'expense': 0.0});
      if (tx.type == 'income') {
        monthlyData[key]!['income'] = (monthlyData[key]!['income'] ?? 0) + tx.amount;
      } else if (tx.type == 'expense') {
        monthlyData[key]!['expense'] = (monthlyData[key]!['expense'] ?? 0) + tx.amount;
      }
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

    _lastTxLength = widget.transactions.length;
    _lastOwner = widget.selectedOwner;
    _lastPool = widget.selectedPool;
    _lastTimeframe = _selectedTimeframe;
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
          decoration: BoxDecoration(
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
                  const Text(
                    'CASHFLOW TREND',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF582F95),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onToggleWidth != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: SizedBox(
                            height: 28,
                            width: 28,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFF1F5F9),
                                foregroundColor: const Color(0xFF64748B),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: widget.onToggleWidth,
                              icon: Icon(
                                widget.isWide ? Icons.fullscreen_exit : Icons.fullscreen,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      if (widget.onHide != null)
                        SizedBox(
                          height: 28,
                          width: 28,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF64748B),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: widget.onHide,
                            icon: const Icon(Icons.visibility_off_outlined, size: 14),
                          ),
                        ),
                    ],
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
                                value: widget.selectedOwner,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                hint: const Text('All Owners', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF64748B))),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text('All Owners')),
                                  ...widget.owners.map((o) => DropdownMenuItem<String>(value: o, child: Text(o))),
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
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedTimeframe,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                items: ['All time', 'This Year', 'Last 12 Months']
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: boxWidth,
                    child: SizedBox(
                      height: 40,
                      child: FilterChip(
                        label: const Text('Net Trend', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        selected: _showNetTrendLine,
                        selectedColor: const Color(0xFF582F95).withValues(alpha: 0.2),
                        checkmarkColor: const Color(0xFF582F95),
                        onSelected: (val) => setState(() => _showNetTrendLine = val),
                      ),
                    ),
                  ),
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
                          const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: widget.selectedPool,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                hint: const Text('All Pools', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF64748B))),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text('All Pools')),
                                  ...widget.pools.map((p) => DropdownMenuItem<String>(value: p, child: Text(p.toUpperCase()))),
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
              const SizedBox(height: 20),

              _cachedSortedKeys.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Text('No transaction history found for this view.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
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
                                          title: Text('View Zaznams (${_cachedMonthLabels[groupIndex]})'),
                                          content: const Text('Display in All Zaznams:'),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                widget.onJumpToHistory!(monthKey, 'expense');
                                              },
                                              child: const Text('Expenses', style: TextStyle(color: Color(0xFFEF4444))),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                widget.onJumpToHistory!(monthKey, 'income');
                                              },
                                              child: const Text('Income', style: TextStyle(color: Colors.white)),
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
                                              style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
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
                                        style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
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
                                getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
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
                                      color: const Color(0xFF582F95),
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