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
  void _showLiabilityInfoModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Liability Setup Guide'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'For the cleanest and most accurate tracking, we recommend:\n\n'
                  '• Enter your current actual remaining liability balance from your latest statement.\n'
                  '• Enter your current active monthly installment.\n'
                  '• Set your due day and current interest rate.\n\n'
                  'When you create a liability, a corresponding [name (L)] label is automatically created, and upcoming amortization installments are scheduled into your calendar and All Zaznams ledger[cite: 6]!',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
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
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Liabilities & Loans',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                      onPressed: () => _showLiabilityInfoModal(context),
                      tooltip: 'Setup Guide',
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_rounded, color: Color(0xFF582F95)),
                      onPressed: widget.onAddLiability,
                      tooltip: 'Add Liability',
                    ),
                    if (widget.onToggleWidth != null)
                      IconButton(
                        icon: Icon(widget.isWide ? Icons.fullscreen_exit : Icons.fullscreen),
                        onPressed: widget.onToggleWidth,
                      ),
                  ],
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            widget.liabilities.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No active liabilities tracked. Tap "+" to add one.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.liabilities.length,
                    itemBuilder: (context, index) {
                      final item = widget.liabilities[index];
                      
                      // 🚀 Calculate shrinking repayment progress ratio
                      // Assuming standard initial estimate or max balance tracking relative to installment progress
                      double estimatedInitial = item.remainingBalance + (item.monthlyInstallment * 12); 
                      if (estimatedInitial <= 0) estimatedInitial = item.remainingBalance > 0 ? item.remainingBalance * 1.5 : 1000.0;
                      double progressRatio = (1.0 - (item.remainingBalance / estimatedInitial)).clamp(0.0, 1.0);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                  onPressed: () => widget.onDeleteLiability(item.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // 🚀 Shrinking Progress Bar showing payment-by-payment payoff
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progressRatio,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF582F95)),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Balance: ${widget.currencySymbol}${item.remainingBalance.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                ),
                                Text(
                                  'Installment: ${widget.currencySymbol}${item.monthlyInstallment.toStringAsFixed(2)} (Due: ${item.dueDay})',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
      ),
    );
  }
}