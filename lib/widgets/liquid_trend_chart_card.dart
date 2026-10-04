import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:zaznamity/models/transaction_model.dart';

class LiquidTrendChartCard extends StatelessWidget {
  final List<TransactionModel> transactions;
  final Map<String, bool> liquidNetPools;
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback? onSelectStartDate;
  final VoidCallback? onSelectEndDate;
  final VoidCallback? onClearDateFilter;
  final bool isWide;
  final VoidCallback onToggleWidth;
  final VoidCallback onHide;

  const LiquidTrendChartCard({
    super.key,
    required this.transactions,
    required this.liquidNetPools,
    this.startDate,
    this.endDate,
    this.onSelectStartDate,
    this.onSelectEndDate,
    this.onClearDateFilter,
    required this.isWide,
    required this.onToggleWidth,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    final filteredTx = transactions.where((tx) {
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null) return true;
      if (startDate != null) {
        final startClean = DateTime(startDate!.year, startDate!.month, startDate!.day);
        if (txDate.isBefore(startClean)) return false;
      }
      if (endDate != null) {
        final endClean = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
        if (txDate.isAfter(endClean)) return false;
      }
      return true;
    }).toList();

    final sortedTx = List<TransactionModel>.from(filteredTx)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a.createdAt) ?? DateTime.now();
        final dateB = DateTime.tryParse(b.createdAt) ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

    double runningBalance = 0;
    final List<FlSpot> pastSpots = [];
    final List<FlSpot> futureSpots = [];
    
    // To handle continuous lines between past and future, keep track of segments
    List<LineChartBarData> lineBars = [];
    final now = DateTime.now();

    // Build segments
    double currentBalance = 0;
    List<FlSpot> currentSegmentSpots = [];
    Color? currentSegmentColor;
    bool currentIsDashed = false;

    for (int i = 0; i < sortedTx.length; i++) {
      final t = sortedTx[i];
      final isPoolIncluded = liquidNetPools[t.pool] == true;
      if (t.isConfirmed == 1 && isPoolIncluded) {
        currentBalance += (t.type == 'income' ? t.amount : -t.amount);
      }
      
      final txDate = DateTime.tryParse(t.createdAt) ?? now;
      final isFuture = txDate.isAfter(now);
      
      // Determine color and style for this step
      Color targetColor;
      if (isFuture) {
        targetColor = const Color.fromARGB(255, 147, 51, 234); // Purple
      } else {
        targetColor = t.type == 'income' ? Colors.green.shade600 : Colors.red.shade600;
      }
      bool targetDashed = isFuture;

      if (i == 0) {
        currentSegmentSpots.add(FlSpot(i.toDouble(), currentBalance));
        currentSegmentColor = targetColor;
        currentIsDashed = targetDashed;
        // Add starting point
        if (sortedTx.length == 1) {
          currentSegmentSpots.insert(0, FlSpot(0, currentBalance - (t.type == 'income' ? t.amount : -t.amount)));
        }
      } else {
        // If color or style changes, push current segment and start a new one
        if (currentSegmentColor != targetColor || currentIsDashed != targetDashed) {
          // Include previous point to connect lines smoothly
          final prevSpot = currentSegmentSpots.last;
          currentSegmentSpots.add(FlSpot(i.toDouble(), currentBalance));

          lineBars.add(
            LineChartBarData(
              spots: List.from(currentSegmentSpots),
              isCurved: false,
              color: currentSegmentColor ?? Color.fromARGB(255, 88, 47, 149),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              dashArray: currentIsDashed ? [6, 4] : null,
              belowBarData: BarAreaData(show: false),
            ),
          );

          currentSegmentSpots = [prevSpot, FlSpot(i.toDouble(), currentBalance)];
          currentSegmentColor = targetColor;
          currentIsDashed = targetDashed;
        } else {
          currentSegmentSpots.add(FlSpot(i.toDouble(), currentBalance));
        }
      }
    }

    if (currentSegmentSpots.isNotEmpty && lineBars.isEmpty) {
      if (currentSegmentSpots.length == 1) {
        currentSegmentSpots.insert(0, FlSpot(0, currentSegmentSpots[0].y));
      }
      lineBars.add(
        LineChartBarData(
          spots: currentSegmentSpots,
          isCurved: false,
          color: currentSegmentColor ?? const Color.fromARGB(255, 88, 47, 149),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          dashArray: currentIsDashed ? [6, 4] : null,
          belowBarData: BarAreaData(
            show: true,
            color: const Color.fromARGB(255, 189, 145, 255).withValues(alpha: 0.08),
          ),
        ),
      );
    } else if (currentSegmentSpots.isNotEmpty) {
      lineBars.add(
        LineChartBarData(
          spots: currentSegmentSpots,
          isCurved: false,
          color: currentSegmentColor ?? const Color.fromARGB(255, 88, 47, 149),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          dashArray: currentIsDashed ? [6, 4] : null,
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    if (lineBars.isEmpty) {
      lineBars.add(
        LineChartBarData(
          spots: const [FlSpot(0, 0), FlSpot(1, 0)],
          color: Color.fromARGB(255, 88, 47, 149),
          barWidth: 3,
        ),
      );
    }

    // Calculate min/max Y across all spots
    double minY = 0;
    double maxY = 0;
    for (var bar in lineBars) {
      for (var spot in bar.spots) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
      }
    }
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onSelectStartDate,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'START',
                          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                        child: Text(
                          startDate != null ? DateFormat('MM/dd/yyyy').format(startDate!) : 'All',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: onSelectEndDate,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'END',
                          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                        child: Text(
                          endDate != null ? DateFormat('MM/dd/yyyy').format(endDate!) : 'All',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ),
                  if (startDate != null || endDate != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                      onPressed: onClearDateFilter,
                      tooltip: 'Clear Filter',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
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
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF1E293B),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            int idx = spot.x.toInt();
                            if (idx >= 0 && idx < sortedTx.length) {
                              final tx = sortedTx[idx];
                              final dateStr = DateFormat('MMM d').format(DateTime.tryParse(tx.createdAt) ?? DateTime.now());
                              final amountStr = NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(tx.amount);
                              final balanceStr = NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(spot.y);

                              return LineTooltipItem(
                                '$dateStr\n',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                children: [
                                  TextSpan(
                                    text: '${tx.type == 'income' ? '+' : '-'}$amountStr\n',
                                    style: TextStyle(
                                      color: tx.type == 'income' ? Colors.green.shade400 : Colors.red.shade400,
                                      fontSize: 11,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Balance: $balanceStr',
                                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                                  ),
                                ],
                              );
                            }
                            return null;
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: lineBars,
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