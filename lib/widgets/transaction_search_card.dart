import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class TransactionSearchCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
  final List<String> pools;
  
  final Function(int) onDeleteTransaction;
  final Function(TransactionModel) onEditTransaction;
  final Function(TransactionModel) onConfirmTransaction;
  
  final bool isWide;
  final VoidCallback onToggleWidth;
  final VoidCallback onHide;

  const TransactionSearchCard({
    super.key,
    required this.transactions,
    required this.labels,
    required this.owners,
    this.pools = const [],
    required this.onDeleteTransaction,
    required this.onEditTransaction,
    required this.onConfirmTransaction,
    required this.isWide,
    required this.onToggleWidth,
    required this.onHide,
  });

  @override
  State<TransactionSearchCard> createState() => _TransactionSearchCardState();
}

class _TransactionSearchCardState extends State<TransactionSearchCard> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  Timer? _debounceTimer;

  int? _selectedLabelId;
  String? _selectedOwner;
  String? _selectedType;
  String? _selectedPool;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedLimit = '50';
  String _debouncedQuery = '';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _debouncedQuery = val.trim().toLowerCase();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Default to showing no transactions if no search text or filters are active
    final bool hasActiveFilter = _debouncedQuery.isNotEmpty ||
        _selectedLabelId != null ||
        _selectedOwner != null ||
        _selectedType != null ||
        _selectedPool != null ||
        _startDate != null ||
        _endDate != null ||
        _minAmountController.text.isNotEmpty ||
        _maxAmountController.text.isNotEmpty;

    final filteredTransactions = !hasActiveFilter
        ? <TransactionModel>[]
        : widget.transactions.where((tx) {
            if (_debouncedQuery.isNotEmpty) {
              final desc = tx.description.toLowerCase();
              if (!desc.contains(_debouncedQuery)) return false;
            }
            if (_selectedLabelId != null && tx.labelId != _selectedLabelId) return false;
            if (_selectedOwner != null && tx.owner != _selectedOwner) return false;
            if (_selectedType != null && tx.type != _selectedType) return false;
            if (_selectedPool != null && tx.pool != _selectedPool) return false;

            final txDate = DateTime.tryParse(tx.createdAt);
            if (txDate != null) {
              if (_startDate != null) {
                final startClean = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
                if (txDate.isBefore(startClean)) return false;
              }
              if (_endDate != null) {
                final endClean = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
                if (txDate.isAfter(endClean)) return false;
              }
            }

            final minAmt = double.tryParse(_minAmountController.text);
            if (minAmt != null && tx.amount < minAmt) return false;

            final maxAmt = double.tryParse(_maxAmountController.text);
            if (maxAmt != null && tx.amount > maxAmt) return false;

            return true;
          }).toList();

    final int totalFound = filteredTransactions.length;
    int displayLimit = totalFound;
    if (_selectedLimit != 'All') {
      displayLimit = int.tryParse(_selectedLimit) ?? 50;
    }
    final displayedTransactions = filteredTransactions.take(displayLimit).toList();

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
                    'SEARCH ZAZNAMS',
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
                        onPressed: widget.onToggleWidth,
                        icon: Icon(
                          widget.isWide ? Icons.fullscreen_exit : Icons.fullscreen,
                          size: 18,
                        ),
                        tooltip: widget.isWide ? 'Narrow' : 'Wide',
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
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'SEARCH DESCRIPTION',
              labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              hintText: 'Type keywords...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LABEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedLabelId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All Labels', style: TextStyle(fontSize: 12))),
                        ...widget.labels.map((l) => DropdownMenuItem<int?>(value: l.id, child: Text(l.name, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: (val) => setState(() => _selectedLabelId = val),
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
                      initialValue: _selectedOwner,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All Owners', style: TextStyle(fontSize: 12))),
                        ...widget.owners.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: (val) => setState(() => _selectedOwner = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TYPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(value: null, child: Text('All Types', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem<String?>(value: 'income', child: Text('Income', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem<String?>(value: 'expense', child: Text('Expense', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) => setState(() => _selectedType = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('POOL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedPool,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All Pools', style: TextStyle(fontSize: 12))),
                        ...widget.pools.map((p) => DropdownMenuItem<String?>(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: (val) => setState(() => _selectedPool = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'START DATE',
                      labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                    child: Text(
                      _startDate != null ? DateFormat('MM/dd/yyyy').format(_startDate!) : 'All',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'END DATE',
                      labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                    child: Text(
                      _endDate != null ? DateFormat('MM/dd/yyyy').format(_endDate!) : 'All',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ),
                ),
              ),
              if (_startDate != null || _endDate != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => setState(() {
                    _startDate = null;
                    _endDate = null;
                  }),
                  tooltip: 'Clear Dates',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'MIN AMOUNT (\$)',
                    labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    hintText: '0.00',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'MAX AMOUNT (\$)',
                    labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    hintText: 'Any',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${displayedTransactions.length} of $totalFound found',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
              Row(
                children: [
                  const Text('Show: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLimit,
                      isDense: true,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
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
          const SizedBox(height: 8),
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: !hasActiveFilter
                ? const Center(
                    child: Text(
                      'Enter search query or select filters above to show results.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  )
                : displayedTransactions.isEmpty
                    ? const Center(
                        child: Text(
                          'No matching transactions found.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      )
                    : ListView.separated(
                        cacheExtent: 1000,
                        itemCount: displayedTransactions.length,
                        separatorBuilder: (context, index) => const Divider(color: Color(0xFFE2E8F0), height: 1),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(formattedDate, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                                          const Text('•', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                                          Text(tx.owner, style: const TextStyle(fontSize: 9, color: Color(0xFF4338CA), fontWeight: FontWeight.w500)),
                                          const Text('•', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              labelObj.name,
                                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
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
                                    Text(
                                      amountString,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isFuture ? 'SCHEDULED' : (isConfirmed ? 'CONFIRMED' : 'SCHEDULED'),
                                      style: TextStyle(
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold,
                                        color: isFuture
                                            ? const Color(0xFF64748B)
                                            : (isConfirmed ? const Color(0xFF10B981) : const Color(0xFFD97706)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Wrap(
                                  spacing: 2,
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (!isConfirmed)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFD1FAE5),
                                          foregroundColor: const Color(0xFF047857),
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          minimumSize: Size.zero,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        ),
                                        onPressed: () => widget.onConfirmTransaction(tx),
                                        child: const Text('Confirm', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      icon: const Icon(Icons.edit, size: 14, color: Color(0xFF64748B)),
                                      tooltip: 'Edit',
                                      onPressed: () => widget.onEditTransaction(tx),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                      icon: const Icon(Icons.delete, size: 14, color: Color(0xFFDC2626)),
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
          ),
        ],
      ),
    );
  }
}