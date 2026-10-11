import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SummaryMetricsCard extends StatefulWidget {
  final List<String> owners;
  final String? selectedOwner;
  final Map<String, Map<String, double>> poolTotalsByOwner;
  final Map<String, double> totalPoolTotals;
  final Map<String, double> liquidNetByOwner;
  final double totalLiquidNet;
  final Map<String, Map<String, double>> ownerBreakdownForLiquidNet;
  final bool isWide;
  final VoidCallback? onToggleWidth;
  final VoidCallback? onHide;

  const SummaryMetricsCard({
    super.key,
    required this.owners,
    this.selectedOwner,
    required this.poolTotalsByOwner,
    required this.totalPoolTotals,
    required this.liquidNetByOwner,
    required this.totalLiquidNet,
    required this.ownerBreakdownForLiquidNet,
    this.isWide = false,
    this.onToggleWidth,
    this.onHide,
  });

  @override
  State<SummaryMetricsCard> createState() => _SummaryMetricsCardState();
}

class _SummaryMetricsCardState extends State<SummaryMetricsCard> {
  late String _selectedOwner;

  @override
  void initState() {
    super.initState();
    _selectedOwner = widget.selectedOwner ?? 'All Owners';
  }

  @override
  void didUpdateWidget(covariant SummaryMetricsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOwner != oldWidget.selectedOwner) {
      setState(() {
        _selectedOwner = widget.selectedOwner ?? 'All Owners';
      });
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return format.format(amount);
  }

  Color _getPoolColor(String poolName) {
    switch (poolName.toLowerCase()) {
      case 'checking':
        return const Color.fromARGB(255, 0, 132, 184);
      case 'cash':
        return const Color(0xFF56C435);
      case 'savings':
        return const Color(0xFFFF7F27);
      case 'loan':
      case 'loans':
        return const Color.fromARGB(255, 105, 105, 105);
      default:
        return Colors.primaries[poolName.hashCode % Colors.primaries.length];
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 32;
        final double boxWidth = (fullWidth - 12) / 2;

        Map<String, double> currentPools;
        double currentLiquidNet;
        String displayTitle = 'LIQUID NET';
        String? singleSubtitle;
        List<Widget> wrapSubtitles = [];

        if (_selectedOwner == 'All Owners') {
          currentPools = widget.totalPoolTotals;
          currentLiquidNet = widget.totalLiquidNet;
          
          wrapSubtitles = widget.ownerBreakdownForLiquidNet.entries.map((e) {
            final val = e.value['liquidNet'] ?? 0;
            return Text(
              '${e.key}: ${_formatCurrency(val)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            );
          }).toList();
        } else {
          currentPools = widget.poolTotalsByOwner[_selectedOwner] ?? {};
          currentLiquidNet = widget.liquidNetByOwner[_selectedOwner] ?? 0.0;
          singleSubtitle = _selectedOwner.toUpperCase();
        }

        final poolEntries = currentPools.entries.toList();
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
              // Top Row: Title & Action Buttons matching Future Metrics style
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'METRICS',
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
                              tooltip: widget.isWide ? 'Narrow' : 'Wide',
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
                            icon: const Icon(
                              Icons.visibility_off_outlined,
                              size: 14,
                            ),
                            tooltip: 'Hide',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Second Row: Owner Dropdown (Left) & Liquid Net Box (Right) matching Future Metrics layout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Owner Dropdown Box
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
                                value: _selectedOwner,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                items: [
                                  const DropdownMenuItem(value: 'All Owners', child: Text('All Owners')),
                                  ...widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o))),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedOwner = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Liquid Net Display Box
                  SizedBox(
                    width: boxWidth,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayTitle,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.6,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _formatCurrency(currentLiquidNet),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF582F95),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Subtitle/Owner breakdown row rendered directly below if needed
              if (singleSubtitle != null || (wrapSubtitles.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: singleSubtitle != null
                      ? Text(
                          singleSubtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Wrap(
                          spacing: 12.0,
                          runSpacing: 4.0,
                          children: wrapSubtitles,
                        ),
                ),
              ],
              const SizedBox(height: 16),

              // Rest of Pool Boxes
              ...poolRows.map((rowEntries) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
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
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatCurrency(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: amountColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}