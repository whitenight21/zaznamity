import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/label.dart';

class NewZaznamCard extends StatefulWidget {
  final List<LabelModel> labels;
  final List<String> pools;
  final Function(
    String description,
    double amount,
    String type,
    int? labelId,
    String owner,
    String pool,
    bool isRecurring,
    String frequency,
    int dayOfMonth,
    List<int> excludedWeekdays, // 1 = Monday ... 7 = Sunday
    List<int> excludedMonths,   // 1 = January ... 12 = December
    DateTime? repeatUntilDate,
    DateTime date,
  ) onSubmit;
  final VoidCallback? onHide;
  final VoidCallback? onToggleWidth;
  final bool isWide;

  const NewZaznamCard({
    super.key,
    required this.labels,
    required this.pools,
    required this.onSubmit,
    this.onHide,
    this.onToggleWidth,
    this.isWide = false,
  });

  @override
  State<NewZaznamCard> createState() => _NewZaznamCardState();
}

class _NewZaznamCardState extends State<NewZaznamCard> {
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  String _type = 'expense';
  int? _selectedLabelId;
  String _owner = 'Mathias';
  late String _selectedPool;
  bool _isRecurring = false;
  
  String _frequency = 'Monthly';
  int _dayOfMonth = 1;
  DateTime? _repeatUntilDate;

  // Exclusions state
  final List<int> _excludedWeekdays = []; // e.g., [6, 7] for Sat, Sun
  final List<int> _excludedMonths = [];   // e.g., [7, 8] for Jul, Aug

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _selectedPool = widget.pools.isNotEmpty ? widget.pools.first : 'checking';
    _dayOfMonth = _selectedDate.day;
  }

  @override
  void didUpdateWidget(covariant NewZaznamCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pools.isNotEmpty && !widget.pools.contains(_selectedPool)) {
      _selectedPool = widget.pools.first;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _clearForm() {
    setState(() {
      _descController.clear();
      _amountController.clear();
      _type = 'expense';
      _selectedLabelId = null;
      _owner = 'Mathias';
      _selectedPool = widget.pools.isNotEmpty ? widget.pools.first : 'checking';
      _isRecurring = false;
      _frequency = 'Monthly';
      _selectedDate = DateTime.now();
      _dayOfMonth = _selectedDate.day;
      _selectedTime = TimeOfDay.now();
      _repeatUntilDate = null;
      _excludedWeekdays.clear();
      _excludedMonths.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'NEW ZAZNAM',
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
                      if (widget.onToggleWidth != null)
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
                      if (widget.onHide != null)
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

              // Date & Time Selectors
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = picked;
                                _dayOfMonth = picked.day;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              suffixIcon: const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(DateFormat('MM/dd/yyyy').format(_selectedDate), style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime,
                            );
                            if (picked != null) setState(() => _selectedTime = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              suffixIcon: const Icon(Icons.access_time, size: 14, color: Colors.grey),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(_selectedTime.format(context), style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Description Input
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Description',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
              ),
              const SizedBox(height: 14),

              // Amount Input & Type Picker Side-by-Side
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '0.00',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'income', child: Text('Income (+)', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'expense', child: Text('Expense (-)', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (val) => setState(() => _type = val ?? 'expense'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Label & Pool Dropdowns
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedLabelId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                      hint: const Text('Select Label', style: TextStyle(fontSize: 13)),
                      items: widget.labels.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (val) => setState(() => _selectedLabelId = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPool,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          items: widget.pools.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase(), style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) => setState(() => _selectedPool = val ?? widget.pools.first),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Wallet Owner & Recurring Button
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _owner,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Mathias', child: Text('Mathias', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 'Julia', child: Text('Julia', style: TextStyle(fontSize: 13))),
                          ],
                          onChanged: (val) => setState(() => _owner = val ?? 'Mathias'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 41,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecurring 
                              ? const Color.fromARGB(255, 88, 47, 149) 
                              : const Color(0xFFF1F5F9),
                          foregroundColor: _isRecurring 
                              ? Colors.white 
                              : const Color(0xFF334155),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: () => setState(() => _isRecurring = !_isRecurring),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isRecurring ? Icons.check_circle_rounded : Icons.repeat_rounded, 
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text(
                                'Recurring Entry',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (_isRecurring) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RECURRENCE SETTINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 88, 47, 149))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('FREQUENCY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  initialValue: _frequency,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Daily', child: Text('Daily', style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Weekly', child: Text('Weekly', style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Monthly', child: Text('Monthly', style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Yearly', child: Text('Yearly', style: TextStyle(fontSize: 12))),
                                  ],
                                  onChanged: (val) => setState(() => _frequency = val ?? 'Monthly'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('REPEAT UNTIL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _repeatUntilDate ?? _selectedDate.add(const Duration(days: 90)),
                                      firstDate: _selectedDate,
                                      lastDate: DateTime(2035),
                                    );
                                    if (picked != null) setState(() => _repeatUntilDate = picked);
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      suffixIcon: const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _repeatUntilDate != null ? DateFormat('MM/dd/yyyy').format(_repeatUntilDate!) : 'Select end date',
                                        style: TextStyle(fontSize: 12, color: _repeatUntilDate != null ? Colors.black : Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Day of month selector if Monthly
                      if (_frequency == 'Monthly') ...[
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('WHICH DAY OF MONTH', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              initialValue: _dayOfMonth,
                              isExpanded: true,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                              items: List.generate(31, (index) => index + 1).map((day) => DropdownMenuItem(
                                value: day,
                                child: Text('$day${_getDaySuffix(day)} of the month', style: const TextStyle(fontSize: 12)),
                              )).toList(),
                              onChanged: (val) => setState(() => _dayOfMonth = val ?? 1),
                            ),
                          ],
                        ),
                      ],

                      // Exclude Weekdays (Useful for Daily & Weekly)
                      if (_frequency == 'Daily' || _frequency == 'Weekly') ...[
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('EXCLUDE DAYS OF THE WEEK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              children: [
                                {'label': 'Mon', 'val': 1},
                                {'label': 'Tue', 'val': 2},
                                {'label': 'Wed', 'val': 3},
                                {'label': 'Thu', 'val': 4},
                                {'label': 'Fri', 'val': 5},
                                {'label': 'Sat', 'val': 6},
                                {'label': 'Sun', 'val': 7},
                              ].map((dayMap) {
                                final val = dayMap['val'] as int;
                                final isSelected = _excludedWeekdays.contains(val);
                                return FilterChip(
                                  label: Text(dayMap['label'] as String, style: const TextStyle(fontSize: 11)),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _excludedWeekdays.add(val);
                                      } else {
                                        _excludedWeekdays.remove(val);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],

                      // Exclude Months (Useful for Monthly & Yearly)
                      if (_frequency == 'Monthly' || _frequency == 'Yearly') ...[
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('EXCLUDE MONTHS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                {'label': 'Jan', 'val': 1},
                                {'label': 'Feb', 'val': 2},
                                {'label': 'Mar', 'val': 3},
                                {'label': 'Apr', 'val': 4},
                                {'label': 'May', 'val': 5},
                                {'label': 'Jun', 'val': 6},
                                {'label': 'Jul', 'val': 7},
                                {'label': 'Aug', 'val': 8},
                                {'label': 'Sep', 'val': 9},
                                {'label': 'Oct', 'val': 10},
                                {'label': 'Nov', 'val': 11},
                                {'label': 'Dec', 'val': 12},
                              ].map((monthMap) {
                                final val = monthMap['val'] as int;
                                final isSelected = _excludedMonths.contains(val);
                                return FilterChip(
                                  label: Text(monthMap['label'] as String, style: const TextStyle(fontSize: 11)),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _excludedMonths.add(val);
                                      } else {
                                        _excludedMonths.remove(val);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Submit Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 232, 232, 232),
                    foregroundColor: const Color.fromARGB(255, 88, 47, 149),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final amount = double.tryParse(_amountController.text) ?? 0.0;
                    if (amount <= 0) return;

                    final targetDay = _frequency == 'Monthly' ? _dayOfMonth : _selectedDate.day;
                    
                    DateTime baseDate = _selectedDate;
                    try {
                      baseDate = DateTime(_selectedDate.year, _selectedDate.month, targetDay, _selectedTime.hour, _selectedTime.minute);
                    } catch (_) {
                      baseDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, _selectedTime.hour, _selectedTime.minute);
                    }

                    widget.onSubmit(
                      _descController.text,
                      amount,
                      _type,
                      _selectedLabelId,
                      _owner,
                      _selectedPool,
                      _isRecurring,
                      _frequency,
                      targetDay,
                      _excludedWeekdays,
                      _excludedMonths,
                      _repeatUntilDate,
                      baseDate,
                    );

                    _clearForm();
                  },
                  child: const Text('Save Zaznam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
}