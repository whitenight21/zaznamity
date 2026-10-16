// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final Set<String>? selectedPools;
  final String? selectedCurrency;
  final String? selectedType;
  final VoidCallback? onSelectStartDate;
  final VoidCallback? onSelectEndDate;
  final ValueChanged<int?>? onLabelChanged;
  final ValueChanged<Set<int>>? onLabelsChanged;
  final ValueChanged<String?>? onOwnerChanged;
  final ValueChanged<String?>? onPoolChanged;
  final ValueChanged<Set<String>>? onPoolsChanged;
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
    this.selectedPools,
    this.selectedCurrency,
    this.selectedType,
    this.onSelectStartDate,
    this.onSelectEndDate,
    this.onLabelChanged,
    this.onLabelsChanged,
    this.onOwnerChanged,
    this.onPoolChanged,
    this.onPoolsChanged,
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
  String _selectedLimit = '50';
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  
  late Set<int> _localSelectedLabels = {};
  late Set<String> _localSelectedPools = {};
  String? _localOwner;
  String? _localCurrency;
  String? _localType;
  DateTime? _localStartDate;
  DateTime? _localEndDate;
  bool _isInitialized = false;
  List<String> _activeCurrencies = ['USD'];
  String _dateRangeSetting = '15 Days';

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
    _loadPrefs();
    _initDefaults();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final primary = prefs.getString('primaryCurrency') ?? 'USD';
    final sec1 = prefs.getString('secondaryCurrency1');
    final sec2 = prefs.getString('secondaryCurrency2');
    final sec3 = prefs.getString('secondaryCurrency3');

    List<String> currencies = [primary];
    if (sec1 != null && sec1.isNotEmpty) currencies.add(sec1);
    if (sec2 != null && sec2.isNotEmpty) currencies.add(sec2);
    if (sec3 != null && sec3.isNotEmpty) currencies.add(sec3);

    if (mounted) {
      setState(() {
        _activeCurrencies = currencies.toSet().toList();
        _dateRangeSetting = prefs.getString('set_allZaznams_range') ?? '15 Days';
      });
    }
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _initDefaults() {
    if (_isInitialized) return;
    _localOwner = widget.selectedOwner;
    _localCurrency = widget.selectedCurrency;
    _localType = widget.selectedType;
    
    _localStartDate = widget.startDate;
    _localEndDate = widget.endDate;

    if (widget.selectedLabelIds != null) {
      _localSelectedLabels = Set.from(widget.selectedLabelIds!);
    } else if (widget.selectedLabelId != null) {
      _localSelectedLabels = {widget.selectedLabelId!};
    } else {
      _localSelectedLabels = widget.labels.map((l) => l.id).toSet();
    }

    if (widget.selectedPools != null) {
      _localSelectedPools = Set.from(widget.selectedPools!);
    } else if (widget.selectedPool != null) {
      _localSelectedPools = {widget.selectedPool!};
    } else {
      _localSelectedPools = widget.pools.toSet();
    }

    _isInitialized = true;
  }

  void _clearAllFilters() {
    setState(() {
      _localOwner = null;
      _localCurrency = null;
      _localType = null;
      _localStartDate = null;
      _localEndDate = null;
      _minAmountController.clear();
      _maxAmountController.clear();
      _localSelectedLabels = widget.labels.map((l) => l.id).toSet();
      _localSelectedPools = widget.pools.toSet();
    });

    if (widget.onOwnerChanged != null) widget.onOwnerChanged!(null);
    if (widget.onPoolChanged != null) widget.onPoolChanged!(null);
    if (widget.onPoolsChanged != null) widget.onPoolsChanged!(_localSelectedPools);
    if (widget.onCurrencyChanged != null) widget.onCurrencyChanged!(null);
    if (widget.onTypeChanged != null) widget.onTypeChanged!(null);
    if (widget.onClearDateFilter != null) {
      widget.onClearDateFilter!();
    }
    if (widget.onLabelsChanged != null) widget.onLabelsChanged!(_localSelectedLabels);
    if (widget.onLabelChanged != null) widget.onLabelChanged!(null);
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
          title: const Text('Delete Zaznam'),
          content: const Text('Are you sure you want to delete this zaznam?'),
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

  void _showPoolsMultiSelectDialog(BuildContext context) {
    Set<String> tempSelected = Set.from(_localSelectedPools);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Select Pools', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 300,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      title: const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: tempSelected.length == widget.pools.length,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            tempSelected = widget.pools.toSet();
                          } else {
                            tempSelected.clear();
                          }
                        });
                      },
                    ),
                    const Divider(),
                    ...widget.pools.map((pool) {
                      return CheckboxListTile(
                        title: Text(pool.toUpperCase()),
                        value: tempSelected.contains(pool),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              tempSelected.add(pool);
                            } else {
                              tempSelected.remove(pool);
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
                      _localSelectedPools = tempSelected;
                    });
                    if (widget.onPoolsChanged != null) {
                      widget.onPoolsChanged!(tempSelected);
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
    final now = DateTime.now();
    DateTime? activeStartDate = widget.startDate ?? _localStartDate;
    DateTime? activeEndDate = widget.endDate ?? _localEndDate;

    // Fully linked setting for default date range if no date filter is actively applied
    if (activeStartDate == null && activeEndDate == null) {
      if (_dateRangeSetting == '7 Days') {
        activeStartDate = now.subtract(const Duration(days: 7));
      } else if (_dateRangeSetting == '15 Days') {
        activeStartDate = now.subtract(const Duration(days: 15));
      } else if (_dateRangeSetting == '30 Days') {
        activeStartDate = now.subtract(const Duration(days: 30));
      } else if (_dateRangeSetting == 'Current Month') {
        activeStartDate = DateTime(now.year, now.month, 1);
      }
    }

    final bool hasDateFilter = widget.startDate != null || widget.endDate != null || _localStartDate != null;

    final activeOwner = widget.selectedOwner ?? _localOwner;
    final activeCurrency = widget.selectedCurrency ?? _localCurrency;
    final activeType = widget.selectedType ?? _localType;

    final double? minAmount = double.tryParse(_minAmountController.text);
    final double? maxAmount = double.tryParse(_maxAmountController.text);

    final filteredTransactions = widget.transactions.where((tx) {
      if (activeOwner != null && activeOwner.isNotEmpty && activeOwner != 'All Owners' && tx.owner != activeOwner) return false;
      if (_localSelectedPools.isNotEmpty && !_localSelectedPools.contains(tx.pool)) return false;
      if (activeCurrency != null && tx.currencyCode != activeCurrency && (tx.currencyCode.isNotEmpty || activeCurrency != 'USD')) return false;
      if (activeType != null && tx.type != activeType) return false;

      if (minAmount != null && tx.amount < minAmount) return false;
      if (maxAmount != null && tx.amount > maxAmount) return false;

      final labelObj = widget.labels.firstWhere(
        (l) => l.id == tx.labelId,
        orElse: () => LabelModel(id: 0, name: 'General', color: '#4338CA'),
      );
      if (_localSelectedLabels.isNotEmpty && !_localSelectedLabels.contains(labelObj.id)) {
        return false;
      }

      final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
      if (activeStartDate != null) {
        final startClean = DateTime(activeStartDate.year, activeStartDate.month, activeStartDate.day);
        if (txDate.isBefore(startClean)) return false;
      }
      if (activeEndDate != null) {
        final endOfDay = DateTime(activeEndDate.year, activeEndDate.month, activeEndDate.day, 23, 59, 59);
        if (txDate.isAfter(endOfDay)) return false;
      }

      return true;
    }).toList();

    final int totalCount = filteredTransactions.length;
    int displayLimit = totalCount;
    if (_selectedLimit != 'All') {
      displayLimit = int.tryParse(_selectedLimit) ?? 50;
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Text(
                            'ALL ZAZNAMS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 88, 47, 149),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              hasDateFilter ? 'Custom' : _dateRangeSetting,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
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
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: hasDateFilter ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                            fontWeight: hasDateFilter ? FontWeight.bold : FontWeight.normal,
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
                                onTap: () {
                                  setState(() {
                                    _localStartDate = null;
                                    _localEndDate = null;
                                  });
                                  if (widget.onClearDateFilter != null) {
                                    widget.onClearDateFilter!();
                                  }
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
                    child: InkWell(
                      onTap: () => _showPoolsMultiSelectDialog(context),
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
                                  const Icon(Icons.layers_outlined, size: 16, color: Color(0xFF582F95)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _localSelectedPools.length == widget.pools.length
                                            ? 'All Pools'
                                            : '${_localSelectedPools.length} selected',
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
                ],
              ),
              const SizedBox(height: 12),

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
                            ..._activeCurrencies.map((c) => DropdownMenuItem<String?>(
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
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: fullWidth * 0.4,
                    child: TextField(
                      controller: _minAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.attach_money_rounded, size: 16, color: Color(0xFF582F95)),
                        hintText: 'Min',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fullWidth * 0.4,
                    child: TextField(
                      controller: _maxAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.attach_money_rounded, size: 16, color: Color(0xFF582F95)),
                        hintText: 'Max',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fullWidth * 0.2,
                    height: 42,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: _clearAllFilters,
                      child: const Text('Clear Filters', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${displayedTransactions.length} of $totalCount found',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Row(
                    children: [
                      const Text('Show: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLimit,
                          isDense: true,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          dropdownColor: Colors.white,
                          items: ['25', '50', '100', '150', '200', 'All']
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
              const Divider(color: Color(0xFFE2E8F0)),
              
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
                        
                        final bool timePassed = txDate.isBefore(DateTime.now());
                        final bool isFuture = txDate.isAfter(DateTime.now());

                        return Container(
                          decoration: BoxDecoration(
                            color: isFuture && !timePassed ? const Color(0xFFF1F5F9) : Colors.transparent,
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
                                    isFuture && !timePassed ? 'PENDING' : 'CONFIRMED',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: isFuture && !timePassed
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF10B981),
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