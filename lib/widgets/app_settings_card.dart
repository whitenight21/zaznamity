// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:zaznamity/models/card_config.dart';
import 'package:zaznamity/models/label.dart';
import 'package:zaznamity/services/notification_service.dart';
import 'package:zaznamity/widgets/settings/owner_management_modal.dart';
import 'package:zaznamity/widgets/settings/pool_management_modal.dart';
import 'package:zaznamity/widgets/csv_import_mapper_dialog.dart';

class AppSettingsCard extends StatefulWidget {
  final Map<String, bool> initialPools;
  final Map<String, bool> initialLiquidNetPools;
  final Map<String, bool> initialPrognosisPools;
  final List<String> initialOwners;
  final List<String> initialLeftNavItems;
  final List<String> initialRightNavItems;
  final List<LabelModel> labels;
  final List<CardConfig> cards;
  final Function(bool)? onThemeChanged;
  final Function(bool, String)? onPinSettingsChanged;
  final Function(Map<String, bool>) onSavePools;
  final Function(Map<String, bool>) onSaveLiquidNetPools;
  final Function(Map<String, bool>) onSavePrognosisPools;
  final Function(List<String>) onSaveOwners;
  final Function(List<String>, List<String>) onSaveNavItems;
  final Function(List<CardConfig>) onSaveCardOrder;
  final Function(String) onAddLabel;
  final Function(int, String) onUpdateLabel;
  final Function(int) onDeleteLabel;
  final VoidCallback? onImportCsv;
  final Function(String, {int? year, int? month}) onDeleteBulkTransactions;
  final Function(String, String) onBulkUpdateTransactionsLabel; 
  final bool isWide;
  final VoidCallback? onToggleWidth;
  final VoidCallback? onHide;

  const AppSettingsCard({
    super.key,
    required this.initialPools,
    required this.initialLiquidNetPools,
    required this.initialPrognosisPools,
    required this.initialOwners,
    required this.initialLeftNavItems,
    required this.initialRightNavItems,
    required this.labels,
    required this.cards,
    this.onThemeChanged,
    this.onPinSettingsChanged,
    required this.onSavePools,
    required this.onSaveLiquidNetPools,
    required this.onSavePrognosisPools,
    required this.onSaveOwners,
    required this.onSaveNavItems,
    required this.onSaveCardOrder,
    required this.onAddLabel,
    required this.onUpdateLabel,
    required this.onDeleteLabel,
    this.onImportCsv,
    required this.onDeleteBulkTransactions,
    required this.onBulkUpdateTransactionsLabel,
    required this.isWide,
    this.onToggleWidth,
    this.onHide,
  });

  @override
  State<AppSettingsCard> createState() => _AppSettingsCardState();
}

class _AppSettingsCardState extends State<AppSettingsCard> {
  late Map<String, bool> _pools;
  late Map<String, bool> _liquidNetPools;
  late Map<String, bool> _prognosisPools;
  late List<String> _owners;
  late List<String> _leftNavItems;
  late List<String> _rightNavItems;
  
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  final int _notifyDaysBefore = 1;
  final int _notifyHoursBefore = 9;
  
  bool _biometricsEnabled = false;
  String _biometricType = 'PIN';
  String _savedPin = "1234";
  
  final TextEditingController _newLabelController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pools = Map.from(widget.initialPools);
    _liquidNetPools = Map.from(widget.initialLiquidNetPools);
    _prognosisPools = Map.from(widget.initialPrognosisPools);
    _owners = List.from(widget.initialOwners);
    
    _leftNavItems = [
      'owner',
      widget.initialLeftNavItems.length > 1 ? widget.initialLeftNavItems[1] : 'metrics',
      widget.initialLeftNavItems.length > 2 ? widget.initialLeftNavItems[2] : 'budget',
    ];
    _rightNavItems = [
      widget.initialRightNavItems.isNotEmpty ? widget.initialRightNavItems[0] : 'history',
      widget.initialRightNavItems.length > 1 ? widget.initialRightNavItems[1] : 'calendar',
      'snapshot',
    ];
    
    _loadPrefs();
  }

  @override
  void didUpdateWidget(covariant AppSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialOwners != oldWidget.initialOwners) {
      _owners = List.from(widget.initialOwners);
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _biometricsEnabled = prefs.getBool('biometricsEnabled') ?? false;
      _savedPin = prefs.getString('savedPin') ?? "1234";
      _pinController.text = _savedPin;

      final leftSaved = prefs.getStringList('leftNavItems');
      if (leftSaved != null && leftSaved.length >= 3) {
        _leftNavItems = ['owner', leftSaved[1], leftSaved[2]];
      }
      final rightSaved = prefs.getStringList('rightNavItems');
      if (rightSaved != null && rightSaved.length >= 3) {
        _rightNavItems = [rightSaved[0], rightSaved[1], 'snapshot'];
      }
    });
  }

  Future<void> _saveNavPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _leftNavItems[0] = 'owner';
    _rightNavItems[2] = 'snapshot';

    await prefs.setStringList('leftNavItems', _leftNavItems);
    await prefs.setStringList('rightNavItems', _rightNavItems);
    widget.onSaveNavItems(_leftNavItems, _rightNavItems);
  }

  List<DropdownMenuItem<String>> _buildNavDropdownItems() {
    final Map<String, String> uniqueItems = {};
    for (var card in widget.cards) {
      uniqueItems[card.id] = card.title;
    }
    return uniqueItems.entries.map((entry) {
      return DropdownMenuItem(
        value: entry.key,
        child: Text(entry.value, style: const TextStyle(fontSize: 13)),
      );
    }).toList();
  }

  void _editLabelDialog(LabelModel label) {
    final controller = TextEditingController(text: label.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Label Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                widget.onUpdateLabel(label.id, controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showReportConfigModal() {
    String selectedTimeframe = 'this_month';
    DateTime? customStartDate;
    DateTime? customEndDate;
    bool includeSummaryCards = true;
    bool includeCategoryChart = true;
    bool includeOwnerBreakdown = false;
    bool includeTransactionTable = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Text('Configure Zaznamity Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Timeframe', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedTimeframe,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                  items: const [
                    DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                    DropdownMenuItem(value: 'last_month', child: Text('Last Month')),
                    DropdownMenuItem(value: 'ytd', child: Text('Year-to-Date (YTD)')),
                    DropdownMenuItem(value: 'all_time', child: Text('All-Time Records')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom Date Range...')),
                  ],
                  onChanged: (val) => setStateModal(() => selectedTimeframe = val ?? 'this_month'),
                ),
                if (selectedTimeframe == 'custom') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: customStartDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setStateModal(() => customStartDate = picked);
                          },
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: Text(customStartDate == null ? 'Start Date' : '${customStartDate!.month}/${customStartDate!.day}/${customStartDate!.year}', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: customEndDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setStateModal(() => customEndDate = picked);
                          },
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: Text(customEndDate == null ? 'End Date' : '${customEndDate!.month}/${customEndDate!.day}/${customEndDate!.year}', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Report Sections & Charts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Summary Metrics and Assets', style: TextStyle(fontSize: 13)),
                  value: includeSummaryCards,
                  onChanged: (val) => setStateModal(() => includeSummaryCards = val ?? true),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Label Analytics and Charts', style: TextStyle(fontSize: 13)),
                  value: includeCategoryChart,
                  onChanged: (val) => setStateModal(() => includeCategoryChart = val ?? true),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Owner Breakdown', style: TextStyle(fontSize: 13)),
                  value: includeOwnerBreakdown,
                  onChanged: (val) => setStateModal(() => includeOwnerBreakdown = val ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Detailed Zaznams Table', style: TextStyle(fontSize: 13)),
                  value: includeTransactionTable,
                  onChanged: (val) => setStateModal(() => includeTransactionTable = val ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 88, 47, 149), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                
                try {
                  final pdfDoc = pw.Document();
                  final logoImage = pw.MemoryImage(
                    (await rootBundle.load('assets/ZaznamityLogo_onlyZwhite.png'))
                        .buffer
                        .asUint8List(),
                  );
                  
                  pdfDoc.addPage(
                    pw.MultiPage(
                      pageFormat: PdfPageFormat.a4,
                      margin: const pw.EdgeInsets.all(32),
                      header: (pw.Context context) {
                        return pw.Container(
                          alignment: pw.Alignment.centerRight,
                          margin: const pw.EdgeInsets.only(bottom: 16),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'Net Worth Statement',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColors.grey600,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      footer: (pw.Context context) {
                        return pw.Container(
                          alignment: pw.Alignment.center,
                          margin: const pw.EdgeInsets.only(top: 16),
                          child: pw.Text(
                            'Page ${context.pageNumber} of ${context.pagesCount} — Secure Financial Ledger',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                          ),
                        );
                      },
                      build: (pw.Context context) {
                        return [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(16),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFF582F95),
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Row(
                                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                                  children: [
                                    pw.Image(
                                      logoImage,
                                      width: 60,
                                      height: 60,
                                      fit: pw.BoxFit.cover,
                                    ),
                                    pw.SizedBox(width: 12),
                                    pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(
                                          ' ZAZNAMITY FINANCIAL REPORT',
                                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                                        ),
                                        pw.SizedBox(height: 4),
                                        pw.Text(
                                          'As of Date: ${selectedTimeframe.toUpperCase().replaceAll('_', ' ')}',
                                          style: pw.TextStyle(fontSize: 12, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                pw.Text(
                                  'Created: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 20),

                          if (includeSummaryCards) ...[
                            pw.Text('1. Summary Metrics and Assets', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                            pw.SizedBox(height: 8),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(12),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey300),
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Text(
                                'This summary report compiles all tracked transactions securely stored on your local device database. No third-party servers or cloud connections were utilized.',
                                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800, lineSpacing: 4),
                              ),
                            ),
                            pw.SizedBox(height: 16),
                          ],

                          if (includeCategoryChart) ...[
                            pw.Text('2. Label Analytics and Charts', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                            pw.SizedBox(height: 8),
                            pw.Container(
                              height: 60,
                              alignment: pw.Alignment.center,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey100,
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Text('[Label Analytics and Charts Module]', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            ),
                            pw.SizedBox(height: 16),
                          ],

                          if (includeOwnerBreakdown) ...[
                            pw.Text('3. Owner Breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                            pw.SizedBox(height: 8),
                            pw.Container(
                              height: 60,
                              alignment: pw.Alignment.center,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey100,
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Text('[Owner Breakdown Module]', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            ),
                            pw.SizedBox(height: 16),
                          ],

                          if (includeTransactionTable) ...[
                            pw.Text('4. Detailed Zaznams Table', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                            pw.SizedBox(height: 8),
                            pw.Table(
                              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                              children: [
                                pw.TableRow(
                                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                                  children: [
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Pool', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                                  ],
                                ),
                                pw.TableRow(
                                  children: [
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('2026-10-01', style: const pw.TextStyle(fontSize: 9))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Sample Zaznam Record', style: const pw.TextStyle(fontSize: 9))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Checking', style: const pw.TextStyle(fontSize: 9))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('\$120.00', style: const pw.TextStyle(fontSize: 9))),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ];
                      },
                    ),
                  );

                  final now = DateTime.now();
                  String timeCode = selectedTimeframe;
                  if (selectedTimeframe == 'this_month') {
                    timeCode = '${now.month.toString().padLeft(2, '0')}.${now.year}';
                  } else if (selectedTimeframe == 'last_month') {
                    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
                    timeCode = '${lastMonthDate.month.toString().padLeft(2, '0')}.${lastMonthDate.year}';
                  } else if (selectedTimeframe == 'ytd') {
                    timeCode = '${now.year}';
                  }

                  final fileName = 'ZaznamityReport_$timeCode.pdf';

                  Directory? directory;
                  if (Platform.isAndroid) {
                    directory = Directory('/storage/emulated/0/Download');
                    if (!await directory.exists()) {
                      directory = await getExternalStorageDirectory();
                    }
                  } else {
                    directory = await getApplicationDocumentsDirectory();
                  }

                  final savedFile = File('${directory!.path}/$fileName');
                  await savedFile.writeAsBytes(await pdfDoc.save());

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved automatically to Downloads: $fileName')),
                  );

                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving PDF report: $e')),
                  );
                }
              },
              child: const Text('Save PDF Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkDeleteDialog() {
    int selectedYear = DateTime.now().year;
    int selectedMonth = DateTime.now().month;
    String mode = 'month';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Text('Bulk Delete Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select scope for deletion:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text('By Specific Month', style: TextStyle(fontSize: 13)),
                value: 'month',
                groupValue: mode,
                onChanged: (val) => setStateModal(() => mode = val!),
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text('By Specific Year', style: TextStyle(fontSize: 13)),
                value: 'year',
                groupValue: mode,
                onChanged: (val) => setStateModal(() => mode = val!),
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text('All Transactions (Wipe All)', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                value: 'all',
                groupValue: mode,
                onChanged: (val) => setStateModal(() => mode = val!),
              ),
              if (mode == 'month' || mode == 'year') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedYear,
                        decoration: const InputDecoration(labelText: 'Year', isDense: true),
                        items: List.generate(11, (i) => 2020 + i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                        onChanged: (val) => setStateModal(() => selectedYear = val ?? selectedYear),
                      ),
                    ),
                    if (mode == 'month') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: selectedMonth,
                          decoration: const InputDecoration(labelText: 'Month', isDense: true),
                          items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text('$m'))).toList(),
                          onChanged: (val) => setStateModal(() => selectedMonth = val ?? selectedMonth),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                if (mode == 'month') {
                  widget.onDeleteBulkTransactions('month', year: selectedYear, month: selectedMonth);
                } else if (mode == 'year') {
                  widget.onDeleteBulkTransactions('year', year: selectedYear);
                } else {
                  widget.onDeleteBulkTransactions('all');
                }
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkEditLabelDialog() {
    String? oldLabelName = widget.labels.isNotEmpty ? widget.labels.first.name : null;
    final newLabelController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Text('Bulk Edit Transactions by Label', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Change all Zaznams labeled:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              const Text('currently:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: oldLabelName,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                items: widget.labels.map((l) => DropdownMenuItem(value: l.name, child: Text(l.name))).toList(),
                onChanged: (val) => setStateModal(() => oldLabelName = val),
              ),
              const SizedBox(height: 16),
              const Text('to new label:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              TextField(
                controller: newLabelController,
                decoration: const InputDecoration(
                  hintText: 'Enter new label name...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 88, 47, 149), foregroundColor: Colors.white),
              onPressed: () {
                final newLabel = newLabelController.text.trim();
                if (oldLabelName != null && newLabel.isNotEmpty) {
                  Navigator.pop(ctx);
                  widget.onBulkUpdateTransactionsLabel(oldLabelName!, newLabel);
                }
              },
              child: const Text('Apply Changes'),
            ),
          ],
        ),
      ),
    );
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
                        'ZAZNAMITY SETTINGS',
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
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 8),

              // ==========================================
              // GROUP 1: APPEARANCE & NAVIGATION
              // ==========================================
              _buildMainCategoryGroup(
                title: 'Appearance & Navigation',
                subtitle: 'Theme preferences and navigation layout configuration',
                children: [
                  _buildSubSectionCard(
                    title: 'Dark Mode',
                    subtitle: 'Toggle light or dark theme',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Dark Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        value: _isDarkMode,
                        onChanged: (val) async {
                          setState(() => _isDarkMode = val);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('isDarkMode', val);
                          if (widget.onThemeChanged != null) {
                            widget.onThemeChanged!(val);
                          }
                        },
                      ),
                    ],
                  ),
                  _buildSubSectionCard(
                    title: 'Navigation Bar Customization',
                    subtitle: 'Configure shortcuts: 2 left and 2 right',
                    children: [
                      const Text('Left Slot 1 (Fixed)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.person_outline, size: 18, color: Color(0xFF475569)),
                            SizedBox(width: 8),
                            Text('Master Owner Selector (Fixed)', style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Left Slot 2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _leftNavItems.length > 1 && _buildNavDropdownItems().any((item) => item.value == _leftNavItems[1]) ? _leftNavItems[1] : 'metrics',
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                        items: _buildNavDropdownItems(),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              _leftNavItems[1] = val;
                            });
                            await _saveNavPrefs();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Left Slot 3', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _leftNavItems.length > 2 && _buildNavDropdownItems().any((item) => item.value == _leftNavItems[2]) ? _leftNavItems[2] : 'budget',
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                        items: _buildNavDropdownItems(),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              _leftNavItems[2] = val;
                            });
                            await _saveNavPrefs();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Center Slot (Fixed)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            ClipOval(
                              child: Image.asset(
                                'assets/ZaznamityLogoFULL.jpg',
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('New Zaznam (Fixed)', style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Right Slot 1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _rightNavItems.isNotEmpty && _buildNavDropdownItems().any((item) => item.value == _rightNavItems[0]) ? _rightNavItems[0] : 'history',
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                        items: _buildNavDropdownItems(),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              _rightNavItems[0] = val;
                            });
                            await _saveNavPrefs();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Right Slot 2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _rightNavItems.length > 1 && _buildNavDropdownItems().any((item) => item.value == _rightNavItems[1]) ? _rightNavItems[1] : 'calendar',
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                        items: _buildNavDropdownItems(),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              _rightNavItems[1] = val;
                            });
                            await _saveNavPrefs();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Right Slot 3 (Fixed)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.grid_view_rounded, size: 18, color: Color(0xFF475569)),
                            SizedBox(width: 8),
                            Text('Zoom-Out Snapshot View (Fixed)', style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // ==========================================
              // GROUP 2: ORGANIZATION & STRUCTURE
              // ==========================================
              _buildMainCategoryGroup(
                title: 'Organization & Structure',
                subtitle: 'Labels, owners, pools, and metric configurations',
                children: [
                  _buildSubSectionCard(
                    title: 'Labels Management',
                    subtitle: 'Manage Zaznamity labels',
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newLabelController,
                              decoration: const InputDecoration(
                                hintText: 'New label name...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 88, 47, 149)),
                            onPressed: () {
                              if (_newLabelController.text.trim().isNotEmpty) {
                                widget.onAddLabel(_newLabelController.text.trim());
                                _newLabelController.clear();
                              }
                            },
                            child: const Text('Add', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: widget.labels.length,
                          itemBuilder: (context, index) {
                            final label = widget.labels[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(label.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 16, color: Color(0xFF64748B)),
                                    onPressed: () => _editLabelDialog(label),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 16, color: Color(0xFFDC2626)),
                                    onPressed: () => widget.onDeleteLabel(label.id),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  _buildSubSectionCard(
                    title: 'Bulk Edit Zaznam Labels',
                    subtitle: 'Change all Zaznams labeled "x" to "y"',
                    children: [
                      const Text(
                        'Reassign all existing Zaznams from one label to another in batch',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 88, 47, 149),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _showBulkEditLabelDialog,
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: const Text('Bulk Edit Labels', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  _buildSubSectionCard(
                    title: 'Owner Management',
                    subtitle: 'Manage custom Zaznamity owners',
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Open Owner Management', style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (ctx) => OwnerManagementModal(
                              initialOwners: _owners,
                              onSaveOwners: (updatedOwners) {
                                setState(() => _owners = updatedOwners);
                                widget.onSaveOwners(updatedOwners);
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _buildSubSectionCard(
                    title: 'Pools Management',
                    subtitle: 'Manage custom Zaznamity pools',
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Open Pool Manager', style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (ctx) => PoolManagementModal(
                              initialPools: _pools,
                              onSavePools: (updatedPools) {
                                setState(() => _pools = updatedPools);
                                widget.onSavePools(updatedPools);
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _buildSubSectionCard(
                    title: 'Liquid Net Counting Pools',
                    subtitle: 'Choose which pools contribute to liquid net',
                    children: _pools.keys.map((poolKey) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(poolKey.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        value: _liquidNetPools[poolKey] ?? true,
                        onChanged: (val) {
                          setState(() {
                            _liquidNetPools[poolKey] = val ?? false;
                          });
                          widget.onSaveLiquidNetPools(_liquidNetPools);
                        },
                      );
                    }).toList(),
                  ),
                  _buildSubSectionCard(
                    title: 'Future Metrics Counting Pools',
                    subtitle: 'Configure which pools update future metrics',
                    children: _pools.keys.map((poolKey) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(poolKey.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        value: _prognosisPools[poolKey] ?? false,
                        onChanged: (val) {
                          setState(() {
                            _prognosisPools[poolKey] = val ?? false;
                          });
                          widget.onSavePrognosisPools(_prognosisPools);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),

              // ==========================================
              // GROUP 3: SECURITY & NOTIFICATIONS
              // ==========================================
              _buildMainCategoryGroup(
                title: 'Security & Notifications',
                subtitle: 'App security lock and reminder schedules',
                children: [
                  _buildSubSectionCard(
                    title: 'Security & App Lock',
                    subtitle: 'Secure app with PIN or Face ID',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Security Lock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        value: _biometricsEnabled,
                        onChanged: (val) async {
                          setState(() => _biometricsEnabled = val);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('biometricsEnabled', val);
                          if (widget.onPinSettingsChanged != null) {
                            widget.onPinSettingsChanged!(val, _savedPin);
                          }
                        },
                      ),
                      if (_biometricsEnabled) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Set 4-Digit PIN',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                            isDense: true,
                          ),
                          onChanged: (val) async {
                            if (val.length == 4) {
                              setState(() => _savedPin = val);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('savedPin', val);
                              if (widget.onPinSettingsChanged != null) {
                                widget.onPinSettingsChanged!(_biometricsEnabled, val);
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _biometricType,
                          items: const [
                            DropdownMenuItem(value: 'PIN', child: Text('Open on PIN Code')),
                            DropdownMenuItem(value: 'Face', child: Text('Face Biometrics / Touch ID')),
                          ],
                          onChanged: (val) => setState(() => _biometricType = val ?? 'PIN'),
                          decoration: const InputDecoration(labelText: 'Authentication Method', isDense: true),
                        ),
                      ],
                    ],
                  ),
                  _buildSubSectionCard(
                    title: 'Notifications & Reminders',
                    subtitle: 'Setup advance reminders for upcoming Zaznams',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Reminders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        value: _notificationsEnabled,
                        onChanged: (val) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('notificationsEnabled', val);
                          setState(() => _notificationsEnabled = val);
                          if (val) {
                            NotificationService.showInstantNotification(
                              title: 'Zaznamity',
                              body: 'Push notifications are now enabled!',
                            );
                          } else {
                            NotificationService.cancelNotifications();
                          }
                        },
                      ),
                      if (_notificationsEnabled) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Days before: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            DropdownButton<int>(
                              value: _notifyDaysBefore,
                              items: [0, 1, 2, 3, 5, 7].map((d) => DropdownMenuItem(value: d, child: Text('$d day(s)'))).toList(),
                              onChanged: (val) {},
                            ),
                            const SizedBox(width: 20),
                            const Text('Hours: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            DropdownButton<int>(
                              value: _notifyHoursBefore,
                              items: [8, 9, 10, 12, 18, 20].map((h) => DropdownMenuItem(value: h, child: Text('$h:00'))).toList(),
                              onChanged: (val) {},
                            ),
                          ],
                        ),
                      ]
                    ],
                  ),
                ],
              ),

              // ==========================================
              // GROUP 4: DATA MANAGEMENT & SYSTEM
              // ==========================================
              _buildMainCategoryGroup(
                title: 'Data Management & System',
                subtitle: 'Reports, CSV imports, and zone actions',
                children: [
                  _buildSubSectionCard(
                    title: 'Zaznamity Reports',
                    subtitle: 'Generate PDF Financial Reports',
                    children: [
                      const Text(
                        'Generate customized PDF Zaznamity Reports by selecting your preferred timeframe, pools, charts and more.\n'
                        'Reports are saved automatically to your device\'s Downloads folder.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 88, 47, 149),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _showReportConfigModal,
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Configure Report', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  _buildSubSectionCard(
                    title: 'CSV Import Mapper',
                    subtitle: 'Select, map, and import your CSV data',
                    children: [
                      const Text(
                        'Upload any CSV file, match your columns to Zaznamity fields, choose to create labels, owners and pools, and detect future transactions.\n\n'
                        'This feature is designed to help you import your financial data from other sources into Zaznamity with ease and efficiency.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 88, 47, 149),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            CsvImportMapperWorkflow.runCsvImportWorkflow(
                              context: context,
                              labels: widget.labels,
                              owners: _owners,
                              pools: _pools.keys.toList(),
                              onImportCompleted: () {
                                if (widget.onImportCsv != null) {
                                  widget.onImportCsv!();
                                }
                              },
                            );
                          },
                          icon: const Icon(Icons.alt_route, size: 18),
                          label: const Text('CSV Import Mapper', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  _buildSubSectionCard(
                    title: 'Delete Zaznams - DANGER ZONE',
                    subtitle: 'Delete Zaznams in bulk by month, year, or all',
                    children: [
                      const Text(
                        'Permanently delete zaznams based on time range.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _showBulkDeleteDialog,
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          label: const Text('Bulk Delete Zaznams', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  _buildSubSectionCard(
                    title: 'About Zaznamity',
                    subtitle: 'App version, credits, and details',
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Welcome to Zaznamity v1.0.0!\n\n'
                          '"Zaznam" in Slovak means record or transaction. Keep track of all your Zaznams and keep them secure on your phone—no cloud, no subscriptions.\n\n'
                          'Local-first (SQLite): Full privacy and ownership. Your financial data stays entirely on your device.\n\n'
                          'Features of this app:\n',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainCategoryGroup({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF582F95),
            letterSpacing: 1.0,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        children: children,
      ),
    );
  }

  Widget _buildSubSectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        children: children,
      ),
    );
  }
}