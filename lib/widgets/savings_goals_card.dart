import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/savings_goal_model.dart';
import '../models/label.dart';

class SavingsGoalsCard extends StatefulWidget {
  final List<SavingsGoalModel> goals;
  final List<LabelModel> labels;
  final List<String> owners;
  final List<String> pools;
  final String? selectedOwner;
  final Function(SavingsGoalModel) onSaveGoal;
  final Function(int goalId, double amountToAdd, String owner, String fromPool, String goalName) onAddFundsToGoal;
  final Function(int goalId) onDeleteGoal;
  final Function(int goalId) onCompleteGoal;
  final bool isWide;
  final VoidCallback? onToggleWidth;
  final VoidCallback? onHide;

  const SavingsGoalsCard({
    super.key,
    required this.goals,
    required this.labels,
    required this.owners,
    required this.pools,
    this.selectedOwner,
    required this.onSaveGoal,
    required this.onAddFundsToGoal,
    required this.onDeleteGoal,
    required this.onCompleteGoal,
    this.isWide = false,
    this.onToggleWidth,
    this.onHide,
  });

  @override
  State<SavingsGoalsCard> createState() => _SavingsGoalsCardState();
}

class _SavingsGoalsCardState extends State<SavingsGoalsCard> {
  late String _selectedOwner;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _selectedOwner = widget.selectedOwner ?? 'All Owners';
  }

  @override
  void didUpdateWidget(covariant SavingsGoalsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOwner != oldWidget.selectedOwner) {
      setState(() {
        _selectedOwner = widget.selectedOwner ?? 'All Owners';
      });
    }
  }

  void _showAddFundsDialog(SavingsGoalModel goal) {
    final TextEditingController amountController = TextEditingController();
    String selectedDialogOwner = (_selectedOwner != 'All Owners' && _selectedOwner.isNotEmpty)
        ? _selectedOwner
        : (widget.owners.isNotEmpty ? widget.owners.first : 'Shared');
    
    String selectedDialogPool = widget.pools.isNotEmpty ? widget.pools.first : 'checking';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add Funds to "${goal.name}"', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: widget.owners.contains(selectedDialogOwner) ? selectedDialogOwner : widget.owners.first,
                      decoration: const InputDecoration(labelText: 'Owner', border: OutlineInputBorder()),
                      items: widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedDialogOwner = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: widget.pools.contains(selectedDialogPool) ? selectedDialogPool : widget.pools.first,
                      decoration: const InputDecoration(labelText: 'From Pool (Source)', border: OutlineInputBorder()),
                      items: widget.pools.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedDialogPool = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Amount to Add (\$)', hintText: '50.00', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF582F95), foregroundColor: Colors.white),
                          onPressed: () {
                            final val = double.tryParse(amountController.text);
                            if (val != null && val > 0) {
                              widget.onAddFundsToGoal(goal.id!, val, selectedDialogOwner, selectedDialogPool, goal.name);
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('Add Funds'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showCreateGoalDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController targetController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create New Savings Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Goal Name (e.g. New Car)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: targetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Target Amount (\$)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF582F95), foregroundColor: Colors.white),
                      onPressed: () {
                        final name = nameController.text.trim();
                        final target = double.tryParse(targetController.text);
                        if (name.isNotEmpty && target != null && target > 0) {
                          final newGoal = SavingsGoalModel(
                            name: name,
                            targetAmount: target,
                            currentAmount: 0.0,
                          );
                          widget.onSaveGoal(newGoal);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Create Goal'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 32;
        final double boxWidth = (fullWidth - 12) / 2;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Title & Action Buttons (Wide / Hide) matching Future Metrics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SAVINGS GOALS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF582F95),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onToggleWidth != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: SizedBox(
                            height: 28,
                            width: 28,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFF1F5F9),
                                foregroundColor: const Color(0xFF64748B),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: widget.onToggleWidth,
                              icon: Icon(
                                widget.isWide ? Icons.fullscreen_exit : Icons.fullscreen,
                                size: 16,
                              ),
                              tooltip: widget.isWide ? 'Narrow' : 'Wide',
                            ),
                          ),
                        ),
                      if (widget.onHide != null)
                        SizedBox(
                          height: 28,
                          width: 28,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF64748B),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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

              // Second Row: Owners Dropdown (Left) & New Goal Button (Right) matching Future Metrics sizing
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
                              child: DropdownButton<String>(
                                value: _selectedOwner,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                items: [
                                  const DropdownMenuItem(value: 'All Owners', child: Text('All Owners')),
                                  ...widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o))),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedOwner = val);
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
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF582F95),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _showCreateGoalDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Goal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Goals List
              widget.goals.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No savings goals set yet. Create one above!',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.goals.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final goal = widget.goals[index];
                        final double progress = goal.targetAmount > 0 
                            ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0) 
                            : 0.0;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        // Complete Checkmark placed directly before Goal Name on the left
                                        SizedBox(
                                          height: 26,
                                          width: 26,
                                          child: IconButton(
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.green.shade600,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.zero,
                                            ),
                                            icon: const Icon(Icons.check, size: 14),
                                            tooltip: 'Complete Goal',
                                            onPressed: () => widget.onCompleteGoal(goal.id!),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            goal.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF1E293B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Target: ${_currencyFormat.format(goal.targetAmount)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: 28,
                                        width: 28,
                                        child: IconButton(
                                          style: IconButton.styleFrom(
                                            backgroundColor: const Color(0xFF582F95),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.zero,
                                          ),
                                          icon: const Icon(Icons.add, size: 16),
                                          tooltip: 'Add funds to goal',
                                          onPressed: () => _showAddFundsDialog(goal),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () => widget.onDeleteGoal(goal.id!),
                                        child: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 16),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 10,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Saved: ${_currencyFormat.format(goal.currentAmount)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
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