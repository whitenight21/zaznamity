import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SummaryMetricsCard extends StatefulWidget {
  final List<String> owners;
  final String? selectedOwner; // Added to sync with global master selector
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
        final double fullWidth = availableWidth - 40;
        final double boxWidth = (fullWidth - 16) / 2;

        Map<String, double> currentPools;
        double currentLiquidNet;
        String displayTitle;
        String? singleSubtitle;
        List<Widget> wrapSubtitles = [];

        if (_selectedOwner == 'All Owners') {
          currentPools = widget.totalPoolTotals;
          currentLiquidNet = widget.totalLiquidNet;
          displayTitle = 'LIQUID NET';
          
          // Build a list of Text widgets for the Wrap component
          wrapSubtitles = widget.ownerBreakdownForLiquidNet.entries.map((e) {
            final val = e.value['liquidNet'] ?? 0;
            return Text(
              '${e.key}: ${_formatCurrency(val)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            );
          }).toList();
        } else {
          currentPools = widget.poolTotalsByOwner[_selectedOwner] ?? {};
          currentLiquidNet = widget.liquidNetByOwner[_selectedOwner] ?? 0.0;
          displayTitle = 'LIQUID NET';
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedOwner,
                            isDense: true,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF582F95)),
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
                      const SizedBox(width: 8),
                      if (widget.onToggleWidth != null)
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
                              onPressed: widget.onToggleWidth,
                              icon: Icon(
                                widget.isWide ? Icons.fullscreen_exit : Icons.fullscreen,
                                size: 18,
                              ),
                              tooltip: widget.isWide ? 'Narrow' : 'Wide',
                            ),
                          ),
                        ),
                      if (widget.onHide != null)
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
                            onPressed: widget.onHide,
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
                    title: displayTitle,
                    amount: currentLiquidNet,
                    amountColor: const Color.fromARGB(255, 88, 47, 149),
                    subtitle: singleSubtitle,
                    customSubtitleWrap: _selectedOwner == 'All Owners' ? wrapSubtitles : null,
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
    List<Widget>? customSubtitleWrap,
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
          if (customSubtitleWrap != null && customSubtitleWrap.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              alignment: isCentered ? WrapAlignment.center : WrapAlignment.start,
              spacing: 12.0,
              runSpacing: 4.0,
              children: customSubtitleWrap,
            ),
          ],
        ],
      ),
    );
  }
}