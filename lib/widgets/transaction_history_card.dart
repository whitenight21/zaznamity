// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';
import '../models/history_display_prefs.dart';
import 'dart:io';

class TransactionHistoryCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<TransactionModel>? allTransactions;
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

  const TransactionHistoryCard({
    super.key,
    required this.transactions,
    this.allTransactions,
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
  });

  @override
  State<TransactionHistoryCard> createState() => _TransactionHistoryCardState();
}

class _TransactionHistoryCardState extends State<TransactionHistoryCard> {
  String _selectedLimit = '50';
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _debouncedQuery = '';
  
  late Set<int> _localSelectedLabels = {};
  late Set<String> _localSelectedPools = {};
  String? _localOwner;
  String? _localCurrency;
  String? _localType;
  
  final Set<String> _localSelectedTypes = {};

  DateTime? _localStartDate;
  DateTime? _localEndDate;
  bool _isInitialized = false;
  List<String> _activeCurrencies = ['USD'];
  bool _isZaznamityMode = true;
  bool _hideFuturePayments = false;
  bool _isCollapsed = false;

  HistoryDisplayPrefs _displayPrefs = HistoryDisplayPrefs();

  final Map<String, String> _currencyFlags = {
    'EUR': '🇪🇺',
    'USD': '🇺🇸',
    'CAD': '🇨🇦',
    'GBP': '🇬🇧',
    'CZK': '🇨🇿',
    'HUF': '🇭🇺',
    'PLN': '🇵🇱',
    'CHF': '🇨🇭',
    'RUB': '🇷🇺',
    'JPY': '🇯🇵',
    'CNY': '🇨🇳',
    'HKD': '🇭🇰',
    'SGD': '🇸🇬',
    'AUD': '🇦🇺',
    'BRL': '🇧🇷',
    'MXN': '🇲🇽',
    'CLP': '🇨🇱',
    'COP': '🇨🇴',
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
    final collapsed = prefs.getBool('set_transactionHistory_collapsed') ?? false;

    final displayPrefs = await HistoryDisplayPrefs.load();

    List<String> currencies = [primary];
    if (sec1 != null && sec1.isNotEmpty) currencies.add(sec1);
    if (sec2 != null && sec2.isNotEmpty) currencies.add(sec2);
    if (sec3 != null && sec3.isNotEmpty) currencies.add(sec3);

    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _activeCurrencies = currencies.toSet().toList();
        _displayPrefs = displayPrefs;
        _isCollapsed = collapsed;
      });
    }
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_transactionHistory_collapsed', _isCollapsed);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadPrefs();
  }

  void _onSearchChanged(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _debouncedQuery = val.trim().toLowerCase();
      });
    });
  }

  void _initDefaults() {
    if (_isInitialized) return;
    _localOwner = widget.selectedOwner;
    _localCurrency = widget.selectedCurrency;
    _localType = widget.selectedType;
    if (_localType != null) {
      _localSelectedTypes.add(_localType!);
    } else {
      _localSelectedTypes.addAll(['income', 'expense']);
    }
    
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
      _localSelectedTypes..clear()..addAll(['income', 'expense']);
      _localStartDate = null;
      _localEndDate = null;
      _minAmountController.clear();
      _maxAmountController.clear();
      _searchController.clear();
      _debouncedQuery = '';
      _localSelectedLabels = allLabelIds;
      _localSelectedPools = allPools;
      _hideFuturePayments = false;
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
      case 'JPY': 
      case 'CNY': return '¥';
      case 'CAD': return 'C\$';
      case 'AUD': return 'A\$';
      case 'HKD': return 'HK\$';
      case 'SGD': return 'S\$';
      case 'CZK': return 'Kč';
      case 'HUF': return 'Ft';
      case 'PLN': return 'zł';
      case 'CHF': return 'CHF';
      case 'RUB': return '₽';
      case 'BRL': return 'R\$';
      case 'MXN': 
      case 'CLP': 
      case 'COP': return '\$';
      default: return '\$';
    }
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) {
      return const Color(0xFF4338CA);
    }
    try {
      var hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF4338CA);
    }
  }

  void _showDeleteConfirmation(BuildContext context, int? transactionId) {
    if (transactionId == null) return;
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
    DateTime? activeStartDate = widget.startDate ?? _localStartDate;
    DateTime? activeEndDate = widget.endDate ?? _localEndDate;

    final bool hasDateFilter = widget.startDate != null || widget.endDate != null || _localStartDate != null;

    final activeOwner = widget.selectedOwner ?? _localOwner;
    final activeCurrency = widget.selectedCurrency ?? _localCurrency;

    final double? minAmount = double.tryParse(_minAmountController.text);
    final double? maxAmount = double.tryParse(_maxAmountController.text);

    final filteredTransactions = widget.transactions.where((tx) {
      if (_debouncedQuery.isNotEmpty) {
        final desc = tx.description.toLowerCase();
        if (!desc.contains(_debouncedQuery)) return false;
      }

      if (activeOwner != null && activeOwner.isNotEmpty && activeOwner != 'All Owners' && tx.owner != activeOwner) return false;
      
      if (_localSelectedPools.isNotEmpty && tx.pool.isNotEmpty && !_localSelectedPools.contains(tx.pool)) {
        return false;
      }

      if (activeCurrency != null && tx.currencyCode != activeCurrency && (tx.currencyCode.isNotEmpty || activeCurrency != 'USD')) return false;
      
      if (_localSelectedTypes.isNotEmpty && !_localSelectedTypes.contains(tx.type)) {
        return false;
      }

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
      
      if (_hideFuturePayments) {
        final bool isFuture = txDate.isAfter(DateTime.now());
        final bool timePassed = txDate.isBefore(DateTime.now());
        if (isFuture && !timePassed) {
          return false;
        }
      }

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

    final bool useCustomView = _displayPrefs.isCustomFilterEnabled;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 32;
        
        final double standardSpacing = 6.0;
        final double thirdWidth = (fullWidth - (standardSpacing * 2)) / 3.0;
        final double row2AvailableWidth = fullWidth - (standardSpacing * 2);

        return Container(
          padding: EdgeInsets.all(_isCollapsed ? 12 : 16),
          decoration: _isZaznamityMode
              ? BoxDecoration(
                  color: Colors.black,
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
            mainAxisSize: MainAxisSize.min,
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
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline_rounded, size: 12, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                            const SizedBox(width: 4),
                            Text(
                              activeOwner != null && activeOwner.isNotEmpty ? activeOwner : 'All Owners',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 28,
                        width: 28,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: useCustomView 
                                ? const Color(0xFF582F95) 
                                : (_isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9)),
                            foregroundColor: useCustomView 
                                ? Colors.white 
                                : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () async {
                            setState(() {
                              _displayPrefs.isCustomFilterEnabled = !_displayPrefs.isCustomFilterEnabled;
                            });
                            await _displayPrefs.save();
                          },
                          icon: Icon(
                            useCustomView ? Icons.tune : Icons.tune_outlined,
                            size: 14,
                          ),
                          tooltip: useCustomView ? 'Custom Compact View Active' : 'Full View Active',
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 28,
                        width: 28,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                            foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: _toggleCollapse,
                          icon: Icon(
                            _isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                            size: 16,
                          ),
                          tooltip: _isCollapsed ? 'Expand' : 'Collapse',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!_isCollapsed) ...[
                const SizedBox(height: 16),

                // =======================================================
                // ROW 1: Labels, Pools, Switch [Expense][Income] (each 1/3)
                // =======================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: thirdWidth,
                      height: 44,
                      child: InkWell(
                        onTap: () => _showMultiSelectDialog(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
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
                                    Icon(Icons.label_outline_rounded, size: 14, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _localSelectedLabels.length == widget.labels.length
                                              ? 'Labels'
                                              : '${_localSelectedLabels.length} labels',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox.shrink(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: thirdWidth,
                      height: 44,
                      child: InkWell(
                        onTap: () => _showPoolsMultiSelectDialog(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
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
                                    Icon(Icons.layers_outlined, size: 14, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _localSelectedPools.length == availablePoolsList.length
                                              ? 'Pools'
                                              : '${_localSelectedPools.length} pools',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox.shrink(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: thirdWidth,
                      height: 44,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_localSelectedTypes.contains('expense')) {
                                      if (_localSelectedTypes.length > 1) {
                                        _localSelectedTypes.remove('expense');
                                      }
                                    } else {
                                      _localSelectedTypes.add('expense');
                                    }
                                  });
                                },
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _localSelectedTypes.contains('expense') ? const Color(0xFF582F95) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Exp',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: _localSelectedTypes.contains('expense') ? Colors.white : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_localSelectedTypes.contains('income')) {
                                      if (_localSelectedTypes.length > 1) {
                                        _localSelectedTypes.remove('income');
                                      }
                                    } else {
                                      _localSelectedTypes.add('income');
                                    }
                                  });
                                },
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _localSelectedTypes.contains('income') ? const Color(0xFF582F95) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Inc',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: _localSelectedTypes.contains('income') ? Colors.white : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                    ),
                                  ),
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

                // =======================================================
                // ROW 2: Currency (20%), Pending (25%), Date (50%)
                // =======================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Currency (20%)
                    SizedBox(
                      width: row2AvailableWidth * 0.24,
                      height: 44,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
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
                            icon: const SizedBox.shrink(),
                            iconSize: 0,
                            dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                            hint: Center(
                              child: Icon(Icons.public, size: 14, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null, 
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.public, size: 12, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                      const SizedBox(width: 3),
                                      Text('All', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ),
                              ..._activeCurrencies.map((c) => DropdownMenuItem<String?>(
                                value: c, 
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_currencyFlags[c] ?? '💵', style: const TextStyle(fontSize: 11)),
                                      const SizedBox(width: 3),
                                      Text(c, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 10)),
                                    ],
                                  ),
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
                    // Pending Button (25%)
                    SizedBox(
                      width: row2AvailableWidth * 0.27,
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _hideFuturePayments
                              ? Colors.white
                              : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                          backgroundColor: _hideFuturePayments
                              ? const Color(0xFF582F95)
                              : (_isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC)),
                          side: BorderSide(
                            color: _hideFuturePayments
                                ? Colors.transparent
                                : (_isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                        ),
                        onPressed: () {
                          setState(() {
                            _hideFuturePayments = !_hideFuturePayments;
                          });
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _hideFuturePayments ? Icons.visibility_off : Icons.visibility,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            const Flexible(
                              child: Text(
                                'Pending',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Date Picker Widget (50%)
                    SizedBox(
                      width: row2AvailableWidth * 0.53,
                      height: 44,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Row(
                                      children: [
                                        Icon(Icons.date_range_rounded, size: 14, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            activeStartDate != null && activeEndDate != null
                                                ? '${DateFormat('MM/dd').format(activeStartDate)} - ${DateFormat('MM/dd').format(activeEndDate)}'
                                                : 'Date Range',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: hasDateFilter ? (_isZaznamityMode ? Colors.white : const Color(0xFF1E293B)) : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                              fontWeight: hasDateFilter ? FontWeight.bold : FontWeight.normal,
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
                              width: 26,
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
                                    child: Icon(Icons.clear, size: 12, color: Color(0xFFDC2626)),
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

                // =======================================================
                // ROW 3: Min Amount, Max Amount, Clear
                // =======================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: (fullWidth - 65 - (standardSpacing * 2)) / 2.0,
                      height: 44,
                      child: TextField(
                        controller: _minAmountController,
                        style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 11),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.attach_money_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                          prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 16),
                          hintText: 'Min Amount',
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
                      width: (fullWidth - 65 - (standardSpacing * 2)) / 2.0,
                      height: 44,
                      child: TextField(
                        controller: _maxAmountController,
                        style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 11),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.attach_money_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                          prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 16),
                          hintText: 'Max Amount',
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
                      width: 65,
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                          side: BorderSide(color: _isZaznamityMode ? Colors.red.shade800 : const Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: _clearAllFilters,
                        child: const Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // =======================================================
                // ROW 4: Description Search
                // =======================================================
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 11),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search description...',
                      hintStyle: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF64748B)),
                      prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                      filled: true,
                      fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Top Pagination Control Header
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
                          final labelColor = _parseColor(labelObj.color);

                          final currencyCode = tx.currencyCode.isNotEmpty ? tx.currencyCode : 'USD';
                          final flag = _currencyFlags[currencyCode] ?? '🇺🇸';
                          final symbol = _getCurrencySymbol(currencyCode);

                          final isIncome = tx.type == 'income';
                          final amountString = '${isIncome ? '+' : '-'}$symbol${tx.amount.toStringAsFixed(2)}';

                          final bool timePassed = txDate.isBefore(DateTime.now());
                          final bool isFuture = txDate.isAfter(DateTime.now());

                          final showDesc = !useCustomView || _displayPrefs.showDescription;
                          final showDate = !useCustomView || _displayPrefs.showDate;
                          final showLabel = !useCustomView || _displayPrefs.showLabel;
                          final showOwner = !useCustomView || _displayPrefs.showOwner;
                          final showCurrency = !useCustomView || _displayPrefs.showCurrency;
                          final showAmount = !useCustomView || _displayPrefs.showAmount;
                          final showPool = !useCustomView || _displayPrefs.showPool;
                          final showEdit = !useCustomView || _displayPrefs.showEdit;
                          final showDelete = !useCustomView || _displayPrefs.showDelete;
                          final showStatus = !useCustomView || _displayPrefs.showConfirmStatus;
                          final showAttach = !useCustomView || _displayPrefs.showAttachments;

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
                                      if (showDesc)
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                tx.description.isNotEmpty ? tx.description : 'Unnamed Transaction',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (showAttach && tx.receiptPath != null && tx.receiptPath!.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) => Dialog(
                                                      backgroundColor: Colors.transparent,
                                                      child: Stack(
                                                        children: [
                                                          Center(
                                                            child: InteractiveViewer(
                                                              child: Image.file(File(tx.receiptPath!)),
                                                            ),
                                                          ),
                                                          Positioned(
                                                            top: 10,
                                                            right: 10,
                                                            child: IconButton(
                                                              icon: const Icon(Icons.close, color: Colors.white, size: 24),
                                                              onPressed: () => Navigator.pop(ctx),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Tooltip(
                                                  message: 'View Attached Receipt',
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFA855F7).withValues(alpha: 0.25),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: const Color(0xFFA855F7), width: 0.5),
                                                    ),
                                                    child: const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFFA855F7)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      if (showDate || showOwner || showLabel || showCurrency) ...[
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 2,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            if (showDate) ...[
                                              Text(formattedDate, style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                              if (showOwner || showLabel || showCurrency)
                                                Text('•', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white24 : const Color(0xFF94A3B8))),
                                            ],
                                            if (showOwner) ...[
                                              Text(tx.owner, style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF4338CA), fontWeight: FontWeight.w500)),
                                              if (showLabel || showCurrency)
                                                Text('•', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white24 : const Color(0xFF94A3B8))),
                                            ],
                                            if (showLabel) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: labelColor.withValues(alpha: _isZaznamityMode ? 0.25 : 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: labelColor.withValues(alpha: 0.5), width: 0.5),
                                                ),
                                                child: Text(
                                                  labelObj.name,
                                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: labelColor),
                                                ),
                                              ),
                                              if (showCurrency)
                                                Text('•', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white24 : const Color(0xFF94A3B8))),
                                            ],
                                            if (showCurrency)
                                              Text('$flag $currencyCode', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                if (showAmount || showPool) ...[
                                  const SizedBox(width: 4),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (showAmount)
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
                                      if (showPool) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          tx.pool.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w600,
                                            color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],

                                if (showEdit || showDelete || showStatus) ...[
                                  const SizedBox(width: 4),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (showEdit || showDelete)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (showEdit)
                                              IconButton(
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                                icon: Icon(Icons.edit, size: 16, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                                tooltip: 'Edit',
                                                onPressed: () => widget.onEditTransaction(tx),
                                              ),
                                            if (showDelete)
                                              IconButton(
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                                icon: const Icon(Icons.delete, size: 16, color: Color(0xFFEF4444)),
                                                tooltip: 'Delete',
                                                onPressed: () => _showDeleteConfirmation(context, tx.id!),
                                              ),
                                          ],
                                        ),
                                      if (showStatus) ...[
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
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),

                if (displayedTransactions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(color: _isZaznamityMode ? Colors.white24 : const Color(0xFFE2E8F0)),
                  const SizedBox(height: 8),
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
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}