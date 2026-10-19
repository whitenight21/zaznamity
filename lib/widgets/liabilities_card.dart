// ignore_for_file: unnecessary_this, deprecated_member_use

import 'package:flutter/material.dart';

class LiabilityItem {
  final String id;
  final String name;
  final double remainingBalance;
  final double monthlyInstallment;
  final double interestRate;
  final int dueDay;
  final String owner;

  LiabilityItem({
    required this.id,
    required this.name,
    required this.remainingBalance,
    required this.monthlyInstallment,
    required this.interestRate,
    required this.dueDay,
    required this.owner,
  });
}

class LiabilitiesCard extends StatefulWidget {
  final List<LiabilityItem> liabilities;
  final List<String> owners;
  final String? selectedOwner;
  final String currencySymbol;
  final Function(LiabilityItem) onSaveLiability;
  final VoidCallback? onAddLiability;
  final Function(String) onDeleteLiability;
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
  final bool _isZaznamityMode = true;
  late String _selectedOwner;

  @override
  void initState() {
    super.initState();
    _selectedOwner = widget.selectedOwner ?? 'All Owners';
  }

  @override
  void didUpdateWidget(covariant LiabilitiesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOwner != oldWidget.selectedOwner) {
      setState(() {
        _selectedOwner = widget.selectedOwner ?? 'All Owners';
      });
    }
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
                  '• Set your due day and current interest rate.\n\n'
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
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
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
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF3B1E63),
                      Color(0xFF160D25),
                      Color(0xFF000000),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
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
                      Text(
                        'LIABILITIES',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.info_outline, size: 16, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
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
                                  const DropdownMenuItem(value: 'All Owners', child: Text('All Owners')),
                                  ...widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o))),
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
                        onPressed: widget.onAddLiability,
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
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredLiabilities.length,
                      itemBuilder: (context, index) {
                        final item = filteredLiabilities[index];
                        
                        double estimatedInitial = item.remainingBalance + (item.monthlyInstallment * 12); 
                        if (estimatedInitial <= 0) estimatedInitial = item.remainingBalance > 0 ? item.remainingBalance * 1.5 : 1000.0;
                        double progressRatio = (1.0 - (item.remainingBalance / estimatedInitial)).clamp(0.0, 1.0);

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
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
                                      fontSize: 13,
                                      color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: _isZaznamityMode ? const Color(0xFFEF4444) : Colors.redAccent,
                                      size: 18,
                                    ),
                                    onPressed: () => widget.onDeleteLiability(item.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progressRatio,
                                  backgroundColor: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Balance: ${widget.currencySymbol}${item.remainingBalance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11,
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