import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/label.dart';
import '../models/report_options.dart';
import '../models/transaction_model.dart';
import 'database_helper.dart';
import 'report_charts.dart';

class ReportService {
  bool isExcludedTransferOrSavings(TransactionModel tx, List<LabelModel> labels) {
    if (tx.isSavings == 1) return true;
    
    final matchLbl = labels.where((l) => l.id == tx.labelId).firstOrNull;
    if (matchLbl != null) {
      final name = matchLbl.name.toLowerCase();
      if (name == 'transfer' ||
          name == 'goals' ||
          name == 'goalssavings' ||
          name == 'savings' ||
          name == 'goal' ||
          name.startsWith('withdrawal') ||
          name.startsWith('deposit') ||
          name.contains('transfer') ||
          name.contains('goal') ||
          name.contains('saving')) {
        return true;
      }
    }

    final desc = tx.description.toLowerCase();
    if (desc.startsWith('withdrawal') ||
        desc.startsWith('deposit') ||
        desc.contains('transfer') ||
        desc.contains('goal') ||
        desc.contains('savings')) {
      return true;
    }

    return false;
  }

  Future<ReportData> collect(
    ReportOptions options,
    List<LabelModel> labels, {
    String primaryCurrency = 'EUR',
  }) async {
    final allTxs = await DatabaseHelper.instance.getTransactions();

    final startOfDay = DateTime(
      options.startDate.year,
      options.startDate.month,
      options.startDate.day,
    );
    final endOfDay = DateTime(
      options.endDate.year,
      options.endDate.month,
      options.endDate.day,
      23,
      59,
      59,
    );

    // Calculate previous period for comparison
    final duration = endOfDay.difference(startOfDay);
    final prevStartOfDay = startOfDay.subtract(duration);
    final prevEndOfDay = startOfDay.subtract(const Duration(seconds: 1));

    final filteredTxs = allTxs.where((tx) {
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null) return false;
      if (txDate.isBefore(startOfDay) || txDate.isAfter(endOfDay)) return false;

      if (options.ownerFilter != 'All' && tx.owner != options.ownerFilter) {
        return false;
      }
      if (options.poolFilter != 'All' &&
          tx.pool.toLowerCase() != options.poolFilter.toLowerCase()) {
        return false;
      }
      if (options.currencyFilter != 'All' &&
          tx.currencyCode != options.currencyFilter) {
        return false;
      }

      if (options.labelFilter != 'All') {
        final labelObj = labels.where((l) => l.name == options.labelFilter).firstOrNull;
        if (labelObj == null || tx.labelId != labelObj.id) return false;
      }

      return true;
    }).toList();

    filteredTxs.sort((a, b) {
      final dA = DateTime.tryParse(a.createdAt) ?? DateTime(1970);
      final dB = DateTime.tryParse(b.createdAt) ?? DateTime(1970);
      return dA.compareTo(dB);
    });

    double totalIncome = 0;
    double totalExpense = 0;
    for (var tx in filteredTxs) {
      if (isExcludedTransferOrSavings(tx, labels)) continue;
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else if (tx.type == 'expense') {
        totalExpense += tx.amount;
      }
    }

    // Previous Period Collection
    double prevTotalIncome = 0;
    double prevTotalExpense = 0;
    if (options.includePreviousPeriodComparison) {
      final prevTxs = allTxs.where((tx) {
        final txDate = DateTime.tryParse(tx.createdAt);
        if (txDate == null) return false;
        return !txDate.isBefore(prevStartOfDay) && !txDate.isAfter(prevEndOfDay);
      });
      for (var tx in prevTxs) {
        if (isExcludedTransferOrSavings(tx, labels)) continue;
        if (tx.type == 'income') prevTotalIncome += tx.amount;
        if (tx.type == 'expense') prevTotalExpense += tx.amount;
      }
    }

    // Initial and End Balance Calculation (+ one balance value per day for the trend chart)
    double initialBalance = 0;
    double endBalance = 0;
    final DateTime startDayUtc =
        DateTime.utc(options.startDate.year, options.startDate.month, options.startDate.day);
    final int dayCount = math.max(
      1,
      DateTime.utc(options.endDate.year, options.endDate.month, options.endDate.day)
              .difference(startDayUtc)
              .inDays +
          1,
    );
    final List<double> dailyDelta = List<double>.filled(dayCount, 0.0);
    for (var tx in allTxs) {
      if (tx.isConfirmed != 1) continue;
      if (options.ownerFilter != 'All' && tx.owner != options.ownerFilter) continue;
      if (options.poolFilter != 'All' &&
          tx.pool.toLowerCase() != options.poolFilter.toLowerCase()) {
        continue;
      }
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null) continue;

      final amt = tx.type == 'income' ? tx.amount : -tx.amount;
      if (txDate.isBefore(startOfDay)) {
        initialBalance += amt;
      }
      if (!txDate.isAfter(endOfDay)) {
        endBalance += amt;
      }
      if (!txDate.isBefore(startOfDay) && !txDate.isAfter(endOfDay)) {
        final idx = DateTime.utc(txDate.year, txDate.month, txDate.day)
            .difference(startDayUtc)
            .inDays;
        if (idx >= 0 && idx < dayCount) dailyDelta[idx] += amt;
      }
    }

    final List<double> balanceSeries = [];
    double runningBalance = initialBalance;
    for (final d in dailyDelta) {
      runningBalance += d;
      balanceSeries.add(runningBalance);
    }

    // Category breakdown map for selected range
    final Map<String, double> categoryBreakdown = {};
    final Map<String, double> incomeBreakdown = {};
    final Map<int, String> labelMap = {for (var l in labels) l.id: l.name};
    for (var tx in filteredTxs) {
      if (isExcludedTransferOrSavings(tx, labels)) continue;
      if (tx.type == 'expense') {
        final catName = labelMap[tx.labelId] ?? 'General';
        categoryBreakdown.update(catName, (v) => v + tx.amount, ifAbsent: () => tx.amount);
      } else if (tx.type == 'income') {
        final incName = labelMap[tx.labelId] ?? 'Income';
        incomeBreakdown.update(incName, (v) => v + tx.amount, ifAbsent: () => tx.amount);
      }
    }

    // Cash flow buckets for the trend chart (weekly for short ranges, else monthly)
    final bool weeklyBuckets = dayCount <= 62;
    DateTime bucketStartFor(DateTime d) => weeklyBuckets
        ? DateTime(d.year, d.month, d.day - (d.weekday - 1))
        : DateTime(d.year, d.month, 1);
    DateTime nextBucket(DateTime d) =>
        weeklyBuckets ? DateTime(d.year, d.month, d.day + 7) : DateTime(d.year, d.month + 1, 1);

    final Map<int, List<double>> bucketTotals = {};
    for (var tx in filteredTxs) {
      if (isExcludedTransferOrSavings(tx, labels)) continue;
      if (tx.type != 'income' && tx.type != 'expense') continue;
      final d = DateTime.tryParse(tx.createdAt);
      if (d == null) continue;
      final totals = bucketTotals.putIfAbsent(
        bucketStartFor(d).millisecondsSinceEpoch,
        () => [0.0, 0.0],
      );
      if (tx.type == 'income') {
        totals[0] += tx.amount;
      } else {
        totals[1] += tx.amount;
      }
    }

    final List<CashflowBucket> cashflowBuckets = [];
    var bucketCursor = bucketStartFor(startOfDay);
    final lastBucketStart = bucketStartFor(endOfDay);
    while (!bucketCursor.isAfter(lastBucketStart) && cashflowBuckets.length < 400) {
      final totals = bucketTotals[bucketCursor.millisecondsSinceEpoch] ?? const [0.0, 0.0];
      final bool isFirst = cashflowBuckets.isEmpty;
      cashflowBuckets.add(
        CashflowBucket(
          label: weeklyBuckets
              ? DateFormat('dd/MM').format(bucketCursor)
              : DateFormat('MMM').format(bucketCursor),
          sublabel: (!weeklyBuckets && (isFirst || bucketCursor.month == 1))
              ? "'${(bucketCursor.year % 100).toString().padLeft(2, '0')}"
              : null,
          income: totals[0],
          expense: totals[1],
        ),
      );
      bucketCursor = nextBucket(bucketCursor);
    }
    if (cashflowBuckets.length > 36) {
      cashflowBuckets.removeRange(0, cashflowBuckets.length - 36);
    }

    // Calculate actual spending per budget label within the selected date range
    final rawBudgets = await DatabaseHelper.instance.getBudgets();
    final List enrichedBudgets = [];
    for (var b in rawBudgets) {
      final labelName = b['label_name'] ?? 'General';
      final limitAmt = ((b['limit_amount'] ?? b['limitAmount'] ?? 0) as num).toDouble();
      
      double spentAmt = 0;
      for (var tx in filteredTxs) {
        if (tx.type != 'expense') continue;
        final txLabelName = labelMap[tx.labelId] ?? 'General';
        if (txLabelName.toLowerCase() == labelName.toLowerCase()) {
          spentAmt += tx.amount;
        }
      }

      enrichedBudgets.add({
        'label_name': labelName,
        'limit_amount': limitAmt,
        'spent_amount': spentAmt,
      });
    }

    // Pool Balances map
    final Map<String, double> poolBalances = {};
    final nowForBalances = DateTime.now();
    for (var tx in allTxs) {
      if (tx.isConfirmed != 1) continue;
      final balDate = DateTime.tryParse(tx.createdAt);
      if (balDate != null && balDate.isAfter(nowForBalances)) continue;
      if (options.ownerFilter != 'All' && tx.owner != options.ownerFilter) continue;
      final p = tx.pool.toLowerCase();
      final amt = tx.type == 'income' ? tx.amount : -tx.amount;
      poolBalances.update(p, (v) => v + amt, ifAbsent: () => amt);
    }

    final rawGoals = await DatabaseHelper.instance.getSavingsGoals();
    final rawLiabilities = await DatabaseHelper.instance.getLiabilities();
    final currencySymbol = _getCurrencySymbol(
      options.currencyFilter == 'All' ? primaryCurrency : options.currencyFilter,
    );

    return ReportData(
      filteredTransactions: filteredTxs,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netBalance: totalIncome - totalExpense,
      prevTotalIncome: prevTotalIncome,
      prevTotalExpense: prevTotalExpense,
      initialBalance: initialBalance,
      endBalance: endBalance,
      currencySymbol: currencySymbol,
      savingsGoals: rawGoals.map((g) => g.toMap()).toList(),
      budgets: enrichedBudgets,
      liabilities: rawLiabilities.map((l) => l.toMap()).toList(),
      poolBalances: poolBalances,
      categoryBreakdown: categoryBreakdown,
      balanceSeries: balanceSeries,
      cashflowBuckets: cashflowBuckets,
      incomeBreakdown: incomeBreakdown,
    );
  }

  static num _n(Map m, List<String> keys, [num fallback = 0]) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v;
    }
    return fallback;
  }

  static String _s(Map m, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      final v = m[k];
      if (v != null) return v.toString();
    }
    return fallback;
  }

  static String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR': return 'EUR';
      case 'GBP': return '£';
      case 'CZK': return 'Kč';
      case 'HUF': return 'Ft';
      case 'PLN': return 'zł';
      case 'CHF': return 'CHF';
      case 'USD': return r'$';
      default: return code.toUpperCase();
    }
  }

  String _formatAmt(double amount, String symbol, bool mask) {
    if (mask) return '******';
    final formattedValue = amount.toStringAsFixed(2);
    if (symbol == 'EUR') {
      return '$formattedValue $symbol';
    } else {
      return '$symbol $formattedValue';
    }
  }

  Future<Uint8List> buildPdf(
    ReportData data,
    ReportOptions options,
    List<LabelModel> labels, {
    Uint8List? logoBytes,
  }) async {
    final ttfFont = pw.Font.helvetica();
    final ttfBoldFont = pw.Font.helveticaBold();
    final theme = pw.ThemeData.withFont(base: ttfFont, bold: ttfBoldFont);
    final pdfDoc = pw.Document(theme: theme);

    final logoImage = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
    final formattedDateRange = '${DateFormat('dd/MM/yyyy').format(options.startDate)} - ${DateFormat('dd/MM/yyyy').format(options.endDate)}';
    final startDateStr = DateFormat('dd/MM/yyyy').format(options.startDate);
    final endDateStr = DateFormat('dd/MM/yyyy').format(options.endDate);
    String moneyFmt(double v) => _formatAmt(v, data.currencySymbol, options.maskAmounts);

    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 16),
          child: pw.Text(
            'Zaznamity Financial Statement [${options.templatePreset}]',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount} — ZAZNAMITY — Record • Track • Focus',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ),
        build: (context) {
          final List<pw.Widget> children = [];

          // Header Banner
          children.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF582F95),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null) pw.Image(logoImage, width: 36, height: 36),
                      if (logoImage != null) pw.SizedBox(width: 12),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('ZAZNAMITY REPORT', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          pw.SizedBox(height: 3),
                          pw.Text('Timeframe: $formattedDateRange | Owner: ${options.ownerFilter}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                        ],
                      ),
                    ],
                  ),
                  pw.Text('Generated: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                ],
              ),
            ),
          );
          children.add(pw.SizedBox(height: 16));

          // Summary Metrics Card
          if (options.includeSummaryCard) {
            children.add(pw.Text('  Summary Metrics & Assets Overview', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            children.add(pw.SizedBox(height: 6));
            children.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Filters — Pool: ${options.poolFilter} | Currency: ${options.currencyFilter} | Label: ${options.labelFilter}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Initial Balance ($startDateStr): ${_formatAmt(data.initialBalance, data.currencySymbol, options.maskAmounts)}', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text('End Balance ($endDateStr): ${_formatAmt(data.endBalance, data.currencySymbol, options.maskAmounts)}', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Divider(color: PdfColors.grey300, height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Income: ${_formatAmt(data.totalIncome, data.currencySymbol, options.maskAmounts)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                        pw.Text('Expenses: ${_formatAmt(data.totalExpense, data.currencySymbol, options.maskAmounts)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                        pw.Text('Net Balance: ${_formatAmt(data.netBalance, data.currencySymbol, options.maskAmounts)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF582F95))),
                      ],
                    ),
                  ],
                ),
              ),
            );
            children.add(pw.SizedBox(height: 14));
          }

          // 1. Category Bar Chart
          if (options.includeBarChart && data.categoryBreakdown.isNotEmpty) {
            children.add(pw.Text('  Category Bar Chart ($formattedDateRange)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            children.add(pw.SizedBox(height: 6));
            
            final sortedCats = data.categoryBreakdown.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final maxVal = sortedCats.isNotEmpty ? sortedCats.first.value : 1.0;

            children.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(
                  children: sortedCats.take(5).map((entry) {
                    final ratio = maxVal > 0 ? entry.value / maxVal : 0.0;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(width: 80, child: pw.Text(entry.key, style: const pw.TextStyle(fontSize: 8))),
                          pw.Expanded(
                            child: pw.Stack(
                              children: [
                                pw.Container(height: 10, decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(3))),
                                pw.Container(
                                  height: 10,
                                  width: 250 * ratio,
                                  decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFA855F7), borderRadius: pw.BorderRadius.circular(3)),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(_formatAmt(entry.value, data.currencySymbol, options.maskAmounts), style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
            children.add(pw.SizedBox(height: 14));
          }

          // 2. Expense distribution (real donut chart)
          if (options.includePieChart && data.categoryBreakdown.isNotEmpty) {
            children.add(
              ReportCharts.section(
                'Expense Distribution',
                ReportCharts.donut(
                  values: data.categoryBreakdown,
                  fmt: moneyFmt,
                  mask: options.maskAmounts,
                  centerLabel: 'Expenses',
                  centerValue: data.totalExpense,
                ),
              ),
            );
          }

          // 3. Balance trend (real line chart, one point per day)
          if (options.includeBalanceTrendChart) {
            children.add(
              ReportCharts.section(
                'Balance Trend ($formattedDateRange)',
                ReportCharts.balanceTrend(
                  series: data.balanceSeries,
                  start: options.startDate,
                  opening: data.initialBalance,
                  closing: data.endBalance,
                  fmt: moneyFmt,
                  mask: options.maskAmounts,
                ),
              ),
            );
          }

          // 4. Cash flow trend (income up, expenses down, net line)
          if (options.includeCashFlowTrendChart) {
            children.add(
              ReportCharts.section(
                'Cash Flow Trend ($formattedDateRange)',
                ReportCharts.cashflowTrend(
                  buckets: data.cashflowBuckets,
                  fmt: moneyFmt,
                  mask: options.maskAmounts,
                ),
              ),
            );
          }

          // 5. Sankey flow (income sources -> total -> spending categories)
          if (options.includeSankeyFlowChart) {
            children.add(
              ReportCharts.section(
                'Money Flow ($formattedDateRange)',
                ReportCharts.sankey(
                  income: data.incomeBreakdown,
                  expenses: data.categoryBreakdown,
                  totalIncome: data.totalIncome,
                  totalExpense: data.totalExpense,
                  fmt: moneyFmt,
                  mask: options.maskAmounts,
                ),
              ),
            );
          }

          // 6. Money breakdown (expense categories + pool balances)
          if (options.includeMoneyBreakdownChart) {
            children.add(
              ReportCharts.section(
                'Money Breakdown',
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    ReportCharts.donut(
                      values: data.categoryBreakdown,
                      fmt: moneyFmt,
                      mask: options.maskAmounts,
                      centerLabel: 'Expenses',
                      centerValue: data.totalExpense,
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(color: PdfColors.grey300, height: 8),
                    pw.Text('Pool balances', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    ReportCharts.poolBars(balances: data.poolBalances, fmt: moneyFmt),
                  ],
                ),
              ),
            );
          }

          // Category Breakdown Table
          if (options.includeCategoryBreakdownTable && data.categoryBreakdown.isNotEmpty) {
            children.add(pw.Text('  Category Breakdown', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            children.add(pw.SizedBox(height: 6));
            
            final catRows = data.categoryBreakdown.entries.map((e) {
              final pct = data.totalExpense > 0 ? (e.value / data.totalExpense) * 100 : 0.0;
              return [
                pw.Text(e.key, style: const pw.TextStyle(fontSize: 8)),
                pw.Text(_formatAmt(e.value, data.currencySymbol, options.maskAmounts), style: const pw.TextStyle(fontSize: 8)),
                pw.Text('${pct.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 8)),
              ];
            }).toList();

            children.add(
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: ['Category', 'Amount', '% of Expenses']
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                            ))
                        .toList(),
                  ),
                  ...catRows.map((rowCells) => pw.TableRow(
                        children: rowCells.map((cellWidget) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: cellWidget,
                            )).toList(),
                      )),
                ],
              ),
            );
            children.add(pw.SizedBox(height: 14));
          }

          // Savings Goals
          if (options.includeSavingsGoalsCard && data.savingsGoals.isNotEmpty) {
            children.add(pw.Text('  Savings Goals & Progress', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            children.add(pw.SizedBox(height: 6));
            children.add(
              pw.Column(
                children: data.savingsGoals.map((g) {
                  final target = _n(g, ['target_amount', 'targetAmount']).toDouble();
                  final current = _n(g, ['current_amount', 'currentAmount']).toDouble();
                  final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(_s(g, ['name']), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Text('${_formatAmt(current, data.currencySymbol, options.maskAmounts)} / ${_formatAmt(target, data.currencySymbol, options.maskAmounts)}', style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Stack(
                          children: [
                            pw.Container(height: 8, decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(4))),
                            pw.Container(
                              height: 8,
                              width: 450 * progress,
                              decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF582F95), borderRadius: pw.BorderRadius.circular(4)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
            children.add(pw.SizedBox(height: 14));
          }

          // Active Budgets
          if (options.includeBudgetCard && data.budgets.isNotEmpty) {
            children.add(pw.Text('  Active Budgets & Usage', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            children.add(pw.SizedBox(height: 6));

            final budgetRows = data.budgets.map((b) {
              final limitAmt = b['limit_amount'] as double;
              final spentAmt = b['spent_amount'] as double;
              return [
                pw.Text(b['label_name'] ?? 'General', style: const pw.TextStyle(fontSize: 8)),
                pw.Text(_formatAmt(limitAmt, data.currencySymbol, options.maskAmounts), style: const pw.TextStyle(fontSize: 8)),
                pw.Text(_formatAmt(spentAmt, data.currencySymbol, options.maskAmounts), style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ];
            }).toList();

            children.add(
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: ['Label Name', 'Limit Amount', 'Actual Spent']
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                            ))
                        .toList(),
                  ),
                  ...budgetRows.map((rowCells) => pw.TableRow(
                        children: rowCells.map((cellWidget) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: cellWidget,
                            )).toList(),
                      )),
                ],
              ),
            );
            children.add(pw.SizedBox(height: 14));
          }

          // Liabilities Schedule
          if (options.includeLiabilitiesCard && data.liabilities.isNotEmpty) {
            children.add(pw.Text('  Liabilities & Loans Schedule', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            children.add(pw.SizedBox(height: 6));

            final liabilityRows = data.liabilities.map((l) => [
              pw.Text(_s(l, ['name']), style: const pw.TextStyle(fontSize: 8)),
              pw.Text(_formatAmt(_n(l, ['remaining_balance', 'remainingBalance']).toDouble(), data.currencySymbol, options.maskAmounts), style: const pw.TextStyle(fontSize: 8)),
              pw.Text(_formatAmt(_n(l, ['monthly_installment', 'monthlyInstallment']).toDouble(), data.currencySymbol, options.maskAmounts), style: const pw.TextStyle(fontSize: 8)),
              pw.Text('${_n(l, ['interest_rate', 'interestRate'])}%', style: const pw.TextStyle(fontSize: 8)),
            ]).toList();

            children.add(
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: ['Liability Name', 'Balance', 'Installment', 'APR %']
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                            ))
                        .toList(),
                  ),
                  ...liabilityRows.map((rowCells) => pw.TableRow(
                        children: rowCells.map((cellWidget) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: cellWidget,
                            )).toList(),
                      )),
                ],
              ),
            );
            children.add(pw.SizedBox(height: 14));
          }

          // Pool Balances
          if (options.includePoolBalancesCard && data.poolBalances.isNotEmpty) {
            children.add(pw.Text('  Pool Balances', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            children.add(pw.SizedBox(height: 6));

            final poolRows = data.poolBalances.entries.map((e) => [
              pw.Text(e.key.toUpperCase(), style: const pw.TextStyle(fontSize: 8)),
              pw.Text(_formatAmt(e.value, data.currencySymbol, options.maskAmounts), style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ]).toList();

            children.add(
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: ['Pool Name', 'Net Balance']
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                            ))
                        .toList(),
                  ),
                  ...poolRows.map((rowCells) => pw.TableRow(
                        children: rowCells.map((cellWidget) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: cellWidget,
                            )).toList(),
                      )),
                ],
              ),
            );
            children.add(pw.SizedBox(height: 14));
          }

          // Transactions Table History
          if (options.includeTransactionTableHistory) {
            children.add(pw.Text('  All Zaznams (${data.filteredTransactions.length})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            children.add(pw.SizedBox(height: 6));
            if (data.filteredTransactions.isEmpty) {
              children.add(pw.Text('No Zaznams found for the selected timeframe and filters.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)));
            } else {
              final tableRows = data.filteredTransactions.map((tx) {
                final dateStr = tx.createdAt.contains('T') ? tx.createdAt.split('T')[0] : tx.createdAt;
                final sign = tx.type == 'expense' ? '-' : '+';
                final amtStr = '$sign${_formatAmt(tx.amount, data.currencySymbol, options.maskAmounts)}';
                final isIncome = tx.type == 'income';

                return [
                  pw.Text(dateStr, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(tx.description, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(tx.owner, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(tx.pool, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    amtStr,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: isIncome ? PdfColors.green800 : PdfColors.red800,
                    ),
                  ),
                ];
              }).toList();

              children.add(
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1.2),
                    1: pw.FlexColumnWidth(2.5),
                    2: pw.FlexColumnWidth(1),
                    3: pw.FlexColumnWidth(1),
                    4: pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: ['Date', 'Description', 'Owner', 'Pool', 'Amount']
                          .map((h) => pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                              ))
                          .toList(),
                    ),
                    ...tableRows.map((rowCells) => pw.TableRow(
                          children: rowCells.map((cellWidget) => pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: cellWidget,
                              )).toList(),
                        )),
                  ],
                ),
              );
            }
          }

          return children;
        },
      ),
    );

    return pdfDoc.save();
  }

  static Future<Uint8List> generateInIsolate(Map<String, dynamic> params) async {
    final ReportOptions options = params['options'] as ReportOptions;
    final ReportData data = params['data'] as ReportData;
    final List<LabelModel> labels = (params['labels'] as List).cast<LabelModel>();
    final Uint8List? logoBytes = params['logoBytes'] as Uint8List?;

    final service = ReportService();
    return await service.buildPdf(
      data,
      options,
      labels,
      logoBytes: logoBytes,
    );
  }

  static Uint8List _bytes(ByteData d) =>
      d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);

  Future<File?> generateAndSave(
    ReportOptions options,
    List<LabelModel> labels, {
    String primaryCurrency = 'EUR',
  }) async {
    try {
      final data = await collect(options, labels, primaryCurrency: primaryCurrency);
      
      Uint8List? logoBytes;
      try {
        logoBytes = _bytes(await rootBundle.load('assets/ZaznamityLogo_onlyZwhite.png'));
      } catch (_) {}

      final Uint8List pdfBytes = await compute(generateInIsolate, {
        'options': options,
        'data': data,
        'labels': labels,
        'logoBytes': logoBytes,
      });

      final dateStamp = '${options.startDate.month.toString().padLeft(2, '0')}-${options.startDate.day.toString().padLeft(2, '0')}-${options.startDate.year}_to_${options.endDate.month.toString().padLeft(2, '0')}-${options.endDate.day.toString().padLeft(2, '0')}-${options.endDate.year}';
      final fileName = 'Z_Report_$dateStamp.pdf';

      File? savedFile;

      // 1. Desktop handling: Use native save dialog
      if (!Platform.isAndroid && !Platform.isIOS) {
        try {
          final FileSaveLocation? result = await getSaveLocation(
            suggestedName: fileName,
            acceptedTypeGroups: const [
              XTypeGroup(label: 'PDF Documents', extensions: ['pdf']),
            ],
          );

          if (result != null) {
            savedFile = File(result.path);
            await savedFile.writeAsBytes(pdfBytes);
          }
        } catch (_) {}
      }

      // 2. Mobile handling (Android & iOS): Use native directory picker (No permissions required)
      if (savedFile == null && (Platform.isAndroid || Platform.isIOS)) {
        final String? directoryPath = await getDirectoryPath();

        if (directoryPath != null) {
          final String separator = Platform.pathSeparator;
          savedFile = File('$directoryPath$separator$fileName');
          await savedFile.writeAsBytes(pdfBytes);
        }
      }

      return savedFile; // Returns null if user cancelled the folder picker dialog
    } catch (e) {
      debugPrint('Error in generateAndSave: $e');
      rethrow;
    }
  }

  Future<void> openOrShareFile(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'Zaznamity Financial Report');
  }

}

//      final dateStamp = '${options.startDate.month.toString().padLeft(2, '0')}/${options.startDate.day.toString().padLeft(2, '0')}/${options.startDate.year}-${options.endDate.month.toString().padLeft(2, '0')}/${options.endDate.day.toString().padLeft(2, '0')}/${options.endDate.year}';
//      final fileName = 'Z_Report_$dateStamp.pdf';