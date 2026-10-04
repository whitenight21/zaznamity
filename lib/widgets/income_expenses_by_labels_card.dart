import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class IncomeExpensesByLabelsCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? selectedOwner;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final ValueChanged<String?> onOwnerChanged;
  final VoidCallback onClearDateFilter;
  final VoidCallback? onHide;
  final bool isWide;
  final VoidCallback? onToggleWidth;

  const IncomeExpensesByLabelsCard({
    super.key,
    required this.transactions,
    required this.labels,
    this.startDate,
    this.endDate,
    this.selectedOwner,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onOwnerChanged,
    required this.onClearDateFilter,
    this.onHide,
    this.isWide = false,
    this.onToggleWidth,
  });

  @override
  State<IncomeExpensesByLabelsCard> createState() => _IncomeExpensesByLabelsCardState();
}

class _IncomeExpensesByLabelsCardState extends State<IncomeExpensesByLabelsCard> {
  String chartDisplayMode = 'Show Expenses';
  String chartType = 'Bar'; // 'Bar' or 'Donut'
  int? touchedPieIndex;
  
  final Set<int> selectedIncomeLabels = {};
  final Set<int> selectedExpenseLabels = {};
  bool _initializedLabels = false;

  @override
  Widget build(BuildContext context) {
    if (!_initializedLabels && widget.labels.isNotEmpty) {
      for (var l in widget.labels) {
        selectedIncomeLabels.add(l.id);
        selectedExpenseLabels.add(l.id);
      }
      _initializedLabels = true;
    }

    final filteredTransactions = widget.transactions.where((tx) {
      if (widget.selectedOwner != null && tx.owner != widget.selectedOwner) {
        return false;
      }
      final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
      if (widget.startDate != null && txDate.isBefore(widget.startDate!)) {
        return false;
      }
      if (widget.endDate != null) {
        final endOfDay = DateTime(widget.endDate!.year, widget.endDate!.month, widget.endDate!.day, 23, 59, 59);
        if (txDate.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();

    double totalIncome = 0;
    double totalExpenses = 0;
    final Map<String, double> labelTotals = {};

    for (var tx in filteredTransactions) {
      if (tx.isConfirmed != 1) continue;
      
      final labelObj = widget.labels.firstWhere(
        (l) => l.id == tx.labelId,
        orElse: () => LabelModel(id: 0, name: 'General', color: '#4338CA'),
      );

      if (tx.type == 'income') {
        if (!selectedIncomeLabels.contains(labelObj.id)) continue;
        totalIncome += tx.amount;
        if (chartDisplayMode == 'Show Income') {
          labelTotals[labelObj.name] = (labelTotals[labelObj.name] ?? 0) + tx.amount;
        }
      } else {
        if (!selectedExpenseLabels.contains(labelObj.id)) continue;
        totalExpenses += tx.amount;
        if (chartDisplayMode == 'Show Expenses') {
          labelTotals[labelObj.name] = (labelTotals[labelObj.name] ?? 0) + tx.amount;
        }
      }
    }

    final sortedEntries = labelTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final double activeModeTotalSum = sortedEntries.fold(0.0, (sum, entry) => sum + entry.value);

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final maxTopAmount = (totalIncome > totalExpenses ? totalIncome : totalExpenses) > 0 
        ? (totalIncome > totalExpenses ? totalIncome : totalExpenses) 
        : 1.0;

    final maxChartAmount = sortedEntries.isNotEmpty ? sortedEntries.first.value : 1.0;
    
    final paletteColors = [
      const Color(0xFFEF4444),
      const Color(0xFFF97316),
      const Color(0xFFEAB308),
      const Color(0xFF84CC16),
      const Color(0xFF10B981),
      const Color(0xFF06B6D4),
      const Color(0xFF3B82F6),
      const Color(0xFF6366F1),
    ];

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
                        'LABEL ANALYTICS',
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
              const SizedBox(height: 16),

              // Date Selection Row (Moved right under title)[cite: 15, 16]
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 42,
                          child: Text('START:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: widget.onSelectStartDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.startDate != null ? DateFormat('MM/dd/yyyy').format(widget.startDate!) : '09/01/2026',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 36,
                          child: Text('END:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: widget.onSelectEndDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.endDate != null ? DateFormat('MM/dd/yyyy').format(widget.endDate!) : '09/30/2026',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Total Income & Total Expenses Cards
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL INCOME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857), letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (totalIncome / maxTopAmount).clamp(0.0, 1.0),
                            backgroundColor: const Color(0xDDA7F3D0),
                            color: const Color(0xFF10B981),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currencyFormat.format(totalIncome),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL EXPENSES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C), letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (totalExpenses / maxTopAmount).clamp(0.0, 1.0),
                            backgroundColor: const Color(0xDDFECACA),
                            color: const Color(0xFFEF4444),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currencyFormat.format(totalExpenses),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Filter Owner & Chart Display Mode Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('FILTER OWNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: widget.selectedOwner,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          hint: const Text('All Owners', style: TextStyle(fontSize: 12)),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('All Owners', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Mathias', child: Text('Mathias', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Julia', child: Text('Julia', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Shared', child: Text('Shared', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: widget.onOwnerChanged,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CHART DISPLAY MODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: chartDisplayMode,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Show Expenses', child: Text('Show Expenses', style: TextStyle(fontSize: 11))),
                            DropdownMenuItem(value: 'Show Income', child: Text('Show Income', style: TextStyle(fontSize: 11))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => chartDisplayMode = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Labels Multi-Select Row
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chartDisplayMode == 'Show Income' ? 'INCOME LABELS' : 'EXPENSE LABELS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _showMultiSelectDialog(
                      context,
                      chartDisplayMode == 'Show Income' ? 'Select Income Labels' : 'Select Expense Labels',
                      widget.labels,
                      chartDisplayMode == 'Show Income' ? selectedIncomeLabels : selectedExpenseLabels,
                      (updatedIds) {
                        setState(() {
                          if (chartDisplayMode == 'Show Income') {
                            selectedIncomeLabels.clear();
                            selectedIncomeLabels.addAll(updatedIds);
                          } else {
                            selectedExpenseLabels.clear();
                            selectedExpenseLabels.addAll(updatedIds);
                          }
                        });
                      },
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                (chartDisplayMode == 'Show Income' ? selectedIncomeLabels.length : selectedExpenseLabels.length) == widget.labels.length
                                    ? 'All Labels'
                                    : '${chartDisplayMode == 'Show Income' ? selectedIncomeLabels.length : selectedExpenseLabels.length} selected',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Chart Rendering Section (Bar/Donut visualization)
              sortedEntries.isEmpty
                  ? const SizedBox(
                      height: 150,
                      child: Center(
                        child: Text('No data available for selected filters.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ),
                    )
                  : chartType == 'Bar'
                      ? Column(
                          children: [
                            ...List.generate(sortedEntries.length, (index) {
                              final entry = sortedEntries[index];
                              final barColor = paletteColors[index % paletteColors.length];
                              final double widthFactor = maxChartAmount > 0 ? (entry.value / maxChartAmount).clamp(0.02, 1.0) : 0.02;
                              final percentageShare = activeModeTotalSum > 0 ? (entry.value / activeModeTotalSum) * 100 : 0.0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 85,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            entry.key,
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${percentageShare.toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          const priceTextWidth = 75.0;
                                          final availableBarArea = constraints.maxWidth - priceTextWidth;
                                          final computedBarWidth = (availableBarArea * widthFactor).clamp(4.0, availableBarArea);

                                          return Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              SizedBox(
                                                width: computedBarWidth,
                                                child: Container(
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    color: barColor,
                                                    borderRadius: const BorderRadius.only(
                                                      topRight: Radius.circular(6),
                                                      bottomRight: Radius.circular(6),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: priceTextWidth,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerRight,
                                                  child: Text(
                                                    '\$${entry.value.toStringAsFixed(2)}',
                                                    textAlign: TextAlign.right,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF334155),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            Container(
                              margin: const EdgeInsets.only(left: 97),
                              child: Column(
                                children: [
                                  Container(height: 1, color: const Color(0xFFE2E8F0)),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('\$0', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                      Text('\$${(maxChartAmount * 0.5).toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                      Text('\$${maxChartAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            SizedBox(
                              height: 220,
                              child: PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions ||
                                            pieTouchResponse == null ||
                                            pieTouchResponse.touchedSection == null) {
                                          touchedPieIndex = null;
                                          return;
                                        }
                                        touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                      });
                                    },
                                  ),
                                  borderData: FlBorderData(show: false),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 45,
                                  sections: List.generate(sortedEntries.length, (index) {
                                    final entry = sortedEntries[index];
                                    final isTouched = index == touchedPieIndex;
                                    final radius = isTouched ? 65.0 : 55.0;
                                    final color = paletteColors[index % paletteColors.length];
                                    final percentage = activeModeTotalSum > 0 ? (entry.value / activeModeTotalSum) * 100 : 0.0;

                                    return PieChartSectionData(
                                      color: color,
                                      value: entry.value,
                                      title: '${percentage.toStringAsFixed(1)}%',
                                      radius: radius,
                                      titleStyle: TextStyle(
                                        fontSize: isTouched ? 13 : 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: List.generate(sortedEntries.length, (index) {
                                final entry = sortedEntries[index];
                                final color = paletteColors[index % paletteColors.length];
                                final percentage = activeModeTotalSum > 0 ? (entry.value / activeModeTotalSum) * 100 : 0.0;

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${entry.key}: ',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                      ),
                                      Text(
                                        '${currencyFormat.format(entry.value)} (${percentage.toStringAsFixed(1)}%)',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
              const SizedBox(height: 20),

              // Chart View Toggle (Moved directly under the chart)[cite: 15, 16]
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CHART VIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => chartType = 'Bar'),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: chartType == 'Bar' ? const Color(0xFF582F95) : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                              ),
                              child: Text(
                                'Bar',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: chartType == 'Bar' ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => chartType = 'Donut'),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: chartType == 'Donut' ? const Color(0xFF582F95) : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                              ),
                              child: Text(
                                'Donut',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: chartType == 'Donut' ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  void _showMultiSelectDialog(
    BuildContext context,
    String title,
    List<LabelModel> allLabels,
    Set<int> initialSelected,
    ValueChanged<Set<int>> onSelectionChanged,
  ) {
    Set<int> tempSelected = Set.from(initialSelected);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 300,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      title: const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: tempSelected.length == allLabels.length,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            tempSelected = allLabels.map((l) => l.id).toSet();
                          } else {
                            tempSelected.clear();
                          }
                        });
                      },
                    ),
                    const Divider(),
                    ...allLabels.map((label) {
                      return CheckboxListTile(
                        title: Text(label.name),
                        value: tempSelected.contains(label.id),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              tempSelected.add(label.id);
                            } else {
                              tempSelected.remove(label.id);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 88, 47, 149), foregroundColor: Colors.white),
                  onPressed: () {
                    onSelectionChanged(tempSelected);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}