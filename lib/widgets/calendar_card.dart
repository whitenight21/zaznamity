import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zaznamity/models/transaction_model.dart';

class CalendarCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final bool isWide;
  final VoidCallback onToggleWidth;
  final VoidCallback onHide;
  final Function(DateTime) onDateSelected;
  final GlobalKey? historyKey;

  const CalendarCard({
    super.key,
    required this.transactions,
    required this.isWide,
    required this.onToggleWidth,
    required this.onHide,
    required this.onDateSelected,
    this.historyKey,
  });

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
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
    widget.onDateSelected(currentDate);

    if (widget.historyKey != null && widget.historyKey!.currentContext != null) {
      Scrollable.ensureVisible(
        widget.historyKey!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<TransactionModel>> txByDate = {};
    for (var tx in widget.transactions) {
      final date = DateTime.tryParse(tx.createdAt);
      if (date != null) {
        final key = DateFormat('yyyy-MM-dd').format(date);
        txByDate.putIfAbsent(key, () => []).add(tx);
      }
    }

    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    
    int startingWeekday = firstDayOfMonth.weekday;
    int totalDays = lastDayOfMonth.day;

    final List<Widget> weekdayWidgets = [];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (var day in weekdays) {
      weekdayWidgets.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                day,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
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

    for (int day = 1; day <= totalDays; day++) {
      final currentDate = DateTime(_displayedMonth.year, _displayedMonth.month, day);
      final dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
      final dayTxs = txByDate[dateKey] ?? [];
      final hasTx = dayTxs.isNotEmpty;

      final isToday = currentDate.year == now.year &&
          currentDate.month == now.month &&
          currentDate.day == now.day;

      bool hasIncome = dayTxs.any((t) => t.type == 'income' && t.isConfirmed == 1);
      bool hasExpense = dayTxs.any((t) => t.type == 'expense' && t.isConfirmed == 1);

      flatCells.add(
        Padding(
          padding: const EdgeInsets.all(1.5),
          child: InkWell(
            onTap: () => _handleDateTap(currentDate),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: hasTx ? const Color(0xFFF8FAFC) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isToday
                      ? const Color.fromARGB(255, 88, 47, 149)
                      : (hasTx ? const Color(0xFFE2E8F0) : Colors.transparent),
                  width: isToday ? 1.5 : 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: (hasTx || isToday) ? FontWeight.bold : FontWeight.normal,
                        color: isToday
                            ? const Color.fromARGB(255, 88, 47, 149)
                            : (hasTx ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasIncome)
                        Container(
                          width: 3.5,
                          height: 3.5,
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (hasExpense)
                        Container(
                          width: 3.5,
                          height: 3.5,
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'CALENDAR',
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
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        DateFormat('MMMM yyyy').format(_displayedMonth),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        onPressed: _previousMonth,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        onPressed: _nextMonth,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
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