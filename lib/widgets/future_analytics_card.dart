// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';
import '../widgets/masked_amount.dart';

class FutureAnalyticsCard extends StatefulWidget {
  final List<String> owners;
  final String? selectedOwner;
  final List<String> pools;
  final String? selectedPool;
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List budgets;
  final Function(int labelId, String labelName, DateTime start, DateTime end)? onJumpToHistoryForLabel;
  final VoidCallback? onJumpToMetrics;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime?, DateTime?)? onDateRangeChanged;
  final VoidCallback? onClearDateFilter;
  final Function(String?)? onPoolChanged; // Added parameter

  const FutureAnalyticsCard({
    super.key,
    required this.owners,
    this.selectedOwner,
    required this.pools,
    this.selectedPool,
    required this.transactions,
    required this.labels,
    this.budgets = const [],
    this.onJumpToHistoryForLabel,
    this.onJumpToMetrics,
    this.startDate,
    this.endDate,
    this.onDateRangeChanged,
    this.onClearDateFilter,
    this.onPoolChanged, // Added to constructor
  });

  @override
  State<FutureAnalyticsCard> createState() => _FutureAnalyticsCardState();
}

class _FutureAnalyticsCardState extends State<FutureAnalyticsCard> {
  late String _selectedOwner;
  late String _selectedPool;
  Set<int> _selectedLabelIds = {};
  String _timeframe = 'Month';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isZaznamityMode = true;
  bool _isCollapsed = false;
  String _primaryCurrency = 'USD';
  bool _excludeTransfers = true;
  Map<Object?, String> _labelNames = {};

  @override
  void initState() {
    super.initState();
    _rebuildLabelNames();
    _selectedOwner = widget.selectedOwner ?? 'All Owners';
    _selectedPool = widget.selectedPool ?? 'All Pools';
    if (widget.startDate != null && widget.endDate != null) {
      _timeframe = 'Custom';
      _customStartDate = widget.startDate;
      _customEndDate = widget.endDate;
    }
    _loadPrefs();
  }

  void _rebuildLabelNames() {
    _labelNames = {for (final l in widget.labels) l.id: l.name};
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    
    final savedLabelIdsList = prefs.getStringList('future_analytics_selected_labels');
    Set<int> loadedLabelIds = {};
    if (savedLabelIdsList != null) {
      final validIds = widget.labels.map((l) => l.id).toSet();
      loadedLabelIds = savedLabelIdsList
          .map((idStr) => int.tryParse(idStr))
          .where((id) => id != null && validIds.contains(id))
          .cast<int>()
          .toSet();
    }

    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _isCollapsed = prefs.getBool('set_futureAnalytics_collapsed') ?? false;
        _primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';
        _excludeTransfers = prefs.getBool('exclude_transfers_insights') ?? true;
        if (savedLabelIdsList != null) {
          _selectedLabelIds = loadedLabelIds;
        }
      });
    }
  }

  Future<void> _saveLabelPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final listToSave = _selectedLabelIds.map((id) => id.toString()).toList();
    await prefs.setStringList('future_analytics_selected_labels', listToSave);
  }

  Color _parseColor(String? colorStr, Color fallback) {
    if (colorStr == null || colorStr.isEmpty) return fallback;
    try {
      String hex = colorStr.replaceAll('#', '').trim();
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) {
        final val = int.tryParse(hex, radix: 16);
        if (val != null) return Color(val);
      }
    } catch (_) {}
    return fallback;
  }

  static const Set<String> _nonSpendingLabels = {'transfer', 'goals', 'goalssavings'};
  static const List<String> _transferDescriptionPrefixes = [
    'transfer out',
    'transfer in',
    'withdrawal from',
    'deposit into',
  ];

  bool _isTransferLike(TransactionModel tx) {
    if (!_excludeTransfers) return false;
    final savingsFlag = '${tx.isSavings}';
    if (savingsFlag == '1' || savingsFlag == 'true') return true;
    final labelName = _labelNames[tx.labelId];
    if (labelName != null && _nonSpendingLabels.contains(labelName.toLowerCase().replaceAll(' ', ''))) {
      return true;
    }
    final desc = '${tx.description}'.toLowerCase().trim();
    return _transferDescriptionPrefixes.any(desc.startsWith);
  }

  bool _matchesOwner(TransactionModel tx) => _selectedOwner == 'All Owners' || tx.owner == _selectedOwner;
  bool _matchesPool(TransactionModel tx) => _selectedPool == 'All Pools' || tx.pool.toLowerCase() == _selectedPool.toLowerCase();
  bool _matchesFilters(TransactionModel tx) => _matchesOwner(tx) && _matchesPool(tx);
  bool _includeInForecast(TransactionModel tx) => _matchesFilters(tx) && !_isTransferLike(tx);

  void _showFutureBreakdownInfoModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Future Breakdown',
                  style: TextStyle(
                    color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              ' “Where is my money going?”\n\n' 
              '• This card provides forward-looking analytical insights into your projected financial standing by labels.\n\n'
              '• It breaks down upcoming scheduled income and expenses by category label over your selected future window, starting strictly from today onwards.\n'
              '• Strictly excludes past zaznams and transfers/goal contributions.\n'
              '• Budget Exceeded Warnings: Visual warning badges indicate if an upcoming category expense exceeds its monthly budget limit.\n'
              '• Label Filter Persistence: Saved selections automatically persist when leaving or collapsing the card.',
              style: TextStyle(
                fontSize: 13,
                color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Got it'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isCollapsed = !_isCollapsed);
    await prefs.setBool('set_futureAnalytics_collapsed', _isCollapsed);
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: todayMidnight,
      lastDate: DateTime(2040),
      initialDateRange: (_customStartDate != null && _customEndDate != null)
          ? DateTimeRange(
              start: _customStartDate!.isBefore(todayMidnight) ? todayMidnight : _customStartDate!,
              end: _customEndDate!,
            )
          : (widget.startDate != null && widget.endDate != null)
              ? DateTimeRange(start: widget.startDate!, end: widget.endDate!)
              : null,
      builder: (context, child) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
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

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start.isBefore(todayMidnight) ? todayMidnight : picked.start;
        _customEndDate = picked.end;
        _timeframe = 'Custom';
      });
      if (widget.onDateRangeChanged != null) {
        widget.onDateRangeChanged!(_customStartDate, _customEndDate);
      }
    }
  }

  void _showLabelsCheckmarkModal(BuildContext context) {
    Set<int> tempSelectedIds = _selectedLabelIds.isEmpty 
        ? widget.labels.map((l) => l.id).toSet() 
        : Set.from(_selectedLabelIds);

    showModalBottomSheet(
      context: context,
      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool allSelected = tempSelectedIds.length == widget.labels.length;

            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Labels',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempSelectedIds = widget.labels.map((l) => l.id).toSet();
                              });
                            },
                            child: const Text('Select All', style: TextStyle(color: Color(0xFFA855F7))),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempSelectedIds.clear();
                              });
                            },
                            child: const Text('Clear All', style: TextStyle(color: Color(0xFFF87171))),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  CheckboxListTile(
                    title: Text(
                      'All Labels',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    value: allSelected,
                    activeColor: const Color(0xFFA855F7),
                    onChanged: (bool? value) {
                      setModalState(() {
                        if (value == true) {
                          tempSelectedIds = widget.labels.map((l) => l.id).toSet();
                        } else {
                          tempSelectedIds.clear();
                        }
                      });
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.labels.length,
                      itemBuilder: (context, index) {
                        final label = widget.labels[index];
                        final isChecked = tempSelectedIds.contains(label.id);

                        return CheckboxListTile(
                          title: Text(
                            label.name,
                            style: TextStyle(
                              color: _isZaznamityMode ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                          value: isChecked,
                          activeColor: const Color(0xFFA855F7),
                          onChanged: (bool? value) {
                            setModalState(() {
                              if (value == true) {
                                tempSelectedIds.add(label.id);
                              } else {
                                tempSelectedIds.remove(label.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          if (tempSelectedIds.isEmpty || tempSelectedIds.length == widget.labels.length) {
                            _selectedLabelIds.clear();
                          } else {
                            _selectedLabelIds = tempSelectedIds;
                          }
                        });
                        _saveLabelPrefs();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant FutureAnalyticsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebuildLabelNames();
    if (widget.selectedOwner != oldWidget.selectedOwner) {
      setState(() => _selectedOwner = widget.selectedOwner ?? 'All Owners');
    }
    if (widget.selectedPool != oldWidget.selectedPool) {
      setState(() => _selectedPool = widget.selectedPool ?? 'All Pools');
    }
  }

  @override
  void dispose() {
    _saveLabelPrefs();
    super.dispose();
  }

  String _formatCurrency(double amount, {bool isExpense = false}) {
    final cleanAmount = amount.abs();
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final formattedNum = formatter.format(cleanAmount);
    
    String result;
    if (_primaryCurrency == 'EUR') {
      result = '$formattedNum €';
    } else if (_primaryCurrency == 'USD') {
      result = '\$$formattedNum';
    } else {
      result = '$formattedNum $_primaryCurrency';
    }

    if (isExpense && cleanAmount > 0) {
      return '-$result';
    }
    return result;
  }

  DateTime _getEffectiveEndDate(DateTime now) {
    if (_timeframe == 'Custom' && _customEndDate != null) return _customEndDate!;
    if (_timeframe == 'Month') {
      return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }
    if (_timeframe == '90D') return now.add(const Duration(days: 90));
    if (_timeframe == '6M') return now.add(const Duration(days: 180));
    if (_timeframe == '1Y') return now.add(const Duration(days: 365));
    return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  DateTime _getEffectiveStartDate(DateTime now) {
    if (_timeframe == 'Custom' && _customStartDate != null) {
      return _customStartDate!.isBefore(now) ? now : _customStartDate!;
    }
    return now;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startDate = widget.startDate ?? _getEffectiveStartDate(now);
    final endDate = widget.endDate ?? _getEffectiveEndDate(now);

    final activeOwner = widget.selectedOwner ?? 'All Owners';

    final Map<int, double> expenseByCategory = {};
    final Map<int, double> incomeByCategory = {};
    double totalFutureExpense = 0;
    double totalFutureIncome = 0;

    for (var tx in widget.transactions) {
      if (!_includeInForecast(tx)) continue;

      final dt = DateTime.tryParse(tx.createdAt);
      if (dt == null || dt.isBefore(startDate) || dt.isAfter(endDate)) continue;
      if (dt.isBefore(now)) continue;

      if (_selectedLabelIds.isNotEmpty && !_selectedLabelIds.contains(tx.labelId)) continue;

      if (tx.type == 'expense') {
        expenseByCategory[tx.labelId] = (expenseByCategory[tx.labelId] ?? 0.0) + tx.amount;
        totalFutureExpense += tx.amount;
      } else if (tx.type == 'income') {
        incomeByCategory[tx.labelId] = (incomeByCategory[tx.labelId] ?? 0.0) + tx.amount;
        totalFutureIncome += tx.amount;
      }
    }

    final labelMap = {for (var l in widget.labels) l.id: l};

    final sortedExpenses = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sortedIncomes = incomeByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final double availableWidth = MediaQuery.of(context).size.width - 32;
    final double boxWidth = (availableWidth - 12) / 2;
    final bool hasDateFilter = widget.startDate != null || widget.endDate != null;

    final windowDateStr = '${DateFormat('MMM dd, yyyy').format(startDate)} – ${DateFormat('MMM dd, yyyy').format(endDate)}';

    String labelButtonText = 'All Labels';
    if (_selectedLabelIds.length == 1) {
      final singleLabel = widget.labels.where((l) => l.id == _selectedLabelIds.first).firstOrNull;
      labelButtonText = singleLabel?.name ?? '1 Selected';
    } else if (_selectedLabelIds.length > 1) {
      labelButtonText = '${_selectedLabelIds.length} Selected';
    }

    return Container(
      padding: EdgeInsets.all(_isCollapsed ? 12 : 16),
      decoration: _isZaznamityMode
          ? BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF582F95).withValues(alpha: 0.5), width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))],
            )
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'FUTURE BREAKDOWN ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.info_outline, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
                    onPressed: () => _showFutureBreakdownInfoModal(context),
                    tooltip: 'Future Breakdown',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
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
                          activeOwner,
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
                        backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                        foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _toggleCollapse,
                      icon: Icon(_isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (!_isCollapsed) ...[
            const SizedBox(height: 4),
            Text(
              'PROJECTION WINDOW: $windowDateStr',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),

            // Dropdowns row: Pool and Checkmark Labels Dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: boxWidth,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPool,
                              isDense: true,
                              isExpanded: true,
                              dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                              items: [
                                const DropdownMenuItem(value: 'All Pools', child: Text('All Pools')),
                                ...widget.pools.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedPool = val);
                                  if (widget.onPoolChanged != null) {
                                    widget.onPoolChanged!(val);
                                  }
                                }
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
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showLabelsCheckmarkModal(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Icon(Icons.label_outline_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  labelButtonText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.arrow_drop_down, size: 18, color: _isZaznamityMode ? Colors.white70 : Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Timeframe Selector Pills & Date Range Picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: boxWidth,
                  child: Row(
                    children: ['Month', '90D', '6M', '1Y'].map((tf) {
                      final isSelected = _timeframe == tf && !hasDateFilter;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: tf != '1Y' ? 4 : 0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _timeframe = tf;
                                _customStartDate = null;
                                _customEndDate = null;
                              });
                              final start = _getEffectiveStartDate(now);
                              final end = _getEffectiveEndDate(now);
                              if (widget.onDateRangeChanged != null) {
                                widget.onDateRangeChanged!(start, end);
                              }
                            },
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? const Color(0xFF582F95) 
                                    : (_isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                              ),
                              alignment: Alignment.center,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Text(
                                  tf,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : (_isZaznamityMode ? Colors.white70 : const Color(0xFF64748B)),
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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
                            color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.horizontal(
                              left: const Radius.circular(10),
                              right: hasDateFilter ? Radius.zero : const Radius.circular(10),
                            ),
                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
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
                                    Icon(Icons.date_range_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        hasDateFilter
                                            ? '${DateFormat('MM/dd').format(startDate)} - ${DateFormat('MM/dd').format(endDate)}'
                                            : 'Date Range',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: hasDateFilter ? (_isZaznamityMode ? Colors.white : const Color(0xFF1E293B)) : (_isZaznamityMode ? Colors.white54 : const Color(0xFF94A3B8)),
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
                        Container(
                          height: 44,
                          width: 32,
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF3D256B) : const Color(0xFFE2E8F0),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _timeframe = 'Month';
                                  _customStartDate = null;
                                  _customEndDate = null;
                                });
                                if (widget.onClearDateFilter != null) {
                                  widget.onClearDateFilter!();
                                }
                              },
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                              child: const Center(
                                child: Icon(Icons.clear, size: 14, color: Color(0xFFF87171)),
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
            const SizedBox(height: 16),

            // Inflow / Outflow Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 87,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('EXPECTED INFLOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey)),
                        const SizedBox(height: 4),
                        MaskedAmount(
                          formattedAmount: _formatCurrency(totalFutureIncome),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 87,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('EXPECTED OUTFLOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey)),
                        const SizedBox(height: 4),
                        MaskedAmount(
                          formattedAmount: _formatCurrency(totalFutureExpense, isExpense: true),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF87171)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Jump to Future Outlook button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onJumpToMetrics,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.insights_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                            const SizedBox(width: 8),
                            Text(
                              'View Prognosis in "Future Outlook"',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Upcoming Income Labels & Expense Labels Headers
            Row(
              children: [
                Expanded(
                  child: Text(
                    'UPCOMING INCOME LABELS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade700, letterSpacing: 0.6),
                  ),
                ),
                Expanded(
                  child: Text(
                    'UPCOMING EXPENSE LABELS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade700, letterSpacing: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Income Column
                Expanded(
                  child: sortedIncomes.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('No scheduled income', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white38 : Colors.grey)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sortedIncomes.length,
                          itemBuilder: (context, index) {
                            final entry = sortedIncomes[index];
                            final labelId = entry.key;
                            final amount = entry.value;
                            final label = labelMap[labelId];
                            final labelName = label?.name ?? 'General';
                            final double percentage = totalFutureIncome > 0 ? (amount / totalFutureIncome) : 0.0;
                            final dotColor = _parseColor(label?.color, const Color(0xFF34D399));

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6, right: 4),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (widget.onJumpToHistoryForLabel != null) {
                                      widget.onJumpToHistoryForLabel!(labelId, labelName, startDate, endDate);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: dotColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  labelName,
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                            MaskedAmount(
                                              formattedAmount:
                                              _formatCurrency(amount),
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF334155)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: percentage.clamp(0.0, 1.0),
                                            backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFE2E8F0),
                                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                                            minHeight: 3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(width: 8),
                // Expense Column
                Expanded(
                  child: sortedExpenses.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('No scheduled expenses', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white38 : Colors.grey)),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sortedExpenses.length,
                          itemBuilder: (context, index) {
                            final entry = sortedExpenses[index];
                            final labelId = entry.key;
                            final amount = entry.value;
                            final label = labelMap[labelId];
                            final labelName = label?.name ?? 'General';
                            final double percentage = totalFutureExpense > 0 ? (amount / totalFutureExpense) : 0.0;
                            final dotColor = _parseColor(label?.color, const Color(0xFFA855F7));

                            final matchingBudget = widget.budgets.where((b) {
                              final bLabelId = b['label_id'] ?? b['labelId'];
                              return bLabelId == labelId;
                            }).firstOrNull;

                            final double? budgetLimit = matchingBudget != null 
                                ? ((matchingBudget['limit_amount'] ?? matchingBudget['limitAmount'] ?? 0) as num).toDouble() 
                                : null;

                            final bool isBudgetExceeded = budgetLimit != null && budgetLimit > 0 && amount > budgetLimit;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6, left: 4),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (widget.onJumpToHistoryForLabel != null) {
                                      widget.onJumpToHistoryForLabel!(labelId, labelName, startDate, endDate);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: dotColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      labelName,
                                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isBudgetExceeded) ...[
                                                    const SizedBox(width: 3),
                                                    const Tooltip(
                                                      message: 'Scheduled expense exceeds category monthly budget!',
                                                      child: Icon(Icons.error_outline_rounded, size: 13, color: Color(0xFFF87171)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            MaskedAmount(
                                              formattedAmount:
                                              _formatCurrency(amount, isExpense: true),
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF334155)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: percentage.clamp(0.0, 1.0),
                                            backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFE2E8F0),
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              isBudgetExceeded ? const Color(0xFFF87171) : dotColor,
                                            ),
                                            minHeight: 3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}