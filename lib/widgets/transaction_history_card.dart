// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class TransactionHistoryCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
  final List<String> pools;
  final List<String> availableCurrencies;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? selectedLabelId;
  final Set<int>? selectedLabelIds;
  final String? selectedOwner;
  final String? selectedPool;
  final String? selectedCurrency;
  final String? selectedType;
  final VoidCallback? onSelectStartDate;
  final VoidCallback? onSelectEndDate;
  final ValueChanged<int?>? onLabelChanged;
  final ValueChanged<Set<int>>? onLabelsChanged;
  final ValueChanged<String?>? onOwnerChanged;
  final ValueChanged<String?>? onPoolChanged;
  final ValueChanged<String?>? onCurrencyChanged;
  final ValueChanged<String?>? onTypeChanged;
  final VoidCallback? onClearDateFilter;
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
    this.pools = const [],
    this.availableCurrencies = const ['USD'],
    this.startDate,
    this.endDate,
    this.selectedLabelId,
    this.selectedLabelIds,
    this.selectedOwner,
    this.selectedPool,
    this.selectedCurrency,
    this.selectedType,
    this.onSelectStartDate,
    this.onSelectEndDate,
    this.onLabelChanged,
    this.onLabelsChanged,
    this.onOwnerChanged,
    this.onPoolChanged,
    this.onCurrencyChanged,
    this.onTypeChanged,
    this.onClearDateFilter,
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
  String _selectedLimit = '25';
  
  // Internal state fallbacks for seamless dropdown interactivity
  late Set<int> _localSelectedLabels = {};
  String? _localOwner;
  String? _localPool;
  String? _localCurrency;
  String? _localType;
  DateTime? _localStartDate;
  DateTime? _localEndDate;
  bool _isInitialized = false;

  final Map<String, String> _currencyFlags = {
    'USD': '🇺🇸',
    'EUR': '🇪🇺',
    'JPY': '🇯🇵',
    'GBP': '🇬🇧',
    'CNY': '🇨🇳',
    'AUD': '🇦🇺',
    'CAD': '🇨🇦',
    'CHF': '🇨🇭',
    'HKD': '🇭🇰',
    'SGD': '🇸🇬',
  };

  @override
  void initState() {
    super.initState();
    _initDefaults();
  }

  void _initDefaults() {
    if (_isInitialized) return;
    _localOwner = widget.selectedOwner;
    _localPool = widget.selectedPool;
    _localCurrency = widget.selectedCurrency;
    _localType = widget.selectedType;
    
    // Default date range to today if not provided
    final now = DateTime.now();
    _localStartDate = widget.startDate ?? DateTime(now.year, now.month, now.day);
    _localEndDate = widget.endDate ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (widget.selectedLabelIds != null) {
      _localSelectedLabels = Set.from(widget.selectedLabelIds!);
    } else if (widget.selectedLabelId != null) {
      _localSelectedLabels = {widget.selectedLabelId!};
    } else {
      _localSelectedLabels = widget.labels.map((l) => l.id).toSet();
    }
    _isInitialized = true;
  }

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      default: return '\$';
    }
  }

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

  void _showMultiSelectDialog(BuildContext context) {
    Set<int> tempSelected = Set.from(_localSelectedLabels);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Select Labels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 300,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      title: const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: tempSelected.length == widget.labels.length,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            tempSelected = widget.labels.map((l) => l.id).toSet();
                          } else {
                            tempSelected.clear();
                          }
                        });
                      },
                    ),
                    const Divider(),
                    ...widget.labels.map((label) {
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
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF582F95), foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() {
                      _localSelectedLabels = tempSelected;
                    });
                    if (widget.onLabelsChanged != null) {
                      widget.onLabelsChanged!(tempSelected);
                    }
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

  @override
  Widget build(BuildContext context) {
    final activeStartDate = widget.startDate ?? _localStartDate;
    final activeEndDate = widget.endDate ?? _localEndDate;
    final bool hasDateFilter = activeStartDate != null || activeEndDate != null;

    final activeOwner = widget.selectedOwner ?? _localOwner;
    final activePool = widget.selectedPool ?? _localPool;
    final activeCurrency = widget.selectedCurrency ?? _localCurrency;
    final activeType = widget.selectedType ?? _localType;

    // Filter transactions based on selected criteria
    final filteredTransactions = widget.transactions.where((tx) {
      if (activeOwner != null && tx.owner != activeOwner) return false;
      if (activePool != null && tx.pool != activePool) return false;
      if (activeCurrency != null && tx.currencyCode != activeCurrency && (tx.currencyCode.isNotEmpty || activeCurrency != 'USD')) return false;
      if (activeType != null && tx.type != activeType) return false;

      final labelObj = widget.labels.firstWhere(
        (l) => l.id == tx.labelId,
        orElse: () => LabelModel(id: 0, name: 'General', color: '#4338CA'),
      );
      if (_localSelectedLabels.isNotEmpty && !_localSelectedLabels.contains(labelObj.id)) {
        return false;
      }

      final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
      if (activeStartDate != null && txDate.isBefore(activeStartDate)) return false;
      if (activeEndDate != null) {
        final endOfDay = DateTime(activeEndDate.year, activeEndDate.month, activeEndDate.day, 23, 59, 59);
        if (txDate.isAfter(endOfDay)) return false;
      }

      return true;
    }).toList();

    final int totalCount = filteredTransactions.length;
    int displayLimit = totalCount;
    if (_selectedLimit != 'All') {
      displayLimit = int.tryParse(_selectedLimit) ?? 25;
    }
    final displayedTransactions = filteredTransactions.take(displayLimit).toList();

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

              // Row 1: Owners (Left) & Date Range Picker (Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                              child: DropdownButton<String?>(
                                value: activeOwner,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                hint: const Text('All Owners', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF64748B))),
                                items: [
                                  const DropdownMenuItem<String?>(value: null, child: Text('All Owners')),
                                  ...widget.owners.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o))),
                                ],
                                onChanged: (val) {
                                  setState(() => _localOwner = val);
                                  if (widget.onOwnerChanged != null) widget.onOwnerChanged!(val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                                onTap: widget.onSelectStartDate ?? () async {
                                  final picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                    initialDateRange: activeStartDate != null && activeEndDate != null
                                        ? DateTimeRange(start: activeStartDate, end: activeEndDate)
                                        : null,
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _localStartDate = picked.start;
                                      _localEndDate = picked.end;
                                    });
                                  }
                                },
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
                                          activeStartDate != null && activeEndDate != null
                                              ? '${DateFormat('MM/dd').format(activeStartDate)} - ${DateFormat('MM/dd').format(activeEndDate)}'
                                              : 'Select Date Range',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF1E293B),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
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
                                onTap: widget.onClearDateFilter ?? () {
                                  setState(() {
                                    _localStartDate = null;
                                    _localEndDate = null;
                                  });
                                },
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

              // Row 2: All Labels (Multi-select checkmarks) & All Pools
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: boxWidth,
                    child: InkWell(
                      onTap: () => _showMultiSelectDialog(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.label_outline_rounded, size: 16, color: Color(0xFF582F95)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _localSelectedLabels.length == widget.labels.length
                                            ? 'All Labels'
                                            : '${_localSelectedLabels.length} selected',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                          const Icon(Icons.layers_outlined, size: 16, color: Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: activePool,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                hint: const Text('All Pools', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF64748B))),
                                items: [
                                  const DropdownMenuItem<String?>(value: null, child: Text('All Pools')),
                                  ...widget.pools.map((p) => DropdownMenuItem<String?>(value: p, child: Text(p.toUpperCase()))),
                                ],
                                onChanged: (val) {
                                  setState(() => _localPool = val);
                                  if (widget.onPoolChanged != null) widget.onPoolChanged!(val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: All Currencies & All Types
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: activeCurrency,
                          isDense: true,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          hint: const Row(
                            children: [
                              Icon(Icons.public, size: 14, color: Color(0xFF582F95)),
                              SizedBox(width: 6),
                              Text('All Currencies', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF64748B))),
                            ],
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null, 
                              child: Row(
                                children: [
                                  Icon(Icons.public, size: 14, color: Color(0xFF582F95)),
                                  SizedBox(width: 6),
                                  Text('All Currencies'),
                                ],
                              ),
                            ),
                            ...widget.availableCurrencies.map((c) => DropdownMenuItem<String?>(
                              value: c, 
                              child: Row(
                                children: [
                                  Text(_currencyFlags[c] ?? '💵', style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(c),
                                ],
                              ),
                            )),
                          ],
                          onChanged: (val) {
                            setState(() => _localCurrency = val);
                            if (widget.onCurrencyChanged != null) widget.onCurrencyChanged!(val);
                          },
                        ),
                      ),
                    ),
                  ),
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
                          const Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: activeType,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                hint: const Text('All Types', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF64748B))),
                                items: const [
                                  DropdownMenuItem<String?>(value: null, child: Text('All Types')),
                                  DropdownMenuItem<String?>(value: 'income', child: Text('Income')),
                                  DropdownMenuItem<String?>(value: 'expense', child: Text('Expense')),
                                ],
                                onChanged: (val) {
                                  setState(() => _localType = val);
                                  if (widget.onTypeChanged != null) widget.onTypeChanged!(val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Showing X of Y Zaznams + Limit Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${displayedTransactions.length} of $totalCount Zaznams',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF582F95),
                      ),
                    ),
                    Row(
                      children: [
                        const Text('Show: ', style: TextStyle(fontSize: 11, color: Color(0xFF582F95))),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLimit,
                            isDense: true,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF582F95)),
                            dropdownColor: const Color(0xFFF8FAFC),
                            items: ['10', '25', '50', '100', 'All']
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
              
              // Transactions ListView
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
                      cacheExtent: 1000,
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

                        final currencyCode = tx.currencyCode.isNotEmpty ? tx.currencyCode : 'USD';
                        final flag = _currencyFlags[currencyCode] ?? '🇺🇸';
                        final symbol = _getCurrencySymbol(currencyCode);

                        final isIncome = tx.type == 'income';
                        final amountString = '${isIncome ? '+' : '-'}$symbol${tx.amount.toStringAsFixed(2)}';
                        final isConfirmed = tx.isConfirmed == 1;
                        final isFuture = txDate.isAfter(DateTime.now());

                        return Container(
                          decoration: BoxDecoration(
                            color: isFuture ? const Color(0xFFF1F5F9) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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
                                        const Text('•', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                        Text('$flag $currencyCode', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
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
                                        ? 'PENDING'
                                        : (isConfirmed ? 'CONFIRMED' : 'PENDING'),
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
                              const SizedBox(width: 4),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(1),
                                        icon: const Icon(Icons.edit, size: 16, color: Color(0xFF64748B)),
                                        tooltip: 'Edit',
                                        onPressed: () => widget.onEditTransaction(tx),
                                      ),
                                      const SizedBox(width: 0),
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(1),
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