import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:zaznamity/models/transaction_model.dart';

class LiquidTrendChartCard extends StatelessWidget {
  final List<TransactionModel> transactions;
  final Map<String, bool> liquidNetPools; // Added parameter for pool settings
  final bool isWide;
  final VoidCallback onToggleWidth;
  final VoidCallback onHide;

  const LiquidTrendChartCard({
    super.key,
    required this.transactions,
    required this.liquidNetPools,
    required this.isWide,
    required this.onToggleWidth,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final sortedTx = List<TransactionModel>.from(transactions)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a.createdAt) ?? DateTime.now();
        final dateB = DateTime.tryParse(b.createdAt) ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

    double runningBalance = 0;
    final List<FlSpot> spots = [];

    for (int i = 0; i < sortedTx.length; i++) {
      final t = sortedTx[i];
      
      // Only count transactions if they are confirmed and their pool is enabled in settings
      final isPoolIncluded = liquidNetPools[t.pool] == true;
      if (t.isConfirmed == 1 && isPoolIncluded) {
        runningBalance += (t.type == 'income' ? t.amount : -t.amount);
      }
      spots.add(FlSpot(i.toDouble(), runningBalance));
    }

    if (spots.isEmpty) {
      spots.add(const FlSpot(0, 0));
    }

    double minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    if (minY > 0) minY = 0;
    if (maxY < 0) maxY = 0;

    final double yRange = maxY - minY;
    final double yPadding = yRange == 0 ? 50 : yRange * 0.15;
    minY -= yPadding;
    maxY += yPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
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
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'LIQUID TREND',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 88, 47, 149),
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
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF64748B),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: onToggleWidth,
                            icon: Icon(
                              isWide ? Icons.fullscreen_exit : Icons.fullscreen,
                              size: 18,
                            ),
                            tooltip: isWide ? 'Narrow' : 'Wide',
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 32,
                        width: 32,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            foregroundColor: const Color(0xFF64748B),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: onHide,
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
              const SizedBox(height: 24),
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: minY,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => const FlLine(
                        color: Color(0xFFF1F5F9),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < sortedTx.length) {
                              final date = DateTime.tryParse(sortedTx[index].createdAt);
                              if (date != null) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('MMM d').format(date),
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                  ),
                                );
                              }
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '\$${value.toInt()}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: const Color.fromARGB(255, 88, 47, 149),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color.fromARGB(255, 189, 145, 255).withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}