// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class FutureAnalyticsCard extends StatefulWidget {
  final List<String> owners;
  final String? selectedOwner;
  final List<String> pools;
  final String? selectedPool;
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final Function(int labelId, String labelName, DateTime start, DateTime end)? onJumpToHistoryForLabel;
  final VoidCallback? onJumpToMetrics; // Quick-jump bridge to Future Metrics card

  const FutureAnalyticsCard({
    super.key,
    required this.owners,
    this.selectedOwner,
    required this.pools,
    this.selectedPool,
    required this.transactions,
    required this.labels,
    this.onJumpToHistoryForLabel,
    this.onJumpToMetrics,
  });

  @override
  State<FutureAnalyticsCard> createState() => _FutureAnalyticsCardState();
}

class _FutureAnalyticsCardState extends State<FutureAnalyticsCard> {
  late String _selectedOwner;
  late String _selectedPool;
  Set<int> _selectedLabelIds = {}; // Empty or full means All Labels, otherwise contains specific label IDs
  String _timeframe = '90 Days'; // 'Current Month', '90 Days', '1 Year', or 'Custom'
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isZaznamityMode = true;
  bool _isCollapsed = false;
  String _primaryCurrency = 'USD';

  @override
  void initState() {
    super.initState();
    _selectedOwner = widget.selectedOwner ?? 'All Owners';
    _selectedPool = widget.selectedPool ?? 'All Pools';
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _isCollapsed = prefs.getBool('set_futureAnalytics_collapsed') ?? false;
        _primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';
      });
    }
  }

  void _showFutureAnalyticsInfoModal(BuildContext context) {
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
                  'Future Analytics',
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
              'Future Analytics provides forward-looking insights into your projected spending patterns starting strictly from today onwards.\n\n'
              '• It breaks down upcoming scheduled income and expenses by category label over your selected future window.\n'
              '• Strictly excludes any past zaznams, even if a custom date range window reaches back into historical dates.\n'
              '• Use the timeframe selector ("Current Month", "90 Days", "1 Year") or custom date range picker to view future projections.\n'
              '• Multi-select labels using the checkmark labels dropdown to filter specific categories.\n'
              '• Includes a Recurring vs. One-Time split to differentiate locked-in bills from flexible future expenses.\n'
              '• You can filter the analysis by owner, pool, and labels to focus on specific segments of your finances.\n\n',
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
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(2030),
      initialDateRange: (_customStartDate != null && _customEndDate != null)
          ? DateTimeRange(
              start: _customStartDate!.isBefore(now) ? now : _customStartDate!,
              end: _customEndDate!,
            )
          : DateTimeRange(start: now, end: now.add(const Duration(days: 90))),
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
        _customStartDate = picked.start.isBefore(now) ? now : picked.start;
        _customEndDate = picked.end;
        _timeframe = 'Custom';
      });
    }
  }

  void _showLabelsCheckmarkModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool allSelected = _selectedLabelIds.isEmpty;

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
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedLabelIds.clear();
                          });
                          setModalState(() {});
                        },
                        child: const Text('Clear All', style: TextStyle(color: Color(0xFFF87171))),
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
                      setState(() {
                        if (value == true) {
                          _selectedLabelIds.clear();
                        }
                      });
                      setModalState(() {});
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.labels.length,
                      itemBuilder: (context, index) {
                        final label = widget.labels[index];
                        final isChecked = _selectedLabelIds.contains(label.id);

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
                            setState(() {
                              if (value == true) {
                                _selectedLabelIds.add(label.id);
                              } else {
                                _selectedLabelIds.remove(label.id);
                              }
                            });
                            setModalState(() {});
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
                      onPressed: () => Navigator.pop(context),
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
    if (widget.selectedOwner != oldWidget.selectedOwner) {
      setState(() => _selectedOwner = widget.selectedOwner ?? 'All Owners');
    }
    if (widget.selectedPool != oldWidget.selectedPool) {
      setState(() => _selectedPool = widget.selectedPool ?? 'All Pools');
    }
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
    if (_timeframe == 'Current Month') {
      // Last day of the current month
      return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }
    if (_timeframe == '1 Year') return now.add(const Duration(days: 365));
    return now.add(const Duration(days: 90));
  }

  DateTime _getEffectiveStartDate(DateTime now) {
    if (_timeframe == 'Custom' && _customStartDate != null) {
      return _customStartDate!.isBefore(now) ? now : _customStartDate!;
    }
    return now;
  }

  bool _isRecurringTransaction(TransactionModel tx, List<LabelModel> labels) {
    final match = labels.where((l) => l.id == tx.labelId).firstOrNull;
    final name = (match?.name ?? '').toLowerCase();
    return name.contains('rent') ||
        name.contains('subscription') ||
        name.contains('utility') ||
        name.contains('utilities') ||
        name.contains('insurance') ||
        name.contains('loan') ||
        name.contains('mortgage') ||
        name.contains('bill') ||
        tx.isRecurring == 1;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startDate = _getEffectiveStartDate(now);
    final endDate = _getEffectiveEndDate(now);

    final Map<int, double> expenseByCategory = {};
    final Map<int, double> incomeByCategory = {};
    double totalFutureExpense = 0;
    double totalFutureIncome = 0;
    double recurringOutflow = 0;
    double oneTimeOutflow = 0;

    for (var tx in widget.transactions) {
      if (_selectedOwner != 'All Owners' && tx.owner != _selectedOwner) continue;
      if (_selectedPool != 'All Pools' && tx.pool.toLowerCase() != _selectedPool.toLowerCase()) continue;
      if (_selectedLabelIds.isNotEmpty && !_selectedLabelIds.contains(tx.labelId)) continue;

      final dt = DateTime.tryParse(tx.createdAt);
      if (dt == null || dt.isBefore(startDate) || dt.isAfter(endDate)) continue;

      if (tx.type == 'expense') {
        expenseByCategory[tx.labelId] = (expenseByCategory[tx.labelId] ?? 0.0) + tx.amount;
        totalFutureExpense += tx.amount;
        
        if (_isRecurringTransaction(tx, widget.labels)) {
          recurringOutflow += tx.amount;
        } else {
          oneTimeOutflow += tx.amount;
        }
      } else if (tx.type == 'income') {
        incomeByCategory[tx.labelId] = (incomeByCategory[tx.labelId] ?? 0.0) + tx.amount;
        totalFutureIncome += tx.amount;
      }
    }

    final netBalance = totalFutureIncome - totalFutureExpense;
    final labelMap = {for (var l in widget.labels) l.id: l};

    final sortedExpenses = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final double availableWidth = MediaQuery.of(context).size.width - 32;
    final double boxWidth = (availableWidth - 12) / 2;
    final bool hasDateFilter = _timeframe == 'Custom' && _customStartDate != null;

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
                    'FUTURE ANALYTICS ',
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
                    onPressed: () => _showFutureAnalyticsInfoModal(context),
                    tooltip: 'Future Analytics',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onJumpToMetrics != null) ...[
                    Tooltip(
                      message: 'Jump to Future Metrics',
                      child: InkWell(
                        onTap: widget.onJumpToMetrics,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF3D256B) : const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _isZaznamityMode ? const Color(0xFFA855F7).withValues(alpha: 0.4) : const Color(0xFFDDD6FE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.insights_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95)),
                              const SizedBox(width: 4),
                              Text(
                                'Metrics',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
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
                                if (val != null) setState(() => _selectedPool = val);
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
                                    color: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
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

            // Timeframe Selector Pills ('Current Month', '90 Days', '1 Year') & Date Range Picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: boxWidth,
                  child: Row(
                    children: ['Current Month', '90 Days', '1 Year'].map((tf) {
                      final isSelected = _timeframe == tf;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: tf != '1 Year' ? 4 : 0),
                          child: InkWell(
                            onTap: () => setState(() => _timeframe = tf),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? (_isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95)) 
                                    : (_isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                              ),
                              alignment: Alignment.center,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Text(
                                  tf == 'Current Month' ? 'Month' : tf,
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
                                            ? '${DateFormat('MM/dd').format(_customStartDate!)} - ${DateFormat('MM/dd').format(_customEndDate!)}'
                                            : 'Date Range',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: hasDateFilter ? (_isZaznamityMode ? Colors.white : const Color(0xFF334155)) : (_isZaznamityMode ? Colors.white54 : const Color(0xFF94A3B8)),
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
                              onTap: () => setState(() {
                                _timeframe = '90 Days';
                                _customStartDate = null;
                                _customEndDate = null;
                              }),
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

            // Net Balance Box
            Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'NET BALANCE',
                        style: TextStyle(
                          color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'The net cash flow resulting from total future inflows minus total outflows from today onwards[cite: 12].',
                        child: Icon(Icons.info_outline, size: 13, color: _isZaznamityMode ? Colors.white54 : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(netBalance, isExpense: netBalance < 0),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: netBalance >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick totals preview (Expected Inflow & Expected Outflow)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EXPECTED OUTFLOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey)),
                        const SizedBox(height: 2),
                        Text(_formatCurrency(totalFutureExpense, isExpense: true), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EXPECTED INFLOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey)),
                        const SizedBox(height: 2),
                        Text(_formatCurrency(totalFutureIncome), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Recurring vs One-Time Split Summary Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('RECURRING OUTFLOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade700)),
                      const SizedBox(height: 2),
                      Text(_formatCurrency(recurringOutflow, isExpense: true), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
                    ],
                  ),
                  Container(height: 24, width: 1, color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  Column(
                    children: [
                      Text('ONE-TIME OUTFLOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade700)),
                      const SizedBox(height: 2),
                      Text(_formatCurrency(oneTimeOutflow, isExpense: true), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Top Upcoming Expense Categories Header
            Text(
              'UPCOMING EXPENSE LABELS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade700, letterSpacing: 0.6),
            ),
            const SizedBox(height: 6),

            sortedExpenses.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No scheduled expenses for this period',
                        style: TextStyle(fontSize: 11, color: _isZaznamityMode ? Colors.white38 : Colors.grey),
                      ),
                    ),
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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
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
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: label?.color != null 
                                                  ? Color(int.parse(label!.color!.replaceFirst('#', '0xFF'))) 
                                                  : const Color(0xFFA855F7),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            labelName,
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _formatCurrency(amount, isExpense: true),
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF334155)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: percentage.clamp(0.0, 1.0),
                                      backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFE2E8F0),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        label?.color != null 
                                            ? Color(int.parse(label!.color!.replaceFirst('#', '0xFF'))) 
                                            : const Color(0xFFA855F7),
                                      ),
                                      minHeight: 4,
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
          ],
        ],
      ),
    );
  }
}