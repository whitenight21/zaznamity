import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
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
  final VoidCallback? onHide;
  final bool isWide;
  final VoidCallback? onToggleWidth;

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
    this.onHide,
    this.isWide = false,
    this.onToggleWidth,
  });

  @override
  State<SankeyFlowCard> createState() => _SankeyFlowCardState();
}

class _SankeyFlowCardState extends State<SankeyFlowCard> {
  String _flowMode = 'Expenses';

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
            padding: const EdgeInsets.only(bottom: 70.0),
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

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = widget.transactions.where((tx) {
      if (tx.isConfirmed != 1) return false;
      if (widget.selectedOwner != null && tx.owner != widget.selectedOwner) {
        return false;
      }
      if (widget.selectedPool != null && widget.selectedPool!.isNotEmpty) {
        if (tx.pool.toLowerCase() != widget.selectedPool!.toLowerCase()) {
          return false;
        }
      }
      final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
      if (widget.startDate != null && txDate.isBefore(widget.startDate!)) {
        return false;
      }
      if (widget.endDate != null) {
        final endOfDay = DateTime(
          widget.endDate!.year,
          widget.endDate!.month,
          widget.endDate!.day,
          23,
          59,
          59,
        );
        if (txDate.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();

    // Aggregate source to target mappings
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

    final sortedSources = sourceTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedTargets = targetTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    int maxItems = sortedSources.length > sortedTargets.length ? sortedSources.length : sortedTargets.length;
    double dynamicHeight = maxItems * 50.0 + 80.0;
    if (dynamicHeight < 300.0) dynamicHeight = 300.0;

    final bool hasDateFilter = widget.startDate != null || widget.endDate != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 48;
        final double boxWidth = (fullWidth - 12) / 2;

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
              // Card Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'SANKEY FLOW CHART',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF582F95),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: widget.onToggleWidth,
                              icon: Icon(
                                widget.isWide
                                    ? Icons.fullscreen_exit
                                    : Icons.fullscreen,
                                size: 18,
                              ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: widget.onHide,
                            icon: const Icon(
                              Icons.visibility_off_outlined,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Row 1: Owner Dropdown (Left) & Date Range Picker (Right)
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
                                value: widget.selectedOwner,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                hint: const Text('All Owners', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF64748B))),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All Owners'),
                                  ),
                                  ...widget.owners.map(
                                    (owner) => DropdownMenuItem<String>(
                                      value: owner,
                                      child: Text(owner),
                                    ),
                                  ),
                                ],
                                onChanged: widget.onOwnerChanged,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Date Range Picker Box with Separate Clear Button
                  SizedBox(
                    width: boxWidth,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.horizontal(
                                left: const Radius.circular(10),
                                right: hasDateFilter ? Radius.zero : const Radius.circular(10),
                              ),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
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
                                      const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF582F95)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          hasDateFilter
                                              ? '${DateFormat('MM/dd').format(widget.startDate!)} - ${DateFormat('MM/dd').format(widget.endDate!)}'
                                              : 'Select Date Range',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: hasDateFilter
                                                ? const Color(0xFF1E293B)
                                                : const Color(0xFF64748B),
                                            fontWeight: hasDateFilter
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!hasDateFilter)
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF94A3B8)),
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
                              color: const Color(0xFFE2E8F0),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
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

              // Row 2: Expense/Income Selector (Left) & Pool Dropdown (Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Mode Selection Controls (Expenses / Income)
                  SizedBox(
                    width: boxWidth,
                    child: SizedBox(
                      height: 44,
                      child: ToggleButtons(
                        isSelected: [_flowMode == 'Expenses', _flowMode == 'Income'],
                        onPressed: (index) {
                          setState(() {
                            _flowMode = index == 0 ? 'Expenses' : 'Income';
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        constraints: BoxConstraints(minHeight: 44, minWidth: boxWidth / 2 - 2),
                        selectedColor: Colors.white,
                        fillColor: const Color(0xFF582F95),
                        color: const Color(0xFF475569),
                        children: const [
                          Text('Expenses', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('Income', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  // Pool Dropdown Box
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
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All Pools'),
                                  ),
                                  ...widget.pools.map(
                                    (pool) => DropdownMenuItem<String>(
                                      value: pool,
                                      child: Text(pool.toUpperCase()),
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
              const SizedBox(height: 20),

              // Graphical Custom Sankey Flow Diagram View with Dynamic Height
              sortedSources.isEmpty || sortedTargets.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No transaction flows match current filters.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: SizedBox(
                        height: dynamicHeight,
                        child: CustomPaint(
                          size: Size(double.infinity, dynamicHeight),
                          painter: SankeyDiagramPainter(
                            sources: sortedSources,
                            targets: sortedTargets,
                            flows: flows,
                            currencyFormat: currencyFormat,
                          ),
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

class SankeyDiagramPainter extends CustomPainter {
  final List<MapEntry<String, double>> sources;
  final List<MapEntry<String, double>> targets;
  final List<Map<String, dynamic>> flows;
  final NumberFormat currencyFormat;

  SankeyDiagramPainter({
    required this.sources,
    required this.targets,
    required this.flows,
    required this.currencyFormat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintRibbon = Paint()..style = PaintingStyle.fill;
    final paintNode = Paint()..style = PaintingStyle.fill;

    double totalSourceVal = sources.fold(0.0, (sum, e) => sum + e.value);
    double totalTargetVal = targets.fold(0.0, (sum, e) => sum + e.value);
    if (totalSourceVal <= 0 || totalTargetVal <= 0) return;

    double nodeWidth = 4.0;
    double leftX = 10.0;
    double rightX = size.width - 10.0;

    double usableHeight = size.height - 20.0;

    Map<String, Rect> sourceRects = {};
    int srcCount = sources.length;
    double sourceGap = srcCount > 1 ? (usableHeight * 0.04 / (srcCount - 1)).clamp(2.0, 6.0) : 0.0;
    double totalSourceGaps = (srcCount > 1) ? (srcCount - 1) * sourceGap : 0.0;
    double availableSourceHeightForNodes = usableHeight - totalSourceGaps;
    if (availableSourceHeightForNodes < srcCount * 12.0) {
      availableSourceHeightForNodes = srcCount * 12.0;
    }

    double currentSourceY = 10.0;
    for (var src in sources) {
      double nodeHeight = (src.value / totalSourceVal) * availableSourceHeightForNodes;
      if (nodeHeight < 12.0) nodeHeight = 12.0;

      sourceRects[src.key] = Rect.fromLTWH(leftX, currentSourceY, nodeWidth, nodeHeight);
      currentSourceY += nodeHeight + sourceGap;
    }

    Map<String, Rect> targetRects = {};
    int tgtCount = targets.length;
    double targetGap = tgtCount > 1 ? (usableHeight * 0.04 / (tgtCount - 1)).clamp(2.0, 6.0) : 0.0;
    double totalTargetGaps = (tgtCount > 1) ? (tgtCount - 1) * targetGap : 0.0;
    double availableTargetHeightForNodes = usableHeight - totalTargetGaps;
    if (availableTargetHeightForNodes < tgtCount * 12.0) {
      availableTargetHeightForNodes = tgtCount * 12.0;
    }

    double currentTargetY = 10.0;
    for (var tgt in targets) {
      double nodeHeight = (tgt.value / totalTargetVal) * availableTargetHeightForNodes;
      if (nodeHeight < 12.0) nodeHeight = 12.0;

      targetRects[tgt.key] = Rect.fromLTWH(rightX, currentTargetY, nodeWidth, nodeHeight);
      currentTargetY += nodeHeight + targetGap;
    }

    Map<String, double> sourceOffsets = {};
    Map<String, double> targetOffsets = {};
    for (var src in sources) {
      sourceOffsets[src.key] = sourceRects[src.key]!.top;
    }
    for (var tgt in targets) {
      targetOffsets[tgt.key] = targetRects[tgt.key]!.top;
    }

    final List<Color> ribbonColors = [
      const Color(0xFFCBD5E1),
      const Color(0xFF93C5FD),
      const Color(0xFFFDE68A),
      const Color(0xFFBBF7D0),
      const Color(0xFFFBCFE8),
    ];

    int colorIndex = 0;
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

      Path path = Path();
      path.moveTo(sRect.right, sTop);
      path.cubicTo(
        (sRect.right + tRect.left) / 2, sTop,
        (sRect.right + tRect.left) / 2, tTop,
        tRect.left, tTop,
      );
      path.lineTo(tRect.left, tTop + tgtH);
      path.cubicTo(
        (sRect.right + tRect.left) / 2, tTop + tgtH,
        (sRect.right + tRect.left) / 2, sTop + srcH,
        sRect.right, sTop + srcH,
      );
      path.close();

      paintRibbon.color = ribbonColors[colorIndex % ribbonColors.length].withValues(alpha: 0.55);
      canvas.drawPath(path, paintRibbon);
      colorIndex++;
    }

    paintNode.color = const Color(0xFF582F95);
    for (var entry in sourceRects.entries) {
      canvas.drawRRect(RRect.fromRectAndRadius(entry.value, const Radius.circular(2)), paintNode);
      
      TextPainter tp = TextPainter(
        text: TextSpan(
          text: '${entry.key}\n${currencyFormat.format(sources.firstWhere((s) => s.key == entry.key).value)}',
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.left,
      );
      tp.layout();
      tp.paint(canvas, Offset(entry.value.right + 6, entry.value.top + (entry.value.height / 2) - 10));
    }

    paintNode.color = const Color.fromARGB(255, 62, 0, 103);
    for (var entry in targetRects.entries) {
      canvas.drawRRect(RRect.fromRectAndRadius(entry.value, const Radius.circular(2)), paintNode);

      TextPainter tp = TextPainter(
        text: TextSpan(
          text: '${entry.key}\n${currencyFormat.format(targets.firstWhere((t) => t.key == entry.key).value)}',
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.right,
      );
      tp.layout();
      tp.paint(canvas, Offset(entry.value.left - tp.width - 6, entry.value.top + (entry.value.height / 2) - 10));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}