import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class TransactionHistoryCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
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
    required this.owners,
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
  String _selectedLimit = '50'; // Default limit options: '50', '100', '150', '200', 'All'

  void _showDeleteConfirmation(BuildContext context, int transactionId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Transaction'),
          content: const Text('Are you sure you want to delete this transaction?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDeleteTransaction(transactionId);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDateFilter = widget.startDate != null || widget.endDate != null;
    final int totalCount = widget.transactions.length;

    // Apply pagination limit based on selection
    int displayLimit = totalCount;
    if (_selectedLimit != 'All') {
      displayLimit = int.tryParse(_selectedLimit) ?? 50;
    }
    final displayedTransactions = widget.transactions.take(displayLimit).toList();

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
                        'ALL ZAZNAMS',
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

              // Labels Multi-Select / Picker Row
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LABEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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
              const SizedBox(height: 16),

              // Owners (Left) & Date Range Picker with Separate Clear Button (Right)
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
                                  const DropdownMenuItem(value: null, child: Text('All Owners')),
                                  ...widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o))),
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
                                onTap: widget.onSelectStartDate,
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
                                          widget.startDate != null && widget.endDate != null
                                              ? '${DateFormat('MM/dd').format(widget.startDate!)} - ${DateFormat('MM/dd').format(widget.endDate!)}'
                                              : widget.startDate != null
                                                  ? DateFormat('MM/dd').format(widget.startDate!)
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
              const SizedBox(height: 14),

              // Yellow Box Area: Showing X of Y Zaznams + Limit Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7), // Light amber/yellow background matching theme
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${displayedTransactions.length} of $totalCount Zaznams',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    Row(
                      children: [
                        const Text('Show: ', style: TextStyle(fontSize: 11, color: Color(0xFF92400E))),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLimit,
                            isDense: true,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            dropdownColor: const Color(0xFFFEF3C7),
                            items: ['50', '100', '150', '200', 'All']
                                .map((lim) => DropdownMenuItem(value: lim, child: Text(lim)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedLimit = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE2E8F0)),
              
              // Transactions List View
              displayedTransactions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('No transactions found.', style: TextStyle(color: Color(0xFF94A3B8))),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedTransactions.length,
                      separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                      itemBuilder: (context, index) {
                        final tx = displayedTransactions[index];
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                        icon: const Icon(Icons.edit, size: 16, color: Color(0xFF64748B)),
                                        tooltip: 'Edit',
                                        onPressed: () => widget.onEditTransaction(tx),
                                      ),
                                      const SizedBox(width: 2),
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                        icon: const Icon(Icons.delete, size: 16, color: Color(0xFFDC2626)),
                                        tooltip: 'Delete',
                                        onPressed: () => _showDeleteConfirmation(context, tx.id!),
                                      ),
                                    ],
                                  ),
                                  if (!isConfirmed) ...[
                                    const SizedBox(height: 4),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFD1FAE5),
                                        foregroundColor: const Color(0xFF047857),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        minimumSize: Size.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      onPressed: () => widget.onConfirmTransaction(tx),
                                      child: const Text('Confirm', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
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
      },
    );
  }
}