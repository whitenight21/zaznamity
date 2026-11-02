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

  const FutureAnalyticsCard({
    super.key,
    required this.owners,
    this.selectedOwner,
    required this.pools,
    this.selectedPool,
    required this.transactions,
    required this.labels,
    this.onJumpToHistoryForLabel,
  });

  @override
  State<FutureAnalyticsCard> createState() => _FutureAnalyticsCardState();
}

class _FutureAnalyticsCardState extends State<FutureAnalyticsCard> {
  late String _selectedOwner;
  late String _selectedPool;
  String _timeframe = '30 Days'; // '30 Days', '90 Days', '1 Year'
  bool _isZaznamityMode = true;
  bool _isCollapsed = false;

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
              'Future Analytics provides insights into your projected spending patterns and helps you make informed financial decisions.\n'
              '• It breaks down upcoming scheduled income and expenses by category label over your selected future window.\n'
              '• The analysis is based on your existing Zaznams and their associated labels, allowing you to anticipate cash flow and plan accordingly.\n'
              '• Use the timeframe selector to view projections for 30 days, 90 days, or 1 year into the future.\n'
              '• You can filter the analysis by owner and pool to focus on specific segments of your finances.\n'
              '• The analysis is updated in real-time as you add new Zaznams, ensuring that you always have the most accurate projections.\n'
              '• To view detailed records for a specific label, tap on the label in the list to jump to "All Zaznams" within the selected timeframe.\n\n',
              
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

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    return format.format(amount);
  }

  int _getTargetDays() {
    if (_timeframe == '90 Days') return 90;
    if (_timeframe == '1 Year') return 365;
    return 30;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final horizonDays = _getTargetDays();
    final endDate = now.add(Duration(days: horizonDays));

    // Filter future transactions matching owner, pool, and timeframe window
    final Map<int, double> expenseByCategory = {};
    final Map<int, double> incomeByCategory = {};
    double totalFutureExpense = 0;
    double totalFutureIncome = 0;

    for (var tx in widget.transactions) {
      if (_selectedOwner != 'All Owners' && tx.owner != _selectedOwner) continue;
      if (_selectedPool != 'All Pools' && tx.pool.toLowerCase() != _selectedPool.toLowerCase()) continue;

      final dt = DateTime.tryParse(tx.createdAt);
      if (dt == null || !dt.isAfter(now) || dt.isAfter(endDate)) continue;

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
          // Header Row
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
                  Tooltip(
                    message: 'Breaks down upcoming scheduled income and expenses by category label over your selected future window.',
                    child: Icon(Icons.info_outline_rounded, size: 15, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
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
          if (!_isCollapsed) ...[
            const SizedBox(height: 12),

            // Timeframe Selector & Summary Pills
            Row(
              children: ['30 Days', '90 Days', '1 Year'].map((tf) {
                final isSelected = _timeframe == tf;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: tf != '1 Year' ? 6 : 0),
                    child: InkWell(
                      onTap: () => setState(() => _timeframe = tf),
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? (_isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95)) 
                              : (_isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tf,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : (_isZaznamityMode ? Colors.white70 : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Quick totals preview
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
                        Text(_formatCurrency(totalFutureExpense), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
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
                        Text(_formatCurrency(totalFutureIncome), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top Upcoming Expense Categories Header
            Text(
              'UPCOMING EXPENSE LABELS ($_timeframe)',
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
                                widget.onJumpToHistoryForLabel!(labelId, labelName, now, endDate);
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
                                        _formatCurrency(amount),
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