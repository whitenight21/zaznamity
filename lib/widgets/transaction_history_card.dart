import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class TransactionHistoryCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? selectedLabelId;
  final String? selectedOwner;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final ValueChanged<int?> onLabelChanged;
  final ValueChanged<String?> onOwnerChanged;
  final VoidCallback onClearDateFilter;
  final Function(int) onDeleteTransaction;
  final Function(TransactionModel) onEditTransaction;
  final Function(TransactionModel) onConfirmTransaction;
  final VoidCallback? onHide;
  final bool isWide;
  final VoidCallback? onToggleWidth;

  const TransactionHistoryCard({
    super.key,
    required this.transactions,
    required this.labels,
    this.startDate,
    this.endDate,
    this.selectedLabelId,
    this.selectedOwner,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.onLabelChanged,
    required this.onOwnerChanged,
    required this.onClearDateFilter,
    required this.onDeleteTransaction,
    required this.onEditTransaction,
    required this.onConfirmTransaction,
    this.onHide,
    this.isWide = false,
    this.onToggleWidth,
  });

  @override
  State<TransactionHistoryCard> createState() => _TransactionHistoryCardState();
}

class _TransactionHistoryCardState extends State<TransactionHistoryCard> {
  @override
  Widget build(BuildContext context) {
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
                    'ZAZNAM HISTORY',
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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: widget.selectedOwner,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      hint: const Text('All Owners', style: TextStyle(fontSize: 13)),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Owners', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Mathias', child: Text('Mathias', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Julia', child: Text('Julia', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Shared', child: Text('Shared', style: TextStyle(fontSize: 13))),
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
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: widget.selectedLabelId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      hint: const Text('All Labels', style: TextStyle(fontSize: 13)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Labels', style: TextStyle(fontSize: 13))),
                        ...widget.labels.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name, style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: widget.onLabelChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Updated Date Pickers matching the reference design style
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: widget.onSelectStartDate,
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
                      widget.startDate != null ? DateFormat('MM/dd/yyyy').format(widget.startDate!) : 'All',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: widget.onSelectEndDate,
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
                      widget.endDate != null ? DateFormat('MM/dd/yyyy').format(widget.endDate!) : 'All',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ),
                ),
              ),
              if (widget.startDate != null || widget.endDate != null || widget.selectedLabelId != null || widget.selectedOwner != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                  onPressed: widget.onClearDateFilter,
                  tooltip: 'Reset Filters',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE2E8F0)),
          widget.transactions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No transactions found.', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.transactions.length,
                  separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                  itemBuilder: (context, index) {
                    final tx = widget.transactions[index];
                    final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
                    final formattedDate = DateFormat('MMM d, yyyy hh:mm a').format(txDate);
                    
                    final labelObj = widget.labels.firstWhere(
                      (l) => l.id == tx.labelId,
                      orElse: () => LabelModel(id: 0, name: 'General', color: '#4338CA'),
                    );

                    final isIncome = tx.type == 'income';
                    final amountString = '${isIncome ? '+' : '-'}\$${tx.amount.toStringAsFixed(2)}';
                    final isConfirmed = tx.isConfirmed == 1;
                    final isFuture = txDate.isAfter(DateTime.now());

                    return Container(
                      decoration: BoxDecoration(
                        color: isFuture ? const Color(0xFFF1F5F9) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.description.isNotEmpty ? tx.description : 'Unnamed Transaction',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(formattedDate, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    const Text('•', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                    Text(tx.owner, style: const TextStyle(fontSize: 10, color: Color(0xFF4338CA), fontWeight: FontWeight.w500)),
                                    const Text('•', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        labelObj.name,
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  amountString,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isFuture
                                    ? 'SCHEDULED'
                                    : (isConfirmed ? 'CONFIRMED' : 'SCHEDULED'),
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isFuture
                                      ? const Color(0xFF64748B)
                                      : (isConfirmed ? const Color(0xFF10B981) : const Color(0xFFD97706)),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Wrap(
                            spacing: 2,
                            runSpacing: 4,
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (!isConfirmed)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD1FAE5),
                                    foregroundColor: const Color(0xFF047857),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  onPressed: () => widget.onConfirmTransaction(tx),
                                  child: const Text('Confirm', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.edit, size: 16, color: Color(0xFF64748B)),
                                tooltip: 'Edit',
                                onPressed: () => widget.onEditTransaction(tx),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.delete, size: 16, color: Color(0xFFDC2626)),
                                tooltip: 'Delete',
                                onPressed: () => widget.onDeleteTransaction(tx.id!),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}