import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class SelectedLabelFocusCard extends StatelessWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? selectedOwner;
  final int? selectedLabelId;
  final Function(int?) onLabelChanged;
  final Function(String?) onOwnerChanged;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final VoidCallback onClearDateFilter;
  
  // Card layout management properties
  final bool isWide;
  final VoidCallback onToggleWidth;
  final VoidCallback onHide;
  
  // Callback for jumping to transaction history with filter applied
  final Function(int? labelId, String? owner, DateTime? start, DateTime? end)? onJumpToHistory;

  const SelectedLabelFocusCard({
    super.key,
    required this.transactions,
    required this.labels,
    required this.owners,
    this.startDate,
    this.endDate,
    this.selectedOwner,
    this.selectedLabelId,
    required this.onLabelChanged,
    required this.onOwnerChanged,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onClearDateFilter,
    required this.isWide,
    required this.onToggleWidth,
    required this.onHide,
    this.onJumpToHistory,
  });

  @override
  Widget build(BuildContext context) {
    final filteredTxs = transactions.where((tx) {
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
      if (selectedLabelId != null && tx.labelId != selectedLabelId) return false;
      if (selectedOwner != null && tx.owner != selectedOwner) return false;
      return true;
    }).toList();

    double inflow = 0;
    double outflow = 0;
    for (var tx in filteredTxs) {
      if (tx.isConfirmed == 1) {
        if (tx.type == 'income') {
          inflow += tx.amount;
        } else {
          outflow += tx.amount;
        }
      }
    }
    double net = inflow - outflow;

    final allCardFilteredTxs = transactions.where((tx) {
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
      if (selectedOwner != null && tx.owner != selectedOwner) return false;
      return true;
    }).toList();

    double totalGlobalInflow = 0;
    double totalGlobalOutflow = 0;
    for (var tx in allCardFilteredTxs) {
      if (tx.isConfirmed == 1) {
        if (tx.type == 'income') {
          totalGlobalInflow += tx.amount;
        } else {
          totalGlobalOutflow += tx.amount;
        }
      }
    }

    double outflowPercentage = totalGlobalOutflow > 0 ? (outflow / totalGlobalOutflow) * 100 : 0.0;
    double inflowPercentage = totalGlobalInflow > 0 ? (inflow / totalGlobalInflow) * 100 : 0.0;

    final sortedFilteredTxs = List<TransactionModel>.from(filteredTxs)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a.createdAt) ?? DateTime(0);
        final dateB = DateTime.tryParse(b.createdAt) ?? DateTime(0);
        return dateB.compareTo(dateA);
      });
    final recentTransactions = sortedFilteredTxs.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
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
                    'SINGLE-LABEL ANALYSIS',
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

          // Date Selection Row
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onSelectStartDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'START DATE',
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
                      labelText: 'END DATE',
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
          const SizedBox(height: 16),

          // Dropdowns for Label and Owner selection
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LABEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedLabelId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All Labels', style: TextStyle(fontSize: 12))),
                        ...labels.map((l) => DropdownMenuItem<int?>(value: l.id, child: Text(l.name, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: onLabelChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OWNER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedOwner,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All Owners', style: TextStyle(fontSize: 12))),
                        ...owners.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: onOwnerChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Net balance & Yellow Box modifications ("View All Zaznams" centered above amount row)
          Padding(
            padding: const EdgeInsets.only(left: 3.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NET BALANCE',
                      style: TextStyle(
                        color: Color(0xFF582F95),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${net.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF582F95),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () {
                      if (onJumpToHistory != null) {
                        onJumpToHistory!(selectedLabelId, selectedOwner, startDate, endDate);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Tooltip(
                      message: 'View in All Zaznams',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        color: Colors.transparent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center, // Centered above the amount row
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Display below all',
                              style: TextStyle(
                                color: Color(0xFF582F95),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${filteredTxs.length} Zaznams',
                                  style: const TextStyle(
                                    color: Color(0xFF582F95),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF582F95)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Inflow vs Outflow breakdown rows (Fonts increased by 1: label 11, amount 17, subtext 11)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('INFLOWS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text('+\$${inflow.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                  const SizedBox(height: 2),
                  Text('${inflowPercentage.toStringAsFixed(1)}% of total', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              Container(height: 35, width: 1, color: const Color(0xFFE2E8F0)),
              Column(
                children: [
                  const Text('OUTFLOWS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text('-\$${outflow.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  const SizedBox(height: 2),
                  Text('${outflowPercentage.toStringAsFixed(1)}% of total', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          
          if (recentTransactions.isNotEmpty) ...[
            const SizedBox(height: 20),
            // Brown box: list items start right below the title
            const Text(
              'RECENT ACTIVITY',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentTransactions.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                itemBuilder: (context, index) {
                  final tx = recentTransactions[index];
                  final txDate = DateTime.tryParse(tx.createdAt);
                  final formattedTxDate = txDate != null ? DateFormat('MM/dd').format(txDate) : '';
                  final isIncome = tx.type == 'income';
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                formattedTxDate,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tx.description.isNotEmpty ? tx.description : 'No description',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${isIncome ? '+' : '-'}\$${tx.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}