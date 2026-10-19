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
  bool _isZaznamityMode = true;

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
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
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
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _activeCurrencies = currencies.toSet().toList();
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
    
    // Default to null so the date range box starts completely empty
    _localStartDate = widget.startDate;
    _localEndDate = widget.endDate;

    final allLabelIds = <int>{};
    for (var l in widget.labels) {
      allLabelIds.add(l.id);
    }
    for (var tx in widget.transactions) {
      allLabelIds.add(tx.labelId);
    }

    if (widget.selectedLabelIds != null) {
      _localSelectedLabels = Set.from(widget.selectedLabelIds!);
    } else if (widget.selectedLabelId != null) {
      _localSelectedLabels = {widget.selectedLabelId!};
    } else {
      _localSelectedLabels = allLabelIds;
    }

    final allPools = <String>{...widget.pools};
    for (var tx in widget.transactions) {
      if (tx.pool.isNotEmpty) allPools.add(tx.pool);
    }

    if (widget.selectedPools != null) {
      _localSelectedPools = Set.from(widget.selectedPools!);
    } else if (widget.selectedPool != null) {
      _localSelectedPools = {widget.selectedPool!};
    } else {
      _localSelectedPools = allPools;
    }

    _isInitialized = true;
  }

  void _clearAllFilters() {
    final allLabelIds = <int>{};
    for (var l in widget.labels) {
      allLabelIds.add(l.id);
    }
    for (var tx in widget.transactions) {
      allLabelIds.add(tx.labelId);
    }

    final allPools = <String>{...widget.pools};
    for (var tx in widget.transactions) {
      if (tx.pool.isNotEmpty) allPools.add(tx.pool);
    }

    setState(() {
      _localOwner = null;
      _localCurrency = null;
      _localType = null;
      _localStartDate = null;
      _localEndDate = null;
      _minAmountController.clear();
      _maxAmountController.clear();
      _localSelectedLabels = allLabelIds;
      _localSelectedPools = allPools;
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
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          title: Text('Delete Zaznam', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
          content: Text('Really delete this zaznam?', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
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
              backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Select Labels', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
              content: SizedBox(
                width: 300,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      title: Text('Select All', style: TextStyle(fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                      value: tempSelected.length == widget.labels.length,
                      checkColor: _isZaznamityMode ? Colors.white : null,
                      activeColor: _isZaznamityMode ? const Color(0xFFA855F7) : null,
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
                    Divider(color: _isZaznamityMode ? Colors.white24 : const Color(0xFFE2E8F0)),
                    ...widget.labels.map((label) {
                      return CheckboxListTile(
                        title: Text(label.name, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
                        value: tempSelected.contains(label.id),
                        checkColor: _isZaznamityMode ? Colors.white : null,
                        activeColor: _isZaznamityMode ? const Color(0xFFA855F7) : null,
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
                  child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), foregroundColor: Colors.white),
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
    final availablePoolsList = widget.pools.isNotEmpty 
        ? widget.pools 
        : widget.transactions.map((t) => t.pool).where((p) => p.isNotEmpty).toSet().toList();

    Set<String> tempSelected = Set.from(_localSelectedPools);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Select Pools', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
              content: SizedBox(
                width: 300,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      title: Text('Select All', style: TextStyle(fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                      value: tempSelected.length == availablePoolsList.length,
                      checkColor: _isZaznamityMode ? Colors.white : null,
                      activeColor: _isZaznamityMode ? const Color(0xFFA855F7) : null,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            tempSelected = availablePoolsList.toSet();
                          } else {
                            tempSelected.clear();
                          }
                        });
                      },
                    ),
                    Divider(color: _isZaznamityMode ? Colors.white24 : const Color(0xFFE2E8F0)),
                    ...availablePoolsList.map((pool) {
                      return CheckboxListTile(
                        title: Text(pool.toUpperCase(), style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
                        value: tempSelected.contains(pool),
                        checkColor: _isZaznamityMode ? Colors.white : null,
                        activeColor: _isZaznamityMode ? const Color(0xFFA855F7) : null,
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
                  child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), foregroundColor: Colors.white),
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
    // Unrestricted date bounds (defaults to null/empty if not explicitly filtered)
    DateTime? activeStartDate = widget.startDate ?? _localStartDate;
    DateTime? activeEndDate = widget.endDate ?? _localEndDate;

    final bool hasDateFilter = widget.startDate != null || widget.endDate != null || _localStartDate != null;

    final activeOwner = widget.selectedOwner ?? _localOwner;
    final activeCurrency = widget.selectedCurrency ?? _localCurrency;
    final activeType = widget.selectedType ?? _localType;

    final double? minAmount = double.tryParse(_minAmountController.text);
    final double? maxAmount = double.tryParse(_maxAmountController.text);

    final filteredTransactions = widget.transactions.where((tx) {
      if (activeOwner != null && activeOwner.isNotEmpty && activeOwner != 'All Owners' && tx.owner != activeOwner) return false;
      
      if (_localSelectedPools.isNotEmpty && tx.pool.isNotEmpty && !_localSelectedPools.contains(tx.pool)) {
        return false;
      }

      if (activeCurrency != null && tx.currencyCode != activeCurrency && (tx.currencyCode.isNotEmpty || activeCurrency != 'USD')) return false;
      if (activeType != null && tx.type != activeType) return false;

      if (minAmount != null && tx.amount < minAmount) return false;
      if (maxAmount != null && tx.amount > maxAmount) return false;

      final labelObj = widget.labels.firstWhere(
        (l) => l.id == tx.labelId,
        orElse: () => LabelModel(id: tx.labelId, name: 'General', color: '#4338CA'),
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

    final availablePoolsList = widget.pools.isNotEmpty 
        ? widget.pools 
        : widget.transactions.map((t) => t.pool).where((p) => p.isNotEmpty).toSet().toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 48;
        final double boxWidth = (fullWidth - 12) / 2;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: _isZaznamityMode
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF3B1E63),
                      Color(0xFF160D25),
                      Color(0xFF000000),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF582F95).withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                )
              : BoxDecoration(
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
                      child: Text(
                        'ALL ZAZNAMS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
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
                                backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                                foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
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
                              backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                              foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
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
                        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: activeOwner,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                hint: Text('All Owners', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                items: [
                                  DropdownMenuItem<String?>(value: null, child: Text('All Owners', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  ...widget.owners.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
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
                              color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.horizontal(
                                left: const Radius.circular(10),
                                right: hasDateFilter ? Radius.zero : const Radius.circular(10),
                              ),
                              border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
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
                                      Icon(Icons.date_range_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          activeStartDate != null && activeEndDate != null
                                              ? '${DateFormat('MM/dd').format(activeStartDate)} - ${DateFormat('MM/dd').format(activeEndDate)}'
                                              : 'Select Date Range',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: hasDateFilter ? (_isZaznamityMode ? Colors.white : const Color(0xFF1E293B)) : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                            fontWeight: hasDateFilter ? FontWeight.bold : FontWeight.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!hasDateFilter)
                                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8)),
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
                              color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFE2E8F0),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                              border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
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
                          color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.label_outline_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _localSelectedLabels.length == widget.labels.length
                                            ? 'All Labels'
                                            : '${_localSelectedLabels.length} selected',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, size: 18, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
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
                          color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(Icons.layers_outlined, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _localSelectedPools.length == availablePoolsList.length
                                            ? 'All Pools'
                                            : '${_localSelectedPools.length} selected',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, size: 18, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
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
                        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: activeCurrency,
                          isDense: true,
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                          hint: Row(
                            children: [
                              Icon(Icons.public, size: 14, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                              const SizedBox(width: 6),
                              Text('All Currencies', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                            ],
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null, 
                              child: Row(
                                children: [
                                  Icon(Icons.public, size: 14, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                  const SizedBox(width: 6),
                                  Text('All Currencies', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                ],
                              ),
                            ),
                            ..._activeCurrencies.map((c) => DropdownMenuItem<String?>(
                              value: c, 
                              child: Row(
                                children: [
                                  Text(_currencyFlags[c] ?? '💵', style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(c, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
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
                        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.swap_vert_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: activeType,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                hint: Text('All Types', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                items: [
                                  DropdownMenuItem<String?>(value: null, child: Text('All Types', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  DropdownMenuItem<String?>(value: 'income', child: Text('Income', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  DropdownMenuItem<String?>(value: 'expense', child: Text('Expense', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
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
                      style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.attach_money_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                        hintText: 'Min',
                        hintStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8), fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fullWidth * 0.4,
                    child: TextField(
                      controller: _maxAmountController,
                      style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.attach_money_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                        hintText: 'Max',
                        hintStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8), fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                        filled: true,
                        fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fullWidth * 0.2,
                    height: 42,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: BorderSide(color: _isZaznamityMode ? Colors.red.shade800 : const Color(0xFFFCA5A5)),
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
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Row(
                    children: [
                      Text('Show: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLimit,
                          isDense: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF475569)),
                          items: ['25', '50', '100', '150', '200', 'All']
                              .map((lim) => DropdownMenuItem(value: lim, child: Text(lim, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))))
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
              Divider(color: _isZaznamityMode ? Colors.white24 : const Color(0xFFE2E8F0)),
              
              displayedTransactions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('No transactions found.', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8))),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      cacheExtent: 1000,
                      itemCount: displayedTransactions.length,
                      separatorBuilder: (context, index) => Divider(color: _isZaznamityMode ? Colors.white10 : const Color(0xFFF1F5F9), height: 1),
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
                            color: isFuture && !timePassed ? (_isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9)) : Colors.transparent,
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
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(formattedDate, style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                        Text('•', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white24 : const Color(0xFF94A3B8))),
                                        Text(tx.owner, style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF4338CA), fontWeight: FontWeight.w500)),
                                        Text('•', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white24 : const Color(0xFF94A3B8))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: _isZaznamityMode ? const Color(0xFF3F2F17) : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            labelObj.name,
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFFCD34D) : const Color(0xFFD97706)),
                                          ),
                                        ),
                                        Text('•', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white24 : const Color(0xFF94A3B8))),
                                        Text('$flag $currencyCode', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
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
                                        color: isIncome ? const Color(0xFF34D399) : const Color(0xFFF87171),
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
                                          ? (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))
                                          : const Color(0xFF34D399),
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
                                        icon: Icon(Icons.edit, size: 16, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                        tooltip: 'Edit',
                                        onPressed: () => widget.onEditTransaction(tx),
                                      ),
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(1),
                                        icon: const Icon(Icons.delete, size: 16, color: Color(0xFFEF4444)),
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