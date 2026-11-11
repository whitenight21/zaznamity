import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/label.dart';
import '../../models/report_options.dart';

Future<ReportOptions?> showReportConfigDialog(
  BuildContext context, {
  required List<LabelModel> labels,
  required List<String> owners,
  required List<String> pools,
  required bool isZaznamityMode,
  required String primaryCurrency,
}) {
  return showDialog<ReportOptions>(
    context: context,
    builder: (ctx) => ReportConfigDialog(
      labels: labels,
      owners: owners,
      pools: pools,
      isZaznamityMode: isZaznamityMode,
      primaryCurrency: primaryCurrency,
    ),
  );
}

class ReportConfigDialog extends StatefulWidget {
  final List<LabelModel> labels;
  final List<String> owners;
  final List<String> pools;
  final bool isZaznamityMode;
  final String primaryCurrency;

  const ReportConfigDialog({
    super.key,
    required this.labels,
    required this.owners,
    required this.pools,
    required this.isZaznamityMode,
    required this.primaryCurrency,
  });

  @override
  State<ReportConfigDialog> createState() => _ReportConfigDialogState();
}

class _ReportConfigDialogState extends State<ReportConfigDialog> {
  DateTime customStartDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime customEndDate = DateTime.now();

  String selectedOwnerFilter = 'All';
  String selectedPoolFilter = 'All';
  String selectedLabelFilter = 'All';
  String selectedCurrencyFilter = 'All';

  String selectedTemplatePreset = 'Custom';
  bool maskAmounts = false;
  bool includePreviousPeriodComparison = false;

  bool includeSummaryCard = true;
  bool includeSavingsGoalsCard = true;
  bool includeBudgetCard = true;
  bool includeLiabilitiesCard = true;
  bool includePoolBalancesCard = true;
  bool includeCategoryBreakdownTable = true;

  bool includeBarChart = true;
  bool includePieChart = true;
  bool includeBalanceTrendChart = true;
  bool includeCashFlowTrendChart = true;
  bool includeSankeyFlowChart = true;
  bool includeMoneyBreakdownChart = true;

  bool includeTransactionTableHistory = true;

  void _applyTemplate(String preset) {
    setState(() {
      selectedTemplatePreset = preset;
      if (preset == 'Monthly Statement') {
        includeSummaryCard = true;
        includeCategoryBreakdownTable = true;
        includeBarChart = true;
        includePieChart = true;
        includeBalanceTrendChart = true;
        includeCashFlowTrendChart = true;
        includeSavingsGoalsCard = false;
        includeLiabilitiesCard = false;
        includePoolBalancesCard = true;
        includeTransactionTableHistory = true;
      } else if (preset == 'Debt & Goals') {
        includeSavingsGoalsCard = true;
        includeLiabilitiesCard = true;
        includeSummaryCard = true;
        includeCategoryBreakdownTable = false;
        includeBarChart = false;
        includePieChart = false;
        includeBalanceTrendChart = false;
        includeCashFlowTrendChart = false;
        includeTransactionTableHistory = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Zaznamity Report Configuration',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: widget.isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
        ),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. TEMPLATE PRESETS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedTemplatePreset,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
                items: const [
                  DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                  DropdownMenuItem(value: 'Monthly Statement', child: Text('Monthly Statement')),
                  //DropdownMenuItem(value: 'Debt & Goals', child: Text('Debt & Goals')),
                ],
                onChanged: (val) {
                  if (val != null) _applyTemplate(val);
                },
              ),
              const SizedBox(height: 14),
              Text(
                '2. SELECT TIME & PRIVACY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: customStartDate,
                          firstDate: DateTime(2010),
                          lastDate: DateTime(2050),
                        );
                        if (picked != null) setState(() => customStartDate = picked);
                      },
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text('Start: ${DateFormat('dd/MM/yyyy').format(customStartDate)}', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: customEndDate,
                          firstDate: DateTime(2010),
                          lastDate: DateTime(2050),
                        );
                        if (picked != null) setState(() => customEndDate = picked);
                      },
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text('End: ${DateFormat('dd/MM/yyyy').format(customEndDate)}', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mask Confidential Amounts (••••••)', style: TextStyle(fontSize: 12)),
                value: maskAmounts,
                onChanged: (val) => setState(() => maskAmounts = val ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include Previous-Period Comparison', style: TextStyle(fontSize: 12)),
                value: includePreviousPeriodComparison,
                onChanged: (val) => setState(() => includePreviousPeriodComparison = val ?? false),
              ),
              const SizedBox(height: 10),
              Text(
                '3. DRILL-DOWN FILTERS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedOwnerFilter,
                      decoration: const InputDecoration(labelText: 'OWNER', isDense: true, border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Owners')),
                        ...widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o))),
                      ],
                      onChanged: (val) => setState(() => selectedOwnerFilter = val ?? 'All'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedPoolFilter,
                      decoration: const InputDecoration(labelText: 'POOL', isDense: true, border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Pools')),
                        ...widget.pools.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))),
                      ],
                      onChanged: (val) => setState(() => selectedPoolFilter = val ?? 'All'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedLabelFilter,
                      decoration: const InputDecoration(labelText: 'LABEL', isDense: true, border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Labels')),
                        ...widget.labels.map((l) => DropdownMenuItem(value: l.name, child: Text(l.name))),
                      ],
                      onChanged: (val) => setState(() => selectedLabelFilter = val ?? 'All'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedCurrencyFilter,
                      decoration: const InputDecoration(labelText: 'CURRENCY', isDense: true, border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Currencies')),
                        DropdownMenuItem(value: widget.primaryCurrency, child: Text(widget.primaryCurrency)),
                      ],
                      onChanged: (val) => setState(() => selectedCurrencyFilter = val ?? 'All'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '4. SELECT "METRICS" CARDS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
              ),
              CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Metrics Card', style: TextStyle(fontSize: 12)), value: includeSummaryCard, onChanged: (val) => setState(() => includeSummaryCard = val ?? true)),
              CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Pool Balances', style: TextStyle(fontSize: 12)), value: includePoolBalancesCard, onChanged: (val) => setState(() => includePoolBalancesCard = val ?? true)),
              //CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Labels Breakdown Table', style: TextStyle(fontSize: 12)), value: includeCategoryBreakdownTable, onChanged: (val) => setState(() => includeCategoryBreakdownTable = val ?? true)),
              CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Savings Goals Progress Bars', style: TextStyle(fontSize: 12)), value: includeSavingsGoalsCard, onChanged: (val) => setState(() => includeSavingsGoalsCard = val ?? true)),
              CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Active Budgets (Limit & Spent)', style: TextStyle(fontSize: 12)), value: includeBudgetCard, onChanged: (val) => setState(() => includeBudgetCard = val ?? true)),
              CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Liabilities Info', style: TextStyle(fontSize: 12)), value: includeLiabilitiesCard, onChanged: (val) => setState(() => includeLiabilitiesCard = val ?? true)),
              CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Zaznams History', style: TextStyle(fontSize: 12)), value: includeTransactionTableHistory, onChanged: (val) => setState(() => includeTransactionTableHistory = val ?? true)),

              const SizedBox(height: 10),
              Text(
                '5. SELECT "TRENDS" CARDS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
              ),
              //CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Labels Bar Chart', style: TextStyle(fontSize: 12)), value: includeBarChart, onChanged: (val) => setState(() => includeBarChart = val ?? true)),
              //CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Labels Pie Chart', style: TextStyle(fontSize: 12)), value: includePieChart, onChanged: (val) => setState(() => includePieChart = val ?? true)),
              CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Balance Trends Chart', style: TextStyle(fontSize: 12)), value: includeBalanceTrendChart, onChanged: (val) => setState(() => includeBalanceTrendChart = val ?? true)),
              CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('CashFlow Trends Chart', style: TextStyle(fontSize: 12)), value: includeCashFlowTrendChart, onChanged: (val) => setState(() => includeCashFlowTrendChart = val ?? true)),
              CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Sankey Flow Chart', style: TextStyle(fontSize: 12)), value: includeSankeyFlowChart, onChanged: (val) => setState(() => includeSankeyFlowChart = val ?? true)),
              //CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Money Breakdown Chart', style: TextStyle(fontSize: 12)), value: includeMoneyBreakdownChart, onChanged: (val) => setState(() => includeMoneyBreakdownChart = val ?? true)),


              const SizedBox(height: 10),
              Text(
                '6. SELECT "ANALYTICS" CARDS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
              ),
              CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Labels Bar Chart', style: TextStyle(fontSize: 12)), value: includeBarChart, onChanged: (val) => setState(() => includeBarChart = val ?? true)),
              //CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Labels Pie Chart', style: TextStyle(fontSize: 12)), value: includePieChart, onChanged: (val) => setState(() => includePieChart = val ?? true)),
              //CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Balance Trends Chart', style: TextStyle(fontSize: 12)), value: includeBalanceTrendChart, onChanged: (val) => setState(() => includeBalanceTrendChart = val ?? true)),
              //CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('CashFlow Trends Chart', style: TextStyle(fontSize: 12)), value: includeCashFlowTrendChart, onChanged: (val) => setState(() => includeCashFlowTrendChart = val ?? true)),
              //CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Sankey Flow Chart', style: TextStyle(fontSize: 12)), value: includeSankeyFlowChart, onChanged: (val) => setState(() => includeSankeyFlowChart = val ?? true)),
              CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Money Breakdown Chart', style: TextStyle(fontSize: 12)), value: includeMoneyBreakdownChart, onChanged: (val) => setState(() => includeMoneyBreakdownChart = val ?? true)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final options = ReportOptions(
              startDate: customStartDate,
              endDate: customEndDate,
              ownerFilter: selectedOwnerFilter,
              poolFilter: selectedPoolFilter,
              labelFilter: selectedLabelFilter,
              currencyFilter: selectedCurrencyFilter,
              maskAmounts: maskAmounts,
              templatePreset: selectedTemplatePreset,
              includePreviousPeriodComparison: includePreviousPeriodComparison,
              includeSummaryCard: includeSummaryCard,
              includeSavingsGoalsCard: includeSavingsGoalsCard,
              includeBudgetCard: includeBudgetCard,
              includeLiabilitiesCard: includeLiabilitiesCard,
              includePoolBalancesCard: includePoolBalancesCard,
              includeCategoryBreakdownTable: includeCategoryBreakdownTable,
              includeBarChart: includeBarChart,
              includePieChart: includePieChart,
              includeBalanceTrendChart: includeBalanceTrendChart,
              includeCashFlowTrendChart: includeCashFlowTrendChart,
              includeSankeyFlowChart: includeSankeyFlowChart,
              includeMoneyBreakdownChart: includeMoneyBreakdownChart,
              includeTransactionTableHistory: includeTransactionTableHistory,
            );
            Navigator.pop(context, options);
          },
          child: const Text('Confirm & Generate PDF'),
        ),
      ],
    );
  }
}