import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zaznamity/models/transaction_model.dart';

class PoolsAnalyticsCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Filter active pools
    final activePoolKeys = pools.entries.where((e) => e.value).map((e) => e.key).toList();

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
                    icon: Icon(isWide ? Icons.fullscreen_exit : Icons.fullscreen, size: 18),
                    onPressed: onToggleWidth,
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility_off_outlined, size: 16),
                    onPressed: onHide,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          if (activePoolKeys.isEmpty)
            const Text('No active pools found.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activePoolKeys.length,
              itemBuilder: (context, index) {
                String poolKey = activePoolKeys[index];
                return _buildPoolMiniSection(poolKey);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPoolMiniSection(String poolKey) {
    // Filter transactions for this specific pool and owner
    final poolTxs = transactions.where((tx) {
      if (tx.pool.toLowerCase() != poolKey.toLowerCase()) return false;
      if (selectedOwner != null && selectedOwner!.isNotEmpty && tx.owner != selectedOwner) {
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
          // Mini visual representation or progress/trend bar for this pool
          SizedBox(
            height: 40,
            child: poolTxs.isEmpty
                ? const Center(child: Text('No entries for this pool', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))))
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _generateSpots(poolTxs),
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

  List<FlSpot> _generateSpots(List<TransactionModel> txs) {
    // Sort transactions by date and map running balance to chart spots
    txs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    double runningTotal = 0;
    List<FlSpot> spots = [];
    for (int i = 0; i < txs.length; i++) {
      runningTotal += (txs[i].type == 'income' ? txs[i].amount : -txs[i].amount);
      spots.add(FlSpot(i.toDouble(), runningTotal));
    }
    if (spots.length == 1) {
      spots.insert(0, FlSpot(0, spots[0].y));
    }
    return spots;
  }
}