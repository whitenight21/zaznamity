// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaznamity/models/transaction_model.dart';

class CalendarCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<String> owners;
  final String? selectedOwner;
  final Function(String?) onOwnerChanged;
  final bool isWide;
  final VoidCallback onToggleWidth;
  final VoidCallback onHide;
  final Function(DateTime) onDateSelected;
  final GlobalKey? historyKey;
  final VoidCallback? onClearFilters;
  final ValueChanged<Set<String>>? onPoolsChanged; // Added to reset pools to all

  const CalendarCard({
    super.key,
    required this.transactions,
    required this.owners,
    required this.selectedOwner,
    required this.onOwnerChanged,
    required this.isWide,
    required this.onToggleWidth,
    required this.onHide,
    required this.onDateSelected,
    this.historyKey,
    this.onClearFilters,
    this.onPoolsChanged,
  });

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  late DateTime _displayedMonth;
  String _calendarStartDay = 'Monday';
  bool _isZaznamityMode = true;
  String _selectedPool = 'All Pools';

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _loadCalendarPrefs();
  }

  Future<void> _loadCalendarPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _calendarStartDay = prefs.getString('calendarStartDay') ?? 'Monday';
      final themeStr = prefs.getString('app_theme') ?? 'zaznamity';
      _isZaznamityMode = (themeStr == 'zaznamity');
    });
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }

  void _handleDateTap(DateTime currentDate) {
    if (widget.onClearFilters != null) {
      widget.onClearFilters!();
    }

    // Automatically select all pools by default when clicking a calendar date
    if (widget.onPoolsChanged != null) {
      final allPools = widget.transactions
          .map((tx) => tx.pool)
          .where((pool) => pool.isNotEmpty)
          .toSet();
      widget.onPoolsChanged!(allPools);
    }

    widget.onDateSelected(currentDate);

    if (widget.historyKey != null && widget.historyKey!.currentContext != null) {
      Scrollable.ensureVisible(
        widget.historyKey!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showCalendarInfoModal(BuildContext context) {
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
                  'Calendar Guide',
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
              'The calendar is fully interactive:\n\n'
              '• Press any day containing transaction data to jump directly to "All Zaznams".\n'
              '• Selecting a day will automatically filter the transaction ledger to show all entries recorded for that specific date with all pools visible by default.\n'
              '• Use the pool dropdown to filter income and expense summaries by a specific financial pool.',
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

  @override
  Widget build(BuildContext context) {
    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString('app_theme') ?? 'zaznamity';
      final zaznamityActive = (themeStr == 'zaznamity');
      if (zaznamityActive != _isZaznamityMode && mounted) {
        setState(() {
          _isZaznamityMode = zaznamityActive;
        });
      }
    });

    final List<String> availablePools = widget.transactions
        .map((tx) => tx.pool)
        .where((pool) => pool.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final filteredTransactions = widget.transactions.where((tx) {
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && widget.selectedOwner != 'All Owners') {
        if (tx.owner != widget.selectedOwner) return false;
      }
      if (_selectedPool != 'All Pools') {
        if (tx.pool.toLowerCase() != _selectedPool.toLowerCase()) return false;
      }
      return true;
    }).toList();

    final Map<String, double> incomeByDate = {};
    final Map<String, double> expenseByDate = {};
    final Map<String, List<TransactionModel>> txByDate = {};

    for (var tx in filteredTransactions) {
      final parsed = DateTime.tryParse(tx.createdAt);
      if (parsed != null && (tx.isConfirmed == 1 || tx.isConfirmed == 0)) {
        final localDate = parsed.toLocal();
        final key = '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
        
        txByDate.putIfAbsent(key, () => []).add(tx);

        if (tx.type == 'income') {
          incomeByDate[key] = (incomeByDate[key] ?? 0.0) + tx.amount;
        } else if (tx.type == 'expense') {
          expenseByDate[key] = (expenseByDate[key] ?? 0.0) + tx.amount;
        }
      }
    }

    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    
    int rawWeekday = firstDayOfMonth.weekday;
    int startingWeekday;
    List<String> weekdays;

    if (_calendarStartDay == 'Sunday') {
      weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      startingWeekday = rawWeekday == 7 ? 1 : rawWeekday + 1;
    } else {
      weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      startingWeekday = rawWeekday;
    }

    final List<Widget> weekdayWidgets = [];
    for (var day in weekdays) {
      weekdayWidgets.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final List<Widget> flatCells = [];
    for (int i = 1; i < startingWeekday; i++) {
      flatCells.add(const SizedBox.shrink());
    }

    final now = DateTime.now();

    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final currentDate = DateTime(_displayedMonth.year, _displayedMonth.month, day);
      final dateKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
      
      final hasTx = txByDate.containsKey(dateKey);
      final isToday = currentDate.year == now.year &&
          currentDate.month == now.month &&
          currentDate.day == now.day;
      final isWeekend = currentDate.weekday == DateTime.saturday || currentDate.weekday == DateTime.sunday;

      final double dayIncome = incomeByDate[dateKey] ?? 0.0;
      final double dayExpense = expenseByDate[dateKey] ?? 0.0;

      flatCells.add(
        Padding(
          padding: const EdgeInsets.all(1.5),
          child: InkWell(
            onTap: () => _handleDateTap(currentDate),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: isWeekend
                    ? LinearGradient(
                        colors: _isZaznamityMode
                            ? [const Color(0xFF2A1E3C), const Color(0xFF1E142B)]
                            : [const Color(0xFFF3E8FF), const Color(0xFFFAF5FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isWeekend
                    ? null
                    : (hasTx
                        ? (_isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC))
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isToday
                      ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                      : (hasTx
                          ? (_isZaznamityMode ? const Color(0xFF3B1E63) : const Color(0xFFE2E8F0))
                          : Colors.transparent),
                  width: isToday ? 1.5 : 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: (hasTx || isToday) ? FontWeight.bold : FontWeight.normal,
                        color: isToday
                            ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                            : (hasTx
                                ? (_isZaznamityMode ? Colors.white : const Color(0xFF1E293B))
                                : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8))),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (dayIncome > 0)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '+${dayIncome.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  if (dayExpense > 0)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '-${dayExpense.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    while (flatCells.length % 7 != 0) {
      flatCells.add(const SizedBox.shrink());
    }

    final List<TableRow> tableRows = [];
    for (int i = 0; i < flatCells.length; i += 7) {
      tableRows.add(
        TableRow(
          children: flatCells.sublist(i, i + 7),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 32;
        final double boxWidth = (fullWidth - 12) / 2;

        return Container(
          padding: const EdgeInsets.all(16),
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
                  Row(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'CALENDAR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.info_outline, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
                        onPressed: () => _showCalendarInfoModal(context),
                        tooltip: 'Calendar Guide',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: SizedBox(
                          height: 28,
                          width: 28,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                              foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: widget.onToggleWidth,
                            icon: Icon(
                              widget.isWide
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              size: 16,
                            ),
                            tooltip: widget.isWide ? 'Narrow' : 'Wide',
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 28,
                        width: 28,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                            foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: widget.onHide,
                          icon: const Icon(
                            Icons.visibility_off_outlined,
                            size: 14,
                          ),
                          tooltip: 'Hide',
                        ),
                      ),
                    ],
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
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 20, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedPool,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                items: [
                                  const DropdownMenuItem(value: 'All Pools', child: Text('All Pools')),
                                  ...availablePools.map((pool) => DropdownMenuItem(
                                        value: pool,
                                        child: Text(pool.toUpperCase(), style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                      )),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedPool = val;
                                    });
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
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 18, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('MMM yyyy').format(_displayedMonth),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: _previousMonth,
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(Icons.chevron_left, size: 18, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                ),
                              ),
                              InkWell(
                                onTap: _nextMonth,
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(Icons.chevron_right, size: 18, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Table(
                children: [
                  TableRow(children: weekdayWidgets),
                ],
              ),
              const SizedBox(height: 4),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                  4: FlexColumnWidth(1),
                  5: FlexColumnWidth(1),
                  6: FlexColumnWidth(1),
                },
                children: tableRows,
              ),
            ],
          ),
        );
      },
    );
  }
}