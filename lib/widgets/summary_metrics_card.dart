import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SummaryMetricsCard extends StatelessWidget {
  final double mathiasCash;
  final double juliaCash;
  final double liquidNetTotal;
  final Map<String, double> poolTotals;
  final double futureFlowTotal;
  final double prognosisTotal;
  final bool isWide;
  final VoidCallback? onToggleWidth;
  final VoidCallback? onHide;

  const SummaryMetricsCard({
    super.key,
    required this.mathiasCash,
    required this.juliaCash,
    required this.liquidNetTotal,
    required this.poolTotals,
    required this.futureFlowTotal,
    required this.prognosisTotal,
    this.isWide = false,
    this.onToggleWidth,
    this.onHide,
  });

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return format.format(amount);
  }

  Color _getPoolColor(String poolName) {
    switch (poolName.toLowerCase()) {
      case 'checking':
        return const Color(0xFF3F48CC);
      case 'cash':
        return const Color(0xFF56C435);
      case 'savings':
        return const Color(0xFF02E6FF);
      case 'loan':
      case 'loans':
        return const Color(0xFFFF7F27);
      default:
        return const Color(0xFF0369A1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 40;
        final double boxWidth = (fullWidth - 16) / 2;

        final poolEntries = poolTotals.entries.toList();
        List<List<MapEntry<String, double>>> poolRows = [];
        for (int i = 0; i < poolEntries.length; i += 2) {
          poolRows.add(
            poolEntries.sublist(
              i,
              i + 2 > poolEntries.length ? poolEntries.length : i + 2,
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
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
                        'METRICS',
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
                      if (onToggleWidth != null)
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
                      if (onHide != null)
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
              const SizedBox(height: 20),

              Center(
                child: SizedBox(
                  width: fullWidth,
                  child: _buildMetricBox(
                    title: 'LIQUID NET',
                    amount: liquidNetTotal,
                    amountColor: const Color.fromARGB(255, 88, 47, 149),
                    subtitle: 'M: ${_formatCurrency(mathiasCash)}  J: ${_formatCurrency(juliaCash)}',
                    width: fullWidth,
                    isCentered: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              ...poolRows.map((rowEntries) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: rowEntries.map((entry) {
                      final bool isSingle = rowEntries.length == 1;
                      return SizedBox(
                        width: isSingle ? fullWidth : boxWidth,
                        child: _buildMetricBox(
                          title: entry.key.toUpperCase(),
                          amount: entry.value,
                          amountColor: _getPoolColor(entry.key),
                          width: isSingle ? fullWidth : boxWidth,
                        ),
                      );
                    }).toList(),
                  ),
                );
              }),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: boxWidth,
                    child: _buildMetricBox(
                      title: 'FUTURE FLOW',
                      amount: futureFlowTotal,
                      amountColor: const Color(0xFFDC2626),
                      width: boxWidth,
                    ),
                  ),
                  SizedBox(
                    width: boxWidth,
                    child: _buildMetricBox(
                      title: 'PROGNOSIS',
                      amount: prognosisTotal,
                      amountColor: const Color(0xFF000000),
                      width: boxWidth,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricBox({
    required String title,
    required double amount,
    required Color amountColor,
    String? subtitle,
    required double width,
    bool isCentered = false,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: isCentered ? Alignment.center : Alignment.centerLeft,
            child: Text(
              _formatCurrency(amount),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: amountColor,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: isCentered ? Alignment.center : Alignment.centerLeft,
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}