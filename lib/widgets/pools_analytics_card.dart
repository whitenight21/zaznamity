import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction_model.dart';

class PoolsAnalyticsCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final Map<String, bool> pools;
  final String? selectedOwner;
  final bool isWide;
  final VoidCallback onToggleWidth;
  final VoidCallback onHide;

  const PoolsAnalyticsCard({
    super.key,
    required this.transactions,
    required this.pools,
    required this.selectedOwner,
    required this.isWide,
    required this.onToggleWidth,
    required this.onHide,
  });

  @override
  State<PoolsAnalyticsCard> createState() => _PoolsAnalyticsCardState();
}

class _PoolsAnalyticsCardState extends State<PoolsAnalyticsCard> {
  // --- Memoization Cache Fields ---
  Map<String, double> _cachedPoolBalances = {};
  Map<String, List<FlSpot>> _cachedPoolSpots = {};
  List<String> _cachedActivePoolKeys = [];

  int? _lastTxLength;
  String? _lastOwner;
  String _lastPoolsKey = '';

  void _computeDataIfNeeded() {
    final poolsKey = widget.pools.entries.map((e) => '${e.key}:${e.value}').join(',');

    if (_lastTxLength == widget.transactions.length &&
        _lastOwner == widget.selectedOwner &&
        _lastPoolsKey == poolsKey) {
      return;
    }

    final activePoolKeys = widget.pools.entries.where((e) => e.value).map((e) => e.key).toList();
    Map<String, double> poolBalances = {};
    Map<String, List<FlSpot>> poolSpots = {};

    for (var poolKey in activePoolKeys) {
      final poolTxs = widget.transactions.where((tx) {
        if (tx.pool.toLowerCase() != poolKey.toLowerCase()) return false;
        if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && tx.owner != widget.selectedOwner) {
          return false;
        }
        return true;
      }).toList();

      double poolBalance = 0;
      for (var tx in poolTxs) {
        if (tx.isConfirmed == 1) {
          poolBalance += (tx.type == 'income' ? tx.amount : -tx.amount);
        }
      }
      poolBalances[poolKey] = poolBalance;

      // Sort and generate spots
      final sortedTxs = List<TransactionModel>.from(poolTxs)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      double runningTotal = 0;
      List<FlSpot> spots = [];
      for (int i = 0; i < sortedTxs.length; i++) {
        runningTotal += (sortedTxs[i].type == 'income' ? sortedTxs[i].amount : -sortedTxs[i].amount);
        spots.add(FlSpot(i.toDouble(), runningTotal));
      }
      if (spots.length == 1) {
        spots.insert(0, FlSpot(0, spots[0].y));
      }
      poolSpots[poolKey] = spots;
    }

    _cachedActivePoolKeys = activePoolKeys;
    _cachedPoolBalances = poolBalances;
    _cachedPoolSpots = poolSpots;

    _lastTxLength = widget.transactions.length;
    _lastOwner = widget.selectedOwner;
    _lastPoolsKey = poolsKey;
  }

  @override
  Widget build(BuildContext context) {
    _computeDataIfNeeded();

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
              const Text(
                'POOLS ANALYTICS',
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
                  IconButton(
                    icon: Icon(widget.isWide ? Icons.fullscreen_exit : Icons.fullscreen, size: 18),
                    onPressed: widget.onToggleWidth,
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility_off_outlined, size: 16),
                    onPressed: widget.onHide,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _cachedActivePoolKeys.isEmpty
              ? const Text('No active pools found.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cachedActivePoolKeys.length,
                  itemBuilder: (context, index) {
                    String poolKey = _cachedActivePoolKeys[index];
                    return _buildPoolMiniSection(poolKey);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildPoolMiniSection(String poolKey) {
    final poolBalance = _cachedPoolBalances[poolKey] ?? 0.0;
    final spots = _cachedPoolSpots[poolKey] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                poolKey.toUpperCase(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              Text(
                '\$${poolBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: poolBalance >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: spots.isEmpty
                ? const Center(child: Text('No entries for this pool', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))))
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: const Color(0xFF582F95),
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF582F95).withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}