import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/label.dart';
import '../models/transaction_model.dart';

class BudgetProgressCard extends StatefulWidget {
  final List<Map<String, dynamic>> budgets;
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final Function(int labelId, double limitAmount) onAddBudget;
  final Function(int budgetId) onDeleteBudget;
  
  final bool isWide;
  final VoidCallback onToggleWidth;
  final VoidCallback onHide;

  const BudgetProgressCard({
    super.key,
    required this.budgets,
    required this.transactions,
    required this.labels,
    required this.onAddBudget,
    required this.onDeleteBudget,
    required this.isWide,
    required this.onToggleWidth,
    required this.onHide,
  });

  @override
  State<BudgetProgressCard> createState() => _BudgetProgressCardState();
}

class _BudgetProgressCardState extends State<BudgetProgressCard> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Select Month',
      fieldLabelText: 'Month/Year',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  void _showAddBudgetDialog(BuildContext context) {
    int? selectedLabelId = widget.labels.isNotEmpty ? widget.labels.first.id : null;
    final limitController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Budget Limit', style: TextStyle(color: Color.fromARGB(255, 88, 47, 149), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedLabelId,
                decoration: InputDecoration(
                  labelText: 'Select Category / Label',
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
                items: widget.labels.map((label) {
                  return DropdownMenuItem<int>(
                    value: label.id,
                    child: Text(label.name, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  setDialogState(() => selectedLabelId = val);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Monthly Limit (\$)',
                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64748B),
                foregroundColor: const Color.fromARGB(255, 88, 47, 149),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                final limit = double.tryParse(limitController.text);
                if (selectedLabelId != null && limit != null && limit > 0) {
                  widget.onAddBudget(selectedLabelId!, limit);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    double totalSpentAll = 0;
    double totalLimitAll = 0;

    List<Map<String, dynamic>> processedBudgets = widget.budgets.map((b) {
      final labelId = b['label_id'];
      final limit = (b['limit_amount'] as num).toDouble();
      
      double spent = 0;
      for (var tx in widget.transactions) {
        if (tx.labelId == labelId && tx.type == 'expense' && tx.isConfirmed == 1) {
          final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
          if (txDate.year == _selectedMonth.year && txDate.month == _selectedMonth.month) {
            spent += tx.amount;
          }
        }
      }

      totalSpentAll += spent;
      totalLimitAll += limit;

      return {
        'id': b['id'],
        'label_name': b['label_name'] ?? 'General',
        'label_color': b['label_color'] ?? '#582F95',
        'spent': spent,
        'limit': limit,
      };
    }).toList();

    double overallProgress = totalLimitAll > 0 ? (totalSpentAll / totalLimitAll).clamp(0.0, 1.0) : 0.0;

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
          // Header Row with Title and Fullscreen/Hide Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'BUDGET PROGRESS',
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
          const SizedBox(height: 14),

          // Underneath Title: Purple Plus Button & Month Picker Box
          Row(
            children: [
              // Purple Plus Button
              SizedBox(
                height: 42,
                width: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF64748B),
                    foregroundColor: const Color.fromARGB(255, 88, 47, 149),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () => _showAddBudgetDialog(context),
                  child: const Icon(Icons.add, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              // Month Picker Field matching reference style
              Expanded(
                child: InkWell(
                  onTap: () => _selectMonth(context),
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'MONTH',
                      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Overall Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${currencyFormat.format(totalSpentAll)} / ${currencyFormat.format(totalLimitAll)}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                '${(overallProgress * 100).toStringAsFixed(0)}% Spent',
                style: TextStyle(
                  color: overallProgress > 0.9 ? Colors.red.shade700 : Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                overallProgress > 0.9 ? Colors.red.shade700 : const Color.fromARGB(255, 88, 47, 149),
              ),
            ),
          ),
          const SizedBox(height: 20),

          processedBudgets.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: Text(
                      'No budget limits set. Tap "+" to add one.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: processedBudgets.length,
                  itemBuilder: (context, index) {
                    final b = processedBudgets[index];
                    final spent = b['spent'] as double;
                    final limit = b['limit'] as double;
                    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
                    final isOverBudget = spent > limit;
                    final colorHex = b['label_color'].toString().replaceAll('#', '');
                    final cardColor = Color(int.parse('0xFF$colorHex'));

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    b['label_name'],
                                    style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${currencyFormat.format(spent)} / ${currencyFormat.format(limit)}',
                                    style: TextStyle(
                                      color: isOverBudget ? Colors.red.shade700 : const Color(0xFF64748B),
                                      fontSize: 13,
                                      fontWeight: isOverBudget ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => widget.onDeleteBudget(b['id']),
                                    child: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 16),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: const Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isOverBudget ? Colors.red.shade700 : cardColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}