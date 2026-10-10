import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    final filteredTransactions = widget.transactions.where((tx) {
      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty) {
        return tx.owner == widget.selectedOwner;
      }
      return true;
    }).toList();

    // Group confirmed transactions by date for daily totals calculation
    final Map<String, double> incomeByDate = {};
    final Map<String, double> expenseByDate = {};
    final Map<String, List<TransactionModel>> txByDate = {};

    for (var tx in filteredTransactions) {
      final date = DateTime.tryParse(tx.createdAt);
      if (date != null && tx.isConfirmed == 1) {
        final key = DateFormat('yyyy-MM-dd').format(date);
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
      final hasTx = txByDate.containsKey(dateKey);

      final isToday = currentDate.year == now.year &&
          currentDate.month == now.month &&
          currentDate.day == now.day;

      final double dayIncome = incomeByDate[dateKey] ?? 0.0;
      final double dayExpense = expenseByDate[dateKey] ?? 0.0;

      flatCells.add(
        Padding(
          padding: const EdgeInsets.all(1.5),
          child: InkWell(
            onTap: () => _handleDateTap(currentDate),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 52, // Increased height to comfortably fit totals
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
                            ? const Color.fromARGB(255, 88, 47, 149)
                            : (hasTx ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: widget.selectedOwner ?? 'All Owners',
                            isDense: true,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF582F95),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'All Owners',
                                child: Text('All Owners'),
                              ),
                              ...widget.owners.map(
                                (o) => DropdownMenuItem(
                                  value: o,
                                  child: Text(o),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                widget.onOwnerChanged(val == 'All Owners' ? null : val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: widget.onToggleWidth,
                            icon: Icon(
                              widget.isWide
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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