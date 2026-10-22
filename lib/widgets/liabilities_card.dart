// ignore_for_file: unnecessary_this, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiabilityItem {
  final String id;
  final String name;
  final double remainingBalance;
  final double monthlyInstallment;
  final double interestRate;
  final int dueDay;
  final String owner;
  final String? projectionEndDate;

  LiabilityItem({
    required this.id,
    required this.name,
    required this.remainingBalance,
    required this.monthlyInstallment,
    required this.interestRate,
    required this.dueDay,
    required this.owner,
    this.projectionEndDate,
  });
}

class LiabilitiesCard extends StatefulWidget {
  final List<LiabilityItem> liabilities;
  final List<String> owners;
  final String? selectedOwner;
  final String currencySymbol;
  final Function(LiabilityItem) onSaveLiability;
  final VoidCallback? onAddLiability;
  final Function(String liabilityId, String liabilityName) onDeleteLiability;
  final bool isWide;
  final VoidCallback? onToggleWidth;
  final VoidCallback? onHide;

  const LiabilitiesCard({
    super.key,
    required this.liabilities,
    required this.owners,
    required this.selectedOwner,
    this.currencySymbol = '€',
    required this.onSaveLiability,
    this.onAddLiability,
    required this.onDeleteLiability,
    required this.isWide,
    this.onToggleWidth,
    this.onHide,
  });

  @override
  State<LiabilitiesCard> createState() => _LiabilitiesCardState();
}

class _LiabilitiesCardState extends State<LiabilitiesCard> {
  bool _isZaznamityMode = true;
  late String _selectedOwner;

  @override
  void initState() {
    super.initState();
    _selectedOwner = widget.selectedOwner ?? 'All Owners';
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
      });
    }
  }

  @override
  void didUpdateWidget(covariant LiabilitiesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOwner != oldWidget.selectedOwner) {
      setState(() {
        _selectedOwner = widget.selectedOwner ?? 'All Owners';
      });
    }
    _loadPrefs();
  }

  void _showLiabilityInfoModal(BuildContext context) {
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
                  'Liability Setup Guide',
                  style: TextStyle(
                    color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'For the cleanest and most accurate tracking, we recommend:\n\n'
                  '• Enter your current actual remaining liability balance from your latest statement.\n'
                  '• Enter your current active monthly installment.\n'
                  '• Set your due day and current interest rate.\n'
                  '• Choose the projection end date until which payment installments should be scheduled in ledger history.\n\n'
                  'When you create a liability, a corresponding [name (L)] label is automatically created, and upcoming amortization installments are scheduled into your calendar and All Zaznams ledger!',
                  style: TextStyle(
                    fontSize: 13,
                    color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ],
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

  void _showAddLiabilityDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController balanceController = TextEditingController();
    final TextEditingController installmentController = TextEditingController();
    final TextEditingController interestController = TextEditingController();
    final TextEditingController dueDayController = TextEditingController(text: '1');
    DateTime selectedProjectionDate = DateTime.now().add(const Duration(days: 365));

    String dialogOwner = (_selectedOwner != 'All Owners' && widget.owners.contains(_selectedOwner))
        ? _selectedOwner
        : (widget.owners.isNotEmpty ? widget.owners.first : 'Shared');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Add New Liability',
            style: TextStyle(
              color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Liability Name (e.g. Mortgage)',
                      labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                      filled: true,
                      fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: balanceController,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Remaining Balance (${widget.currencySymbol})',
                      labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                      filled: true,
                      fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: installmentController,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monthly Installment (${widget.currencySymbol})',
                      labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                      filled: true,
                      fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: interestController,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Interest Rate (%)',
                            labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            filled: true,
                            fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: dueDayController,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Due Day',
                            labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            filled: true,
                            fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: widget.owners.contains(dialogOwner) ? dialogOwner : widget.owners.first,
                    dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                    style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Owner',
                      labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                      filled: true,
                      fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                    ),
                    items: widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => dialogOwner = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Project Until: ${DateFormat('yyyy-MM-dd').format(selectedProjectionDate)}',
                        style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedProjectionDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2045),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedProjectionDate = picked);
                          }
                        },
                        child: Text('Select Date', style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                final name = nameController.text.trim();
                final balance = double.tryParse(balanceController.text) ?? 0.0;
                final installment = double.tryParse(installmentController.text) ?? 0.0;
                final interest = double.tryParse(interestController.text) ?? 0.0;
                final dueDay = int.tryParse(dueDayController.text) ?? 1;

                if (name.isNotEmpty) {
                  final newItem = LiabilityItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    remainingBalance: balance,
                    monthlyInstallment: installment,
                    interestRate: interest,
                    dueDay: dueDay,
                    owner: dialogOwner,
                    projectionEndDate: selectedProjectionDate.toIso8601String(),
                  );
                  widget.onSaveLiability(newItem);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Liability', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLiabilities = widget.liabilities.where((item) {
      if (_selectedOwner.isNotEmpty && _selectedOwner != 'All Owners') {
        return item.owner.trim().toLowerCase() == _selectedOwner.trim().toLowerCase();
      }
      return true;
    }).toList();

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
                          'LIABILITIES',
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
                        onPressed: () => _showLiabilityInfoModal(context),
                        tooltip: 'Setup Guide',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
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
                                backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                                foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: widget.onToggleWidth,
                              icon: Icon(widget.isWide ? Icons.fullscreen_exit : Icons.fullscreen, size: 16),
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
                              backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                              foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: widget.onHide,
                            icon: const Icon(Icons.visibility_off_outlined, size: 14),
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
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedOwner,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                items: [
                                  DropdownMenuItem(value: 'All Owners', child: Text('All Owners', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                  ...widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedOwner = val);
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
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFFF1F5F9),
                          foregroundColor: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _showAddLiabilityDialog(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Liability', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              filteredLiabilities.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No active liabilities tracked for this selection.',
                          style: TextStyle(
                            color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredLiabilities.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filteredLiabilities[index];
                        
                        double estimatedInitial = item.remainingBalance + (item.monthlyInstallment * 12); 
                        if (estimatedInitial <= 0) estimatedInitial = item.remainingBalance > 0 ? item.remainingBalance * 1.5 : 1000.0;
                        double progressRatio = (1.0 - (item.remainingBalance / estimatedInitial)).clamp(0.0, 1.0);

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => widget.onDeleteLiability(item.id, item.name),
                                    child: Icon(Icons.close, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8), size: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progressRatio,
                                  minHeight: 10,
                                  backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Balance: ${widget.currencySymbol}${item.remainingBalance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155),
                                    ),
                                  ),
                                  Text(
                                    'Installment: ${widget.currencySymbol}${item.monthlyInstallment.toStringAsFixed(2)} (Due: ${item.dueDay})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
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