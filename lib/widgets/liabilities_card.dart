// ignore_for_file: unnecessary_this, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:zaznamity/services/snackbar_notification.dart';
import '../services/privacy_service.dart';

class LiabilityItem {
  final String id;
  final String name;
  final double originalAmount;
  final double remainingBalance;
  final double monthlyInstallment;
  final double interestRate; 
  final int dueDay; 
  final String owner;
  final DateTime startDate;
  final String? projectionEndDate;
  final bool isBiWeekly;
  final String liabilityType;
  final String recurrenceUnit; // 'Months' or 'Weeks'
  final int recurrenceInterval;  // e.g. 1 for every month, 2 for every 2 months / bi-weekly

  LiabilityItem({
    required this.id,
    required this.name,
    required this.originalAmount,
    required this.remainingBalance,
    required this.monthlyInstallment,
    required this.interestRate,
    required this.dueDay,
    required this.owner,
    required this.startDate,
    this.projectionEndDate,
    this.isBiWeekly = false,
    this.liabilityType = 'Long-Term Loan / Mortgage',
    this.recurrenceUnit = 'Months',
    this.recurrenceInterval = 1,
  });

  LiabilityItem copyWith({
    String? name,
    double? originalAmount,
    double? remainingBalance,
    double? monthlyInstallment,
    double? interestRate,
    int? dueDay,
    String? owner,
    DateTime? startDate,
    String? projectionEndDate,
    bool? isBiWeekly,
    String? liabilityType,
    String? recurrenceUnit,
    int? recurrenceInterval,
  }) {
    return LiabilityItem(
      id: this.id,
      name: name ?? this.name,
      originalAmount: originalAmount ?? this.originalAmount,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      monthlyInstallment: monthlyInstallment ?? this.monthlyInstallment,
      interestRate: interestRate ?? this.interestRate,
      dueDay: dueDay ?? this.dueDay,
      owner: owner ?? this.owner,
      startDate: startDate ?? this.startDate,
      projectionEndDate: projectionEndDate ?? this.projectionEndDate,
      isBiWeekly: isBiWeekly ?? this.isBiWeekly,
      liabilityType: liabilityType ?? this.liabilityType,
      recurrenceUnit: recurrenceUnit ?? this.recurrenceUnit,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
    );
  }
}

class LiabilitiesCard extends StatefulWidget {
  final List<LiabilityItem> liabilities;
  final List<String> owners;
  final String? selectedOwner;
  final String currencySymbol;
  final Function(LiabilityItem) onSaveLiability;
  final VoidCallback? onAddLiability;
  final Function(String liabilityId, String liabilityName) onDeleteLiability;

  const LiabilitiesCard({
    super.key,
    required this.liabilities,
    required this.owners,
    required this.selectedOwner,
    this.currencySymbol = '€',
    required this.onSaveLiability,
    this.onAddLiability,
    required this.onDeleteLiability,
  });

  @override
  State<LiabilitiesCard> createState() => _LiabilitiesCardState();
}

class _LiabilitiesCardState extends State<LiabilitiesCard> {
  bool _isZaznamityMode = true;
  bool _isCollapsed = false;
  String _sortingMode = 'Avalanche'; // 'Avalanche' (Highest Rate) or 'Snowball' (Lowest Balance)
  double _extraPaymentSimulation = 0.0; // Extra monthly payment simulator amount

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void didUpdateWidget(covariant LiabilitiesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final collapsed = prefs.getBool('set_liabilities_collapsed') ?? false;
    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _isCollapsed = collapsed;
      });
    }
  }

  /// Formats numbers with thousands separator and places currency symbol correctly,
  /// while respecting global Privacy Mode[cite: 11].
  String _formatCurrency(double amount) {
    if (PrivacyService.instance.isPrivacyModeEnabled.value) {
      return widget.currencySymbol == '€' ? '•••••• €' : '${widget.currencySymbol}••••••';
    }

    final formatter = NumberFormat('#,##0.00', 'en_US');
    final formattedNumber = formatter.format(amount);
    final symbol = widget.currencySymbol.trim();

    const trailingSymbols = ['€', 'Ft', ' Kč', 'zł', 'CHF'];
    bool isTrailing = trailingSymbols.any((s) => symbol.toLowerCase() == s.toLowerCase());

    if (isTrailing) {
      return '$formattedNumber $symbol';
    } else {
      return '$symbol$formattedNumber';
    }
  }

  void _showLiabilityTypeSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Select Liability Type',
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
                _buildCategoryHeader('SHORT TERM'),
                _buildTypeTile(context, 'Short-Term Loans', 'Short-Term Loan'),
                _buildTypeTile(context, 'Accounts Payable (AP)', 'Accounts Payable'),
                const Divider(height: 20),
                _buildCategoryHeader('LONG TERM'),
                _buildTypeTile(context, 'Long-Term Loan / Mortgage', 'Long-Term Loan / Mortgage'),
                const Divider(height: 20),
                _buildCategoryHeader('SIMPLE'),
                _buildTypeTile(context, 'Simple month to month recurring payment', 'Simple Recurring Payment'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildTypeTile(BuildContext context, String title, String typeKey) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
      onTap: () {
        Navigator.pop(context);
        _showLiabilityDialog(context, liabilityType: typeKey);
      },
    );
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_liabilities_collapsed', _isCollapsed);
  }

  double _parseNum(String text) {
    if (text.isEmpty) return 0.0;
    final normalized = text.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0.0;
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
                  'Liabilities',
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
                  'This card tracks your loans, mortgages, and other debts clearly and effectively:\n\n'
                  '• Real Progress Tracking: Monitors real progress comparing original balance vs. current remaining balance.\n'
                  '• Amortization & Splits: Calculates interest-versus-principal payment splits, remaining months, and approximate payoff dates.\n'
                  '• Start Date Tracking: Pins down your loan origination timeline for accurate structural logging.\n'
                  '• Avalanche vs. Snowball: Sort debts by highest interest rate first (Avalanche) or lowest balance first (Snowball).\n'
                  '• Overdue Indicators: Flags payments past their scheduled due day (1–31).\n'
                  '• Split Guardian: Protects against negative amortization by verifying monthly installments cover interest.\n\n'
                  '• Tap any liability item to edit its parameters in place.',
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

  void _showLiabilityDialog(BuildContext context, {LiabilityItem? existingItem, String? liabilityType}) {
    final TextEditingController nameController = TextEditingController(text: existingItem?.name ?? '');
    final TextEditingController originalController = TextEditingController(text: existingItem != null ? '${existingItem.originalAmount}' : '');
    final TextEditingController balanceController = TextEditingController(text: existingItem != null ? '${existingItem.remainingBalance}' : '');
    final TextEditingController installmentController = TextEditingController(text: existingItem != null ? '${existingItem.monthlyInstallment}' : '');
    final TextEditingController interestController = TextEditingController(text: existingItem != null ? '${existingItem.interestRate}' : '');
    final TextEditingController dueDayController = TextEditingController(text: existingItem != null ? '${existingItem.dueDay}' : '1');
    final TextEditingController intervalController = TextEditingController(text: existingItem != null ? '${existingItem.recurrenceInterval}' : '1');
    String recurrenceUnit = existingItem?.recurrenceUnit ?? 'Months';
    
    final selectedType = existingItem?.liabilityType ?? liabilityType ?? 'Long-Term Loan / Mortgage';
    
    DateTime selectedStartDate = existingItem?.startDate ?? DateTime.now();
    DateTime selectedProjectionDate = existingItem?.projectionEndDate != null 
        ? (DateTime.tryParse(existingItem!.projectionEndDate!) ?? DateTime.now().add(const Duration(days: 365)))
        : DateTime.now().add(const Duration(days: 365));
    bool isBiWeekly = existingItem?.isBiWeekly ?? false;

    String dialogOwner = (widget.selectedOwner != null && widget.selectedOwner != 'All Owners' && widget.owners.contains(widget.selectedOwner))
        ? widget.selectedOwner!
        : (existingItem?.owner ?? (widget.owners.isNotEmpty ? widget.owners.first : 'Shared'));

    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existingItem == null ? 'Add New Liability ($selectedType)' : 'Edit Liability',
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
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.shade900.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                      child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Liability Name',
                      labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                      filled: true,
                      fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: intervalController,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Repeat Every (N)',
                            labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: recurrenceUnit,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Frequency Unit',
                            labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Months', child: Text('Months')),
                            DropdownMenuItem(value: 'Weeks', child: Text('Weeks')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => recurrenceUnit = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: originalController,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Original Amount (${widget.currencySymbol})',
                            labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            filled: true,
                            fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: balanceController,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Current Balance (${widget.currencySymbol})',
                            labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            filled: true,
                            fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Start Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedStartDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedStartDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('yyyy-MM-dd').format(selectedStartDate),
                            style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87),
                          ),
                          Icon(Icons.calendar_today_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: installmentController,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Installment Amount (${widget.currencySymbol})',
                      labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
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
                            labelText: 'Due Day (1-31)',
                            labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            filled: true,
                            fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    title: Text('Bi-Weekly Payment Schedule', style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                    value: isBiWeekly,
                    activeColor: const Color(0xFFA855F7),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() => isBiWeekly = val),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: widget.owners.contains(dialogOwner) ? dialogOwner : widget.owners.first,
                    dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                    style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Owner',
                      labelStyle: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                      filled: true,
                      fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
                    ),
                    items: widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => dialogOwner = val);
                    },
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
                backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                final name = nameController.text.trim();
                final original = _parseNum(originalController.text);
                final balance = _parseNum(balanceController.text);
                final installment = _parseNum(installmentController.text);
                final interest = _parseNum(interestController.text);
                final dueDay = int.tryParse(dueDayController.text) ?? 1;

                if (name.isEmpty) {
                  setDialogState(() => errorMessage = 'Please enter a liability name.');
                  return;
                }
                if (dueDay < 1 || dueDay > 31) {
                  setDialogState(() => errorMessage = 'Due day must be between 1 and 31.');
                  return;
                }
                
                if (selectedType != 'Simple Recurring Payment' && interest > 0) {
                  final monthlyRate = (interest / 100.0) / 12.0;
                  final monthlyInterest = balance * monthlyRate;
                  if (installment <= monthlyInterest) {
                    setDialogState(() => errorMessage = 'Error: Installment amount must exceed monthly interest (${_formatCurrency(monthlyInterest)}) to pay down debt.');
                    return;
                  }
                }

                final finalOriginal = original > 0 ? original : balance;

                final newItem = LiabilityItem(
                  id: existingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  originalAmount: finalOriginal,
                  remainingBalance: balance,
                  monthlyInstallment: installment,
                  interestRate: interest,
                  dueDay: dueDay,
                  owner: dialogOwner,
                  startDate: selectedStartDate,
                  projectionEndDate: selectedProjectionDate.toIso8601String(),
                  isBiWeekly: isBiWeekly,
                  liabilityType: selectedType,
                  recurrenceUnit: recurrenceUnit,
                  recurrenceInterval: int.tryParse(intervalController.text) ?? 1,
                );
                
                widget.onSaveLiability(newItem);
                Navigator.pop(context);
              },
              child: Text(existingItem == null ? 'Add Liability' : 'Save Changes', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showWindfallDialog(BuildContext context, LiabilityItem item) {
    final TextEditingController windfallController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        title: Text('Windfall / Lump-Sum Payment', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95), fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Apply a lump-sum payment to ${item.name}:', style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 12),
            TextField(
              controller: windfallController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Windfall Amount (${widget.currencySymbol})',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final amount = _parseNum(windfallController.text);
              if (amount > 0) {
                final newBalance = math.max(0.0, item.remainingBalance - amount);
                final updated = item.copyWith(remainingBalance: newBalance);
                widget.onSaveLiability(updated);
                Navigator.pop(context);
              }
            },
            child: const Text('Apply Windfall'),
          ),
        ],
      ),
    );
  }

  void _showRecastDialog(BuildContext context, LiabilityItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        title: Text('Mortgage Recasting', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95), fontSize: 16)),
        content: Text(
          'Recasting recalculates your installment based on your current balance and remaining amortization term without changing your interest rate.',
          style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              const remainingMonths = 317.0;
              final r = (item.interestRate / 100.0) / 12.0;
              double newInstallment = item.monthlyInstallment;
              if (r > 0) {
                newInstallment = item.remainingBalance * (r * math.pow(1 + r, remainingMonths)) / (math.pow(1 + r, remainingMonths) - 1);
              } else {
                newInstallment = item.remainingBalance / remainingMonths;
              }
              final updated = item.copyWith(monthlyInstallment: newInstallment);
              widget.onSaveLiability(updated);
              Navigator.pop(context);
              showSnackbarNotification(context, 'Recast complete! New installment: ${_formatCurrency(newInstallment)}');
            },
            child: const Text('Recast Installment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeOwner = widget.selectedOwner ?? 'All Owners';
    final filteredLiabilities = widget.liabilities.where((item) {
      if (activeOwner.isNotEmpty && activeOwner != 'All Owners') {
        return item.owner.trim().toLowerCase() == activeOwner.trim().toLowerCase();
      }
      return true;
    }).toList();

    filteredLiabilities.sort((a, b) {
      if (_sortingMode == 'Avalanche') {
        return b.interestRate.compareTo(a.interestRate);
      } else {
        return a.remainingBalance.compareTo(b.remainingBalance);
      }
    });

    double totalDebt = 0.0;
    double totalMonthlyPayments = 0.0;
    double weightedRateSum = 0.0;
    DateTime latestPayoffDate = DateTime.now();

    for (var item in filteredLiabilities) {
      totalDebt += item.remainingBalance;
      totalMonthlyPayments += item.monthlyInstallment;
      weightedRateSum += item.interestRate * item.remainingBalance;

      final r = (item.interestRate / 100.0) / 12.0;
      double effectiveInstallment = item.monthlyInstallment + _extraPaymentSimulation;
      if (r > 0 && effectiveInstallment > item.remainingBalance * r) {
        final months = -math.log(1 - (r * item.remainingBalance) / effectiveInstallment) / math.log(1 + r);
        final payoff = DateTime.now().add(Duration(days: (months * 30).round()));
        if (payoff.isAfter(latestPayoffDate)) {
          latestPayoffDate = payoff;
        }
      }
    }

    double weightedAverageRate = totalDebt > 0 ? weightedRateSum / totalDebt : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 32;
        final double boxWidth = (fullWidth - 12) / 2;

        return ValueListenableBuilder<bool>(
          valueListenable: PrivacyService.instance.isPrivacyModeEnabled,
          builder: (context, isPrivate, child) {
            return Container(
              padding: EdgeInsets.all(_isCollapsed ? 12 : 16),
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
                      Expanded(
                        child: Row(
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
                              tooltip: _isCollapsed ? 'Expand' : 'Collapse',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!_isCollapsed) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: boxWidth,
                          child: SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95),
                                foregroundColor: _isZaznamityMode ? Colors.white : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showLiabilityTypeSelector(context),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Liability', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), 
                            ),
                          ),
                        ),
                        SizedBox(
                          width: boxWidth,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.sort, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _sortingMode,
                                      isDense: true,
                                      isExpanded: true,
                                      dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                      items: const [
                                        DropdownMenuItem(value: 'Avalanche', child: Text('Avalanche')),
                                        DropdownMenuItem(value: 'Snowball', child: Text('Snowball')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => _sortingMode = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Debt', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B))),
                                  Text(_formatCurrency(totalDebt), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Payment Total', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B))),
                                  Text(_formatCurrency(totalMonthlyPayments), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFF34D399) : const Color(0xFF059669))),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 16, color: Colors.white12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Weighted Avg Rate: ${weightedAverageRate.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569))),
                              Text('Debt-Free Approx.: ${filteredLiabilities.isEmpty ? 'N/A' : DateFormat('MMM yyyy').format(latestPayoffDate)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Simulator: +${_formatCurrency(_extraPaymentSimulation)}/extra', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                              Text('Saves Interest & Time', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                            ],
                          ),
                          Slider(
                            value: _extraPaymentSimulation,
                            min: 0,
                            max: 1000,
                            divisions: 20,
                            activeColor: _isZaznamityMode ? Color(0xFFA855F7) : Color(0xFF582F95),
                            inactiveColor: _isZaznamityMode ? Colors.white24 : Colors.grey.shade300,
                            onChanged: (val) => setState(() => _extraPaymentSimulation = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
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
                              
                              double original = item.originalAmount > 0 ? item.originalAmount : item.remainingBalance;
                              double progressRatio = original > 0 ? (1.0 - (item.remainingBalance / original)).clamp(0.0, 1.0) : 0.0;

                              final r = (item.interestRate / 100.0) / 12.0;
                              final effectiveInstallment = item.monthlyInstallment + _extraPaymentSimulation;
                              double interestPart = item.remainingBalance * r;
                              double principalPart = math.max(0.0, effectiveInstallment - interestPart);

                              int monthsLeft = 0;
                              DateTime payoffDate = DateTime.now();
                              if (r > 0 && effectiveInstallment > interestPart) {
                                final m = -math.log(1 - (r * item.remainingBalance) / effectiveInstallment) / math.log(1 + r);
                                monthsLeft = m.ceil();
                                payoffDate = DateTime.now().add(Duration(days: (monthsLeft * 30).round()));
                              }

                              final now = DateTime.now();
                              bool isOverdue = now.day > item.dueDay;

                              return InkWell(
                                onTap: () => _showLiabilityDialog(context, existingItem: item),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isOverdue ? Colors.red.shade400 : (_isZaznamityMode ? Colors.white12 : const Color(0xFFE2E8F0)),
                                      width: isOverdue ? 1.5 : 1.0,
                                    ),
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
                                                Text(
                                                  item.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (isOverdue) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(4)),
                                                    child: const Text('OVERDUE', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white)),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () => _showWindfallDialog(context, item),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.bolt, size: 12, color: _isZaznamityMode ? Color(0xFFA855F7) : Color(0xFF582F95)),
                                                      const SizedBox(width: 2),
                                                      Text('Windfall', style: TextStyle(fontSize: 9, color: _isZaznamityMode ? Color(0xFFA855F7) : Color(0xFF582F95), fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () => _showRecastDialog(context, item),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.refresh, size: 12, color: _isZaznamityMode ? Color(0xFFA855F7) : Color(0xFF582F95)),
                                                      const SizedBox(width: 2),
                                                      Text('Recast', style: TextStyle(fontSize: 9, color: _isZaznamityMode ? Color(0xFFA855F7) : Color(0xFF582F95), fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: progressRatio,
                                          minHeight: 8,
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
                                            'Bal: ${_formatCurrency(item.remainingBalance)} / Orig: ${_formatCurrency(original)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155),
                                            ),
                                          ),
                                          Text(
                                            'Rate: ${item.interestRate}% • Due: ${item.dueDay}',
                                            style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Rem: $monthsLeft periods (${DateFormat('MMM yyyy').format(payoffDate)})',
                                            style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B)),
                                          ),
                                          Text(
                                            'Split: Prin ${_formatCurrency(principalPart)} / Int ${_formatCurrency(interestPart)}',
                                            style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}