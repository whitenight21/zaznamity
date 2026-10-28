// ignore_for_file: unnecessary_this, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:zaznamity/models/card_config.dart';
import 'package:zaznamity/models/label.dart';
import 'package:zaznamity/models/liability_model.dart';
import 'package:zaznamity/models/savings_goal_model.dart';
import 'package:zaznamity/services/database_helper.dart';
import 'package:zaznamity/services/notification_service.dart';
import 'package:zaznamity/widgets/settings/owner_management_modal.dart';
import 'package:zaznamity/widgets/settings/pool_management_modal.dart';
import 'package:zaznamity/widgets/csv_import_mapper_dialog.dart';
import 'package:zaznamity/widgets/settings/history_display_settings_widget.dart';

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
  final Function(int, String, String) onUpdateLabel; // Updated to include hex color
  final Function(int) onDeleteLabel;
  final VoidCallback? onImportCsv;
  final Function(String, {int? year, int? month}) onDeleteBulkTransactions;
  final Function(int)? onDeleteTransactionsByLabel; 
  final Function(String, String) onBulkUpdateTransactionsLabel; 
  final Function(String, String, String) onBulkUpdateTransactionsPool;
  final VoidCallback? onLiabilityUpdated;
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
    this.onDeleteTransactionsByLabel,
    required this.onBulkUpdateTransactionsLabel,
    required this.onBulkUpdateTransactionsPool,
    this.onLiabilityUpdated,
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
  
  bool _isZaznamityMode = true;
  bool _isCollapsed = false;
  bool _notificationsEnabled = true;
  final int _notifyDaysBefore = 1;
  final int _notifyHoursBefore = 9;
  
  bool _biometricsEnabled = false;
  String _biometricType = 'PIN';
  String _savedPin = "1234";
  bool _isPinVisible = false;

  String _primaryCurrency = 'USD';
  String? _secondaryCurrency1;
  String? _secondaryCurrency2;
  String? _secondaryCurrency3;

  String _calendarStartDay = 'Monday';

  bool _titleCardVisible = true;

  final Map<String, bool> _multiLabelFixedCategories = {};

  bool _liquidTrendShowFuture = false;
  bool _poolsTrendsShowFuture = false;
  final Map<String, bool> _poolsTrendsVisibility = {};

  bool _budgetRolloverEnabled = false;
  bool _excludeTransfersFromInsights = true;

  List<File> _savedReportsList = [];
  List<File> _savedExportsList = []; // New separate list for CSV & JSON backups
  List<LiabilityModel> _liabilitiesList = [];
  List<SavingsGoalModel> _savingsGoalsList = [];

  final List<Map<String, String>> _availableCurrencies = [
    // Primary / Major
    {'code': 'EUR', 'name': '🇪🇺 Euro (€)'},
    {'code': 'USD', 'name': '🇺🇸 US Dollar (\$)'},
    {'code': 'CAD', 'name': '🇨🇦 Canadian Dollar (C\$)'},
    {'code': 'GBP', 'name': '🇬🇧 British Pound (£)'},
    // European Currencies
    {'code': 'CZK', 'name': '🇨🇿 Czech Koruna (Kč)'},
    {'code': 'HUF', 'name': '🇭🇺 Hungarian Forint (Ft)'},
    {'code': 'PLN', 'name': '🇵🇱 Polish Zloty (zł)'},
    {'code': 'CHF', 'name': '🇨🇭 Swiss Franc (CHF)'},
    {'code': 'RUB', 'name': '🇷🇺 Russian Ruble (₽)'},
    // Asian Currencies
    {'code': 'JPY', 'name': '🇯🇵 Japanese Yen (¥)'},
    {'code': 'CNY', 'name': '🇨🇳 Chinese Yuan (¥)'},
    {'code': 'HKD', 'name': '🇭🇰 Hong Kong Dollar (HK\$)'},
    {'code': 'SGD', 'name': '🇸🇬 Singapore Dollar (S\$)'},
    {'code': 'AUD', 'name': '🇦🇺 Australian Dollar (A\$)'},
    // South American Currencies
    {'code': 'BRL', 'name': '🇧🇷 Brazilian Real (R\$)'},
    {'code': 'MXN', 'name': '🇲🇽 Mexican Peso (\$)'},
    {'code': 'CLP', 'name': '🇨🇱 Chilean Peso (\$)'},
    {'code': 'COP', 'name': '🇨🇴 Colombian Peso (\$)'},
  ];

  final List<String> _labelPalette = [
    '#582F95', // Deep Purple
    '#A855F7', // Vivid Purple
    '#6366F1', // Indigo
    '#3B82F6', // Blue
    '#0284C7', // Light Blue
    '#06B6D4', // Cyan
    '#10B981', // Emerald
    '#059669', // Green
    '#84CC16', // Lime
    '#EAB308', // Yellow
    '#F59E0B', // Amber
    '#F97316', // Orange
    '#EF4444', // Red
    '#EC4899', // Pink
    '#D946EF', // Fuchsia
    '#64748B', // Slate Gray
  ];
  
  final TextEditingController _newLabelController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pools = Map.from(widget.initialPools);
    _liquidNetPools = Map.from(widget.initialLiquidNetPools);
    _prognosisPools = Map.from(widget.initialPrognosisPools);
    _owners = List.from(widget.initialOwners);
    
    for (var poolKey in _pools.keys) {
      _poolsTrendsVisibility[poolKey] = true;
    }

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

    for (var label in widget.labels) {
      _multiLabelFixedCategories[label.name] = false;
    }
    
    _loadPrefs();
    _loadSavedReports();
    _loadLiabilities();
    _loadSavingsGoals();
  }

  @override
  void dispose() {
    _newLabelController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AppSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialOwners != oldWidget.initialOwners) {
      _owners = List.from(widget.initialOwners);
    }
    if (widget.labels != oldWidget.labels) {
      for (var label in widget.labels) {
        _multiLabelFixedCategories.putIfAbsent(label.name, () => false);
      }
    }
    _loadPrefs(); // Re-loads preferences instantly on widget update
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final themeStr = prefs.getString('app_theme') ?? 'zaznamity';
      _isZaznamityMode = (themeStr == 'zaznamity');
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _biometricsEnabled = prefs.getBool('biometricsEnabled') ?? false;
      _biometricType = prefs.getString('biometricType') ?? 'PIN';
      _savedPin = prefs.getString('savedPin') ?? "1234";
      _pinController.text = _savedPin;

      _primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';
      _secondaryCurrency1 = prefs.getString('secondaryCurrency1');
      _secondaryCurrency2 = prefs.getString('secondaryCurrency2');
      _secondaryCurrency3 = prefs.getString('secondaryCurrency3');

      _calendarStartDay = prefs.getString('calendarStartDay') ?? 'Monday';

      _titleCardVisible = prefs.getBool('titleCardVisible') ?? true;
      _excludeTransfersFromInsights = prefs.getBool('exclude_transfers_insights') ?? true;

      for (var label in widget.labels) {
        _multiLabelFixedCategories[label.name] = prefs.getBool('set_multilabel_fixed_${label.name}') ?? false;
      }

      for (var poolKey in _pools.keys) {
        _poolsTrendsVisibility[poolKey] = prefs.getBool('set_poolsTrends_pool_visible_$poolKey') ?? true;
        _liquidNetPools[poolKey] = prefs.getBool('set_liquidNet_pool_$poolKey') ?? true;
      }

      _liquidTrendShowFuture = prefs.getBool('set_liquidTrend_show_future') ?? false;
      _poolsTrendsShowFuture = prefs.getBool('set_poolsTrends_show_future') ?? false;
      _budgetRolloverEnabled = prefs.getBool('set_budget_rollover') ?? false;

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

  Future<void> _loadLiabilities() async {
    try {
      final dbLiabilities = await DatabaseHelper.instance.getLiabilities();
      setState(() {
        _liabilitiesList = dbLiabilities;
      });
    } catch (_) {}
  }

  Future<void> _loadSavingsGoals() async {
    try {
      final dbGoals = await DatabaseHelper.instance.getSavingsGoals();
      setState(() {
        _savingsGoalsList = dbGoals;
      });
    } catch (_) {}
  }

  Future<void> _loadSavedReports() async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      if (await directory.exists()) {
        final List<FileSystemEntity> entities = directory.listSync();
        
        List<File> pdfFiles = [];
        List<File> exportFiles = [];

        for (var entity in entities) {
          if (entity is File) {
            final path = entity.path;
            final lowerPath = path.toLowerCase();
            
            // Check for PDF reports
            if (lowerPath.endsWith('.pdf')) {
              pdfFiles.add(entity);
            }
            
            // Check for CSV or JSON exports (captures any file ending in .csv or .json)
            if (lowerPath.endsWith('.csv') || lowerPath.endsWith('.json')) {
              exportFiles.add(entity);
            }
          }
        }

        // Sort both lists by last modified date (newest first)
        pdfFiles.sort((a, b) {
          try {
            return b.lastModifiedSync().compareTo(a.lastModifiedSync());
          } catch (_) {
            return 0;
          }
        });

        exportFiles.sort((a, b) {
          try {
            return b.lastModifiedSync().compareTo(a.lastModifiedSync());
          } catch (_) {
            return 0;
          }
        });

        if (mounted) {
          setState(() {
            _savedReportsList = pdfFiles;
            _savedExportsList = exportFiles;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading saved reports/exports: $e');
    }
  }

  Future<void> _openReportFile(File file) async {
    try {
      final path = file.path.toLowerCase();
      if (path.endsWith('.pdf')) {
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
          await _shareFile(file);
        }
      } else {
        await _shareFile(file);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: $e')),
      );
    }
  }

  Future<void> _shareFile(File file) async {
    try {
      await Share.shareXFiles([XFile(file.path)], text: 'Zaznamity Backup File');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sharing failed: $e')),
      );
    }
  }

  Future<void> _deleteReportFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
      await _loadSavedReports();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting file: $e')),
      );
    }
  }

  void _showDeleteManagerDialog() {
    bool deleteLabels = false;
    bool deleteOwners = false;
    bool deletePools = false;
    bool deleteZaznams = false;
    bool wipeAll = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626)),
              const SizedBox(width: 8),
              Text(
                'Delete Manager',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select items to permanently remove from phone storage:',
                    style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Delete All Labels', style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                    value: wipeAll || deleteLabels,
                    activeColor: const Color(0xFFDC2626),
                    onChanged: wipeAll ? null : (val) => setModalState(() => deleteLabels = val ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Delete All Owners', style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                    value: wipeAll || deleteOwners,
                    activeColor: const Color(0xFFDC2626),
                    onChanged: wipeAll ? null : (val) => setModalState(() => deleteOwners = val ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Delete All Pools', style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                    value: wipeAll || deletePools,
                    activeColor: const Color(0xFFDC2626),
                    onChanged: wipeAll ? null : (val) => setModalState(() => deletePools = val ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Delete All Zaznams', style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : Colors.black87)),
                    value: wipeAll || deleteZaznams,
                    activeColor: const Color(0xFFDC2626),
                    onChanged: wipeAll ? null : (val) => setModalState(() => deleteZaznams = val ?? false),
                  ),
                  const Divider(),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('WIPE ALL DATA FROM PHONE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                    subtitle: const Text('Performs complete factory reset of app database', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    value: wipeAll,
                    activeColor: const Color(0xFFDC2626),
                    onChanged: (val) {
                      setModalState(() {
                        wipeAll = val ?? false;
                        if (wipeAll) {
                          deleteLabels = true;
                          deleteOwners = true;
                          deletePools = true;
                          deleteZaznams = true;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                if (wipeAll || deleteZaznams) {
                  widget.onDeleteBulkTransactions('all');
                }
                if (wipeAll || deleteLabels) {
                  for (var l in List.from(widget.labels)) {
                    widget.onDeleteLabel(l.id);
                  }
                }
                if (wipeAll || deleteOwners) {
                  widget.onSaveOwners(['Owner 1']);
                }
                if (wipeAll || deletePools) {
                  widget.onSavePools({'checking': true, 'cash': true, 'savings': true});
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete operation executed successfully')),
                  );
                }
              },
              child: const Text('Execute Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExportPreviewDialog(String format) async {
    String selectedRangeMode = 'all';
    int selectedYear = DateTime.now().year;
    int selectedMonth = DateTime.now().month;
    DateTime customStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime customEnd = DateTime.now();

    try {
      final allTxs = await DatabaseHelper.instance.getTransactions();
      final Map<int, String> labelMap = {
        for (var l in widget.labels) l.id: l.name
      };

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setStateModal) {
            final filteredTxs = allTxs.where((tx) {
              final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
              if (selectedRangeMode == 'month') {
                return txDate.year == selectedYear && txDate.month == selectedMonth;
              } else if (selectedRangeMode == 'year') {
                return txDate.year == selectedYear;
              } else if (selectedRangeMode == 'custom') {
                final startOfDay = DateTime(customStart.year, customStart.month, customStart.day);
                final endOfDay = DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59);
                return !txDate.isBefore(startOfDay) && !txDate.isAfter(endOfDay);
              }
              return true;
            }).toList();

            String previewHeader = 'ID,CreatedAt,Type,Amount,Description,Owner,Pool,CurrencyCode,LabelId,LabelName,IsConfirmed\n';
            final previewRowsBuffer = StringBuffer();
            
            for (var tx in filteredTxs.take(2)) {
              final double exportAmount = (tx.type.toLowerCase() == 'expense') ? -tx.amount.abs() : tx.amount.abs();
              final labelName = labelMap[tx.labelId] ?? 'General';
              previewRowsBuffer.writeln('${tx.id},"${tx.createdAt}","${tx.type}",$exportAmount,"${tx.description}","${tx.owner}","${tx.pool}","${tx.currencyCode}",${tx.labelId},"$labelName",${tx.isConfirmed}');
            }

            final previewContent = previewHeader + previewRowsBuffer.toString();

            return AlertDialog(
              backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Export Preview (${format.toUpperCase()})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                ),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Export Date Range:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRangeMode,
                        dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                        style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 12),
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All-Time Ledger History')),
                          DropdownMenuItem(value: 'month', child: Text('By Specific Month')),
                          DropdownMenuItem(value: 'year', child: Text('By Specific Year')),
                          DropdownMenuItem(value: 'custom', child: Text('Custom Date Range')),
                        ],
                        onChanged: (val) => setStateModal(() => selectedRangeMode = val ?? 'all'),
                      ),
                      if (selectedRangeMode == 'month' || selectedRangeMode == 'year') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: selectedYear,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 12),
                                decoration: const InputDecoration(labelText: 'Year', isDense: true, border: OutlineInputBorder()),
                                items: List.generate(11, (i) => 2020 + i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                                onChanged: (val) => setStateModal(() => selectedYear = val ?? selectedYear),
                              ),
                            ),
                            if (selectedRangeMode == 'month') ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: selectedMonth,
                                  dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                  style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 12),
                                  decoration: const InputDecoration(labelText: 'Month', isDense: true, border: OutlineInputBorder()),
                                  items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text('$m'))).toList(),
                                  onChanged: (val) => setStateModal(() => selectedMonth = val ?? selectedMonth),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (selectedRangeMode == 'custom') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: customStart,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) setStateModal(() => customStart = picked);
                                },
                                icon: const Icon(Icons.calendar_today, size: 14),
                                label: Text('Start: ${DateFormat('yyyy-MM-dd').format(customStart)}', style: const TextStyle(fontSize: 11)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: customEnd,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) setStateModal(() => customEnd = picked);
                                },
                                icon: const Icon(Icons.calendar_today, size: 14),
                                label: Text('End: ${DateFormat('yyyy-MM-dd').format(customEnd)}', style: const TextStyle(fontSize: 11)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        'Total Matching Records: ${filteredTxs.length} (Showing 2-Row Horizontal Preview)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 600),
                            child: Text(
                              filteredTxs.isEmpty ? 'No zaznams match the selected date range.' : previewContent,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: _isZaznamityMode ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _executeExportData(format, selectedRangeMode, selectedYear, selectedMonth, customStart, customEnd);
                  },
                  child: const Text('Confirm & Save'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview error: $e')),
      );
    }
  }

  Future<void> _executeExportData(
    String format,
    String rangeMode,
    int year,
    int month,
    DateTime customStart,
    DateTime customEnd,
  ) async {
    try {
      final allTxs = await DatabaseHelper.instance.getTransactions();
      
      final filteredTxs = allTxs.where((tx) {
        final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
        if (rangeMode == 'month') {
          return txDate.year == year && txDate.month == month;
        } else if (rangeMode == 'year') {
          return txDate.year == year;
        } else if (rangeMode == 'custom') {
          final startOfDay = DateTime(customStart.year, customStart.month, customStart.day);
          final endOfDay = DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59);
          return !txDate.isBefore(startOfDay) && !txDate.isAfter(endOfDay);
        }
        return true;
      }).toList();

      String fileContent = '';
      String extension = format.toLowerCase();
      
      final Map<int, String> labelMap = {
        for (var l in widget.labels) l.id: l.name
      };

      if (extension == 'csv') {
        final buffer = StringBuffer();
        buffer.writeln('ID,CreatedAt,Type,Amount,Description,Owner,Pool,CurrencyCode,LabelId,LabelName,IsConfirmed');
        
        for (var tx in filteredTxs) {
          final safeDescription = tx.description.replaceAll('"', '""');
          final safeOwner = tx.owner.replaceAll('"', '""');
          final safePool = tx.pool.replaceAll('"', '""');
          final safeCurrency = tx.currencyCode.replaceAll('"', '""');
          
          final double exportAmount = (tx.type.toLowerCase() == 'expense') 
              ? -tx.amount.abs() 
              : tx.amount.abs();
          
          final labelName = labelMap[tx.labelId] ?? 'General';
          final safeLabelName = labelName.replaceAll('"', '""');

          buffer.writeln(
            '${tx.id},'
            '"${tx.createdAt}",'
            '"${tx.type}",'
            '$exportAmount,'
            '"$safeDescription",'
            '"$safeOwner",'
            '"$safePool",'
            '"$safeCurrency",'
            '${tx.labelId},'
            '"$safeLabelName",'
            '${tx.isConfirmed}'
          );
        }
        fileContent = buffer.toString();
      } else {
        final List<Map<String, dynamic>> txMaps = filteredTxs.map((tx) => {
          'id': tx.id,
          'createdAt': tx.createdAt,
          'type': tx.type,
          'amount': (tx.type.toLowerCase() == 'expense') ? -tx.amount.abs() : tx.amount.abs(),
          'description': tx.description,
          'owner': tx.owner,
          'pool': tx.pool,
          'currencyCode': tx.currencyCode,
          'labelId': tx.labelId,
          'labelName': labelMap[tx.labelId] ?? 'General',
          'isConfirmed': tx.isConfirmed,
        }).toList();
        
        fileContent = txMaps.toString();
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Z_ExportZaznams_$timestamp.$extension';

      final directory = await getApplicationDocumentsDirectory();
      final savedFile = File('${directory.path}/$fileName');
      
      await savedFile.writeAsString(fileContent, encoding: utf8);
      await _loadSavedReports();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup saved successfully: $fileName (${filteredTxs.length} records)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _exportFullSystemBackup() async {
    try {
      final transactions = await DatabaseHelper.instance.getTransactions();
      final liabilities = await DatabaseHelper.instance.getLiabilities();
      
      List<Map<String, dynamic>> savingsGoalsMaps = [];
      try {
        final goals = await DatabaseHelper.instance.getSavingsGoals();
        for (var g in goals) {
          savingsGoalsMaps.add((g as dynamic).toMap());
        }
      } catch (_) {}

      List<Map<String, dynamic>> budgets = [];
      try {
        budgets = await DatabaseHelper.instance.getBudgets();
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> sharedPrefsData = {};
      for (String key in prefs.getKeys()) {
        final val = prefs.get(key);
        if (val is bool || val is int || val is double || val is String || val is List<String>) {
          sharedPrefsData[key] = val;
        }
      }

      final Map<String, dynamic> fullBackup = {
        'version': '1.0.0',
        'exportDate': DateTime.now().toIso8601String(),
        'preferences': sharedPrefsData,
        'labels': widget.labels.map((l) => {'id': l.id, 'name': l.name, 'color': l.color}).toList(),
        'liabilities': liabilities.map((l) => l.toMap()).toList(),
        'savingsGoals': savingsGoalsMaps,
        'budgets': budgets,
        'transactions': transactions.map((t) => t.toMap()).toList(),
      };

      final jsonString = jsonEncode(fullBackup);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Z_FullSystemBackup_$timestamp.json';

      final directory = await getApplicationDocumentsDirectory();
      final savedFile = File('${directory.path}/$fileName');
      await savedFile.writeAsString(jsonString, encoding: utf8);

      await _loadSavedReports();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Full System Backup saved successfully: $fileName')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Full backup failed: $e')),
      );
    }
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
    uniqueItems['title_card'] = 'Title Card';

    return uniqueItems.entries.map((entry) {
      return DropdownMenuItem(
        value: entry.key,
        child: Text(entry.value, style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
      );
    }).toList();
  }

  Color _parseColor(String hexStr) {
    try {
      String cleanHex = hexStr.replaceAll('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return const Color(0xFF582F95);
    }
  }

  void _editLabelDialog(LabelModel label) {
    final controller = TextEditingController(text: label.name);
    String selectedColor = label.color.isNotEmpty ? label.color : '#582F95';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Label',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
            ),
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Label Name', isDense: true, border: OutlineInputBorder()),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Label Color Palette',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _labelPalette.map((hexCode) {
                      final isSelected = selectedColor.toUpperCase() == hexCode.toUpperCase();
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = hexCode),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _parseColor(hexCode),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? (_isZaznamityMode ? Colors.white : const Color(0xFF582F95)) : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  widget.onUpdateLabel(label.id, controller.text.trim(), selectedColor);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLiabilityDialog(LiabilityModel liability) {
    final nameController = TextEditingController(text: liability.name);
    final balanceController = TextEditingController(text: liability.remainingBalance.toString());
    final installmentController = TextEditingController(text: liability.monthlyInstallment.toString());
    final aprController = TextEditingController(text: liability.interestRate.toString());
    final dueDayController = TextEditingController(text: liability.dueDay.toString());
    String selectedOwner = _owners.contains(liability.owner) ? liability.owner : (_owners.isNotEmpty ? _owners.first : 'Shared');
    
    DateTime selectedProjectionDate = liability.projectionEndDate != null 
        ? (DateTime.tryParse(liability.projectionEndDate!) ?? DateTime.now().add(const Duration(days: 365)))
        : DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Liability: ${liability.name}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
            ),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Liability Name', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balanceController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Remaining Balance', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: installmentController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Monthly Installment', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: aprController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Interest Rate (APR %)', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dueDayController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Due Day of Month (1-31)', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedOwner,
                    dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Owner', isDense: true, border: OutlineInputBorder()),
                    items: _owners.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => selectedOwner = val);
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
                            setStateModal(() => selectedProjectionDate = picked);
                          }
                        },
                        child: Text('Reproject Date', style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  final updatedLiability = LiabilityModel(
                    id: liability.id,
                    name: nameController.text.trim(),
                    remainingBalance: double.tryParse(balanceController.text) ?? liability.remainingBalance,
                    monthlyInstallment: double.tryParse(installmentController.text) ?? liability.monthlyInstallment,
                    interestRate: double.tryParse(aprController.text) ?? liability.interestRate,
                    dueDay: int.tryParse(dueDayController.text) ?? liability.dueDay,
                    owner: selectedOwner,
                    lastProcessedDate: liability.lastProcessedDate,
                    projectionEndDate: selectedProjectionDate.toIso8601String(),
                  );

                  await DatabaseHelper.instance.deleteTransactionsByLabelOrDescription(liability.name);
                  await DatabaseHelper.instance.insertLiability(updatedLiability);
                  await DatabaseHelper.instance.updateExistingLiabilityTransactions(
                    liability.id!, 
                    liability.name, 
                    updatedLiability,
                  );
                  final allTxs = await DatabaseHelper.instance.getTransactions();
                  for (var tx in allTxs) {
                    if (tx.description.contains(liability.name)) {
                      final txDate = DateTime.tryParse(tx.createdAt);
                      if (txDate != null && txDate.isAfter(selectedProjectionDate)) {
                        await DatabaseHelper.instance.deleteTransaction(tx.id!);
                      }
                    }
                  }
                  await DatabaseHelper.instance.checkAndApplyAutomaticLiabilityPayments();
                  await _loadLiabilities();

                  if (widget.onLiabilityUpdated != null) {
                    widget.onLiabilityUpdated!();
                  }

                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Liability updated and payments reprojected successfully'))
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating liability: $e'))
                  );
                }
              },
              child: const Text('Save Changes & Reproject'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSavingsGoalDialog(SavingsGoalModel goal) {
    final nameController = TextEditingController(text: goal.name);
    final targetController = TextEditingController(text: goal.targetAmount.toString());
    String selectedOwner = _owners.contains(goal.owner) ? goal.owner : (_owners.isNotEmpty ? _owners.first : 'Shared');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Savings Goal: ${goal.name}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
            ),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Goal Name', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Target Amount', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedOwner,
                    dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Owner', isDense: true, border: OutlineInputBorder()),
                    items: _owners.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => selectedOwner = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  final updatedGoal = SavingsGoalModel(
                    id: goal.id,
                    name: nameController.text.trim(),
                    targetAmount: double.tryParse(targetController.text) ?? goal.targetAmount,
                    currentAmount: goal.currentAmount,
                    owner: selectedOwner,
                  );

                  await DatabaseHelper.instance.insertSavingsGoal(updatedGoal);
                  await _loadSavingsGoals();

                  if (widget.onLiabilityUpdated != null) {
                    widget.onLiabilityUpdated!();
                  }

                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Savings goal updated successfully'))
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating savings goal: $e'))
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfigureBudgetsDialog() async {
    List<Map<String, dynamic>> budgets = [];
    try {
      budgets = await DatabaseHelper.instance.getBudgets();
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Configure Budgets',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
            ),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Budgets',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                    ),
                  ),
                  const SizedBox(height: 6),
                  budgets.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'No budgets configured yet. Create budgets in the Budgets card.',
                            style: TextStyle(
                              fontSize: 11,
                              color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: budgets.length,
                          itemBuilder: (context, index) {
                            final b = budgets[index];
                            final labelId = b['label_id'] ?? b['labelId'];
                            double limitAmount = ((b['limit_amount'] ?? b['limitAmount'] ?? 0) as num).toDouble();
                            String currency = b['currency'] ?? _primaryCurrency;

                            final labelObj = widget.labels.firstWhere(
                              (l) => l.id == labelId,
                              orElse: () => LabelModel(id: -1, name: b['label_name'] ?? 'General', color: '582F95'),
                            );

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                labelObj.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              subtitle: Text(
                                'Limit: $currency ${limitAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF64748B),
                                ),
                                onPressed: () => _showEditSingleBudgetDialog(b, () async {
                                  final updated = await DatabaseHelper.instance.getBudgets();
                                  setDialogState(() => budgets = updated);
                                }),
                                tooltip: 'Edit Budget Parameters',
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSingleBudgetDialog(Map<String, dynamic> budgetMap, VoidCallback onUpdated) {
    final budgetId = budgetMap['id'] as int;
    final labelId = budgetMap['label_id'] ?? budgetMap['labelId'];
    double limitAmount = ((budgetMap['limit_amount'] ?? budgetMap['limitAmount'] ?? 0) as num).toDouble();
    String owner = budgetMap['owner'] ?? _owners.firstOrNull ?? 'Shared';
    String currency = budgetMap['currency'] ?? _primaryCurrency;

    final labelObj = widget.labels.firstWhere(
      (l) => l.id == labelId,
      orElse: () => LabelModel(id: -1, name: budgetMap['label_name'] ?? 'General', color: '582F95'),
    );

    final limitController = TextEditingController(text: limitAmount.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Budget: ${labelObj.name}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
            ),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: limitController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Amount Limit', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _owners.contains(owner) ? owner : (_owners.isNotEmpty ? _owners.first : owner),
                    dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Owner', isDense: true, border: OutlineInputBorder()),
                    items: _owners.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => owner = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: [_primaryCurrency, if (_secondaryCurrency1 != null) _secondaryCurrency1!, if (_secondaryCurrency2 != null) _secondaryCurrency2!, if (_secondaryCurrency3 != null) _secondaryCurrency3!].contains(currency) ? currency : _primaryCurrency,
                    dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Currency', isDense: true, border: OutlineInputBorder()),
                    items: [
                      _primaryCurrency,
                      if (_secondaryCurrency1 != null) _secondaryCurrency1!,
                      if (_secondaryCurrency2 != null) _secondaryCurrency2!,
                      if (_secondaryCurrency3 != null) _secondaryCurrency3!,
                    ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => currency = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final finalLimit = double.tryParse(limitController.text) ?? limitAmount;
                await DatabaseHelper.instance.updateBudget(budgetId, finalLimit);
                Navigator.pop(ctx);
                onUpdated();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget updated successfully')));
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportConfigModal() {
    DateTime customStartDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime customEndDate = DateTime.now();
    
    String selectedOwnerFilter = 'All';
    String selectedPoolFilter = 'All';
    String selectedLabelFilter = 'All';
    String selectedCurrencyFilter = 'All';

    bool includeSummaryCard = true;
    bool includeFutureMetricsCard = true;
    bool includeSavingsGoalsCard = true;
    bool includeBudgetCard = true;

    bool includeBarChart = true;
    bool includePieChart = false;
    bool includeLineChart = false;

    bool includeTransactionTableHistory = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: Text('Configure Zaznamity Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. SELECT CUSTOM DATE RANGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: customStartDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setStateModal(() => customStartDate = picked);
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
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setStateModal(() => customEndDate = picked);
                          },
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: Text('End: ${DateFormat('dd/MM/yyyy').format(customEndDate)}', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text('2. FLEXIBLE DRILL-DOWN FILTERS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedOwnerFilter,
                          decoration: const InputDecoration(labelText: 'Owner', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('All Owners')),
                            ..._owners.map((o) => DropdownMenuItem(value: o, child: Text(o))),
                          ],
                          onChanged: (val) => setStateModal(() => selectedOwnerFilter = val ?? 'All'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedPoolFilter,
                          decoration: const InputDecoration(labelText: 'Pool', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('All Pools')),
                            ..._pools.keys.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))),
                          ],
                          onChanged: (val) => setStateModal(() => selectedPoolFilter = val ?? 'All'),
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
                          decoration: const InputDecoration(labelText: 'Label', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('All Labels')),
                            ...widget.labels.map((l) => DropdownMenuItem(value: l.name, child: Text(l.name))),
                          ],
                          onChanged: (val) => setStateModal(() => selectedLabelFilter = val ?? 'All'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCurrencyFilter,
                          decoration: const InputDecoration(labelText: 'Currency', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)))),
                          items: [
                            const DropdownMenuItem<String>(value: 'All', child: Text('All Currencies')),
                            if (_secondaryCurrency1 != null) DropdownMenuItem<String>(value: _secondaryCurrency1!, child: Text(_secondaryCurrency1!)),
                            if (_secondaryCurrency2 != null) DropdownMenuItem<String>(value: _secondaryCurrency2!, child: Text(_secondaryCurrency2!)),
                            if (_secondaryCurrency3 != null) DropdownMenuItem<String>(value: _secondaryCurrency3!, child: Text(_secondaryCurrency3!)),
                            DropdownMenuItem<String>(value: _primaryCurrency, child: Text(_primaryCurrency)),
                          ],
                          onChanged: (val) => setStateModal(() => selectedCurrencyFilter = val ?? 'All'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text('3. CARD PARAMETERS & METRICS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include Metrics', style: TextStyle(fontSize: 12)),
                    value: includeSummaryCard,
                    onChanged: (val) => setStateModal(() => includeSummaryCard = val ?? true),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include Future Metrics', style: TextStyle(fontSize: 12)),
                    value: includeFutureMetricsCard,
                    onChanged: (val) => setStateModal(() => includeFutureMetricsCard = val ?? true),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include Savings Goals', style: TextStyle(fontSize: 12)),
                    value: includeSavingsGoalsCard,
                    onChanged: (val) => setStateModal(() => includeSavingsGoalsCard = val ?? true),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include Budgets', style: TextStyle(fontSize: 12)),
                    value: includeBudgetCard,
                    onChanged: (val) => setStateModal(() => includeBudgetCard = val ?? true),
                  ),
                  const SizedBox(height: 14),

                  Text('4. CHART VISUALIZATIONS (Checkmark Select)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bar Chart (Multi-Label Analytics)', style: TextStyle(fontSize: 12)),
                    value: includeBarChart,
                    onChanged: (val) => setStateModal(() => includeBarChart = val ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pie Chart (Multi-Label Analytics)', style: TextStyle(fontSize: 12)),
                    value: includePieChart,
                    onChanged: (val) => setStateModal(() => includePieChart = val ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Liquid Trend', style: TextStyle(fontSize: 12)),
                    value: includeLineChart,
                    onChanged: (val) => setStateModal(() => includeLineChart = val ?? false),
                  ),
                  const SizedBox(height: 14),

                  Text('5. DATA GROUPING & HISTORY TABLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('List Zaznam history as last parameter (Full Zaznams table)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    value: includeTransactionTableHistory,
                    onChanged: (val) => setStateModal(() => includeTransactionTableHistory = val ?? true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                
                try {
                  final allTxs = await DatabaseHelper.instance.getTransactions();
                  
                  final startOfDay = DateTime(customStartDate.year, customStartDate.month, customStartDate.day);
                  final endOfDay = DateTime(customEndDate.year, customEndDate.month, customEndDate.day, 23, 59, 59);

                  final filteredTxs = allTxs.where((tx) {
                    final txDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
                    if (txDate.isBefore(startOfDay) || txDate.isAfter(endOfDay)) return false;

                    if (selectedOwnerFilter != 'All' && tx.owner != selectedOwnerFilter) return false;
                    if (selectedPoolFilter != 'All' && tx.pool != selectedPoolFilter) return false;
                    if (selectedCurrencyFilter != 'All' && tx.currencyCode != selectedCurrencyFilter) return false;

                    if (selectedLabelFilter != 'All') {
                      final labelObj = widget.labels.firstWhere(
                        (l) => l.name == selectedLabelFilter,
                        orElse: () => LabelModel(id: -999, name: '', color: '582F95'),
                      );
                      if (tx.labelId != labelObj.id) return false;
                    }

                    return true;
                  }).toList();

                  double totalIncome = 0;
                  double totalExpense = 0;
                  for (var tx in filteredTxs) {
                    if (tx.type == 'income') {
                      totalIncome += tx.amount;
                    } else {
                      totalExpense += tx.amount;
                    }
                  }
                  final netBalance = totalIncome - totalExpense;

                  final pdfDoc = pw.Document();
                  final logoImage = pw.MemoryImage(
                    (await rootBundle.load('assets/ZaznamityLogo_onlyZwhite.png'))
                        .buffer
                        .asUint8List(),
                  );
                  
                  final formattedDateRange = '${DateFormat('dd/MM/yyyy').format(customStartDate)} - ${DateFormat('dd/MM/yyyy').format(customEndDate)}';

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
                                'Zaznamity Financial Statement',
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
                            'Page ${context.pageNumber} of ${context.pagesCount} — Secure Local Ledger',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                          ),
                        );
                      },
                      build: (pw.Context context) {
                        List<pw.Widget> childrenWidgets = [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(16),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(_isZaznamityMode ? 0xFFA855F7 : 0xFF582F95),
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
                                      width: 50,
                                      height: 50,
                                      fit: pw.BoxFit.cover,
                                    ),
                                    pw.SizedBox(width: 12),
                                    pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(
                                          'ZAZNAMITY REPORT',
                                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                                        ),
                                        pw.SizedBox(height: 4),
                                        pw.Text(
                                          'Timeframe: $formattedDateRange | Owner: $selectedOwnerFilter',
                                          style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                pw.Text(
                                  'Generated: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 20),
                        ];

                        if (includeSummaryCard) {
                          childrenWidgets.add(pw.Text('• Summary Metrics & Assets Overview', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(_isZaznamityMode ? 0xFFE2E8F0 : 0xFF1E293B))));
                          childrenWidgets.add(pw.SizedBox(height: 6));
                          childrenWidgets.add(pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Filters — Pool: $selectedPoolFilter | Currency: $selectedCurrencyFilter | Label: $selectedLabelFilter', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                                pw.SizedBox(height: 6),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('Total Income: \$${totalIncome.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                                    pw.Text('Total Expenses: \$${totalExpense.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                                    pw.Text('Net Balance: \$${netBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(_isZaznamityMode ? 0xFFA855F7 : 0xFF582F95))),
                                  ],
                                ),
                              ],
                            ),
                          ));
                          childrenWidgets.add(pw.SizedBox(height: 14));
                        }

                        if (includeFutureMetricsCard) {
                          childrenWidgets.add(pw.Text('• Future Metrics & Scheduled Flow', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(_isZaznamityMode ? 0xFFE2E8F0 : 0xFF1E293B))));
                          childrenWidgets.add(pw.SizedBox(height: 6));
                          childrenWidgets.add(pw.Container(height: 25, alignment: pw.Alignment.centerLeft, child: pw.Text('[Future metrics parameters and prognosis included]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))));
                          childrenWidgets.add(pw.SizedBox(height: 14));
                        }

                        if (includeSavingsGoalsCard || includeBudgetCard) {
                          childrenWidgets.add(pw.Text('• Savings Goals & Budget Status', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(_isZaznamityMode ? 0xFFE2E8F0 : 0xFF1E293B))));
                          childrenWidgets.add(pw.SizedBox(height: 6));
                          childrenWidgets.add(pw.Container(height: 25, alignment: pw.Alignment.centerLeft, child: pw.Text('[Goals and budget parameters included]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))));
                          childrenWidgets.add(pw.SizedBox(height: 14));
                        }

                        if (includeBarChart) {
                          childrenWidgets.add(pw.Text('• Visual Chart: Bar Chart', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(_isZaznamityMode ? 0xFFE2E8F0 : 0xFF1E293B))));
                          childrenWidgets.add(pw.SizedBox(height: 4));
                          childrenWidgets.add(pw.Container(height: 45, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)), child: pw.Text('[Bar Chart Rendering]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))));
                          childrenWidgets.add(pw.SizedBox(height: 10));
                        }

                        if (includePieChart) {
                          childrenWidgets.add(pw.Text('• Visual Chart: Pie Chart', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(_isZaznamityMode ? 0xFFE2E8F0 : 0xFF1E293B))));
                          childrenWidgets.add(pw.SizedBox(height: 4));
                          childrenWidgets.add(pw.Container(height: 45, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)), child: pw.Text('[Pie Chart Rendering]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))));
                          childrenWidgets.add(pw.SizedBox(height: 10));
                        }

                        if (includeLineChart) {
                          childrenWidgets.add(pw.Text('• Visual Chart: Liquid Trend', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(_isZaznamityMode ? 0xFFE2E8F0 : 0xFF1E293B))));
                          childrenWidgets.add(pw.SizedBox(height: 4));
                          childrenWidgets.add(pw.Container(height: 45, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)), child: pw.Text('[Line Chart Rendering]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))));
                          childrenWidgets.add(pw.SizedBox(height: 10));
                        }

                        if (includeTransactionTableHistory) {
                          childrenWidgets.add(pw.SizedBox(height: 6));
                          childrenWidgets.add(pw.Text('• All Zaznams (${filteredTxs.length})', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(_isZaznamityMode ? 0xFFE2E8F0 : 0xFF1E293B))));
                          childrenWidgets.add(pw.SizedBox(height: 6));
                          
                          if (filteredTxs.isEmpty) {
                            childrenWidgets.add(pw.Text('No Zaznams found for the selected timeframe and filters.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)));
                          } else {
                            childrenWidgets.add(pw.Table(
                              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                              children: [
                                pw.TableRow(
                                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                                  children: [
                                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Owner', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Pool', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                                  ],
                                ),
                                ...filteredTxs.map((tx) {
                                  final dateStr = tx.createdAt.split('T')[0];
                                  return pw.TableRow(
                                    children: [
                                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(dateStr, style: const pw.TextStyle(fontSize: 8))),
                                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(tx.description, style: const pw.TextStyle(fontSize: 8))),
                                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(tx.owner, style: const pw.TextStyle(fontSize: 8))),
                                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(tx.pool, style: const pw.TextStyle(fontSize: 8))),
                                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${tx.type == 'expense' ? '-' : '+'}\$${tx.amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, color: tx.type == 'expense' ? PdfColors.red700 : PdfColors.green700))),
                                    ],
                                  );
                                }),
                              ],
                            ));
                          }
                        }

                        return childrenWidgets;
                      },
                    ),
                  );

                  final dateStamp = '${customStartDate.year}${customStartDate.month.toString().padLeft(2, '0')}${customStartDate.day.toString().padLeft(2, '0')}_to_${customEndDate.year}${customEndDate.month.toString().padLeft(2, '0')}${customEndDate.day.toString().padLeft(2, '0')}';
                  final fileName = 'ZaznamityReport_$dateStamp.pdf';

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

                  await _loadSavedReports();

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Report saved to Downloads & Log: $fileName (${filteredTxs.length} zaznams included)')),
                  );

                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving PDF report: $e')),
                  );
                }
              },
              child: const Text('Generate & Save PDF'),
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
          title: const Text('Bulk Edit Zaznams by Label', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change all Zaznams labeled:', style: TextStyle(fontSize: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
              const SizedBox(height: 16),
              Text('currently:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: oldLabelName,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                items: widget.labels.map((l) => DropdownMenuItem(value: l.name, child: Text(l.name))).toList(),
                onChanged: (val) => setStateModal(() => oldLabelName = val),
              ),
              const SizedBox(height: 16),
              Text('to new label:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
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
              style: ElevatedButton.styleFrom(backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), foregroundColor: Colors.white),
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

  void _showBulkMoveLabelToPoolDialog() {
    String selectedOwner = _owners.isNotEmpty ? _owners.first : 'Shared';
    String selectedLabelName = widget.labels.isNotEmpty ? widget.labels.first.name : '';
    String selectedPool = _pools.keys.isNotEmpty ? _pools.keys.first : 'checking';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: Text('Bulk Move Zaznams by Label to Pool', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Owner:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: selectedOwner,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                items: _owners.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (val) => setStateModal(() => selectedOwner = val ?? selectedOwner),
              ),
              const SizedBox(height: 14),
              Text('Select Label / Category:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: selectedLabelName.isNotEmpty ? selectedLabelName : null,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                items: widget.labels.map((l) => DropdownMenuItem(value: l.name, child: Text(l.name))).toList(),
                onChanged: (val) => setStateModal(() => selectedLabelName = val ?? selectedLabelName),
              ),
              const SizedBox(height: 14),
              Text('Move to Target Pool:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: selectedPool,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                items: _pools.keys.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
                onChanged: (val) => setStateModal(() => selectedPool = val ?? selectedPool),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95), foregroundColor: Colors.white),
              onPressed: () {
                if (selectedLabelName.isNotEmpty) {
                  Navigator.pop(ctx);
                  widget.onBulkUpdateTransactionsPool(selectedOwner, selectedLabelName, selectedPool);
                }
              },
              child: const Text('Execute Move'),
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ZAZNAMITY SETTINGS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
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
                            onPressed: () {
                              setState(() {
                                _isCollapsed = !_isCollapsed;
                              });
                            },
                            icon: Icon(
                              _isCollapsed ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
                              size: 16,
                            ),
                            tooltip: _isCollapsed ? 'Uncollapse' : 'Collapse',
                          ),
                        ),
                      ),
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
                              backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                              foregroundColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
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
              if (!_isCollapsed) ...[
                const SizedBox(height: 16),
                Divider(color: _isZaznamityMode ? Colors.white24 : const Color(0xFFE2E8F0)),
                const SizedBox(height: 8),

                // ==========================================
                // GROUP 1: APPEARANCE & NAVIGATION
                // ==========================================
                _buildMainCategoryGroup(
                  title: 'Appearance & Navigation',
                  subtitle: 'Theme preferences and Navigation Bar layout',
                  children: [
                    _buildSubSectionCard(
                      title: 'Zaznamity Theme',
                      subtitle: 'Toggle: White (light) or Zaznamity (dark)',
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Enable Zaznamity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                          value: _isZaznamityMode,
                          onChanged: (val) async {
                            setState(() => _isZaznamityMode = val);
                            
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('app_theme', val ? 'zaznamity' : 'light');
                            if (widget.onThemeChanged != null) {
                              widget.onThemeChanged!(val);
                            }
                          },
                        ),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'Navigation Bar Show/Hide and Customization',
                      subtitle: 'Swipe down anywhere on the Navigation Bar to hide it - click on purple tab to bring it back into view. Configure shortcuts on the Navigation Bar: 2 left and 2 right',
                      children: [
                        Text('Left Slot 1 (Fixed)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, size: 18, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569)),
                              const SizedBox(width: 8),
                              Text('Master Owner Selector (Fixed)', style: TextStyle(fontSize: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Left Slot 2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _leftNavItems.length > 1 && _buildNavDropdownItems().any((item) => item.value == _leftNavItems[1]) ? _leftNavItems[1] : 'metrics',
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
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
                        Text('Left Slot 3', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _leftNavItems.length > 2 && _buildNavDropdownItems().any((item) => item.value == _leftNavItems[2]) ? _leftNavItems[2] : 'budget',
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
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
                        Text('Center Slot (Fixed)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
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
                              Text('New Zaznam (Fixed)', style: TextStyle(fontSize: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Right Slot 1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _rightNavItems.isNotEmpty && _buildNavDropdownItems().any((item) => item.value == _rightNavItems[0]) ? _rightNavItems[0] : 'history',
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
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
                        Text('Right Slot 2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _rightNavItems.length > 1 && _buildNavDropdownItems().any((item) => item.value == _rightNavItems[1]) ? _rightNavItems[1] : 'calendar',
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
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
                        Text('Right Slot 3 (Fixed)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF160D25) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.grid_view_rounded, size: 18, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569)),
                              const SizedBox(width: 8),
                              Text('Dashboard Snapshot (Fixed)', style: TextStyle(fontSize: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // ==========================================
                // GROUP 2: CARDS SETTINGS
                // ==========================================
                _buildMainCategoryGroup(
                  title: 'Cards Settings',
                  subtitle: 'Configure default behaviors, parameters, and filters for specific dashboard cards',
                  children: [
                    _buildSubSectionCard(
                      title: 'Welcome Card',
                      subtitle: 'Toggle card visibility',
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Show Title Card', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                          subtitle: Text('Toggle visibility of the Title Card', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                          value: _titleCardVisible,
                          onChanged: (val) async {
                            setState(() => _titleCardVisible = val);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('titleCardVisible', val);
                          },
                        ),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'Metrics',
                      subtitle: 'Select which pools contribute to liquid net calculation (liabilites excluded)',
                      children: _pools.keys.map((poolKey) {
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(poolKey.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                          value: _liquidNetPools[poolKey] ?? true,
                          onChanged: (val) async {
                            final included = val ?? true;
                            setState(() {
                              _liquidNetPools[poolKey] = included;
                            });
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('set_liquidNet_pool_$poolKey', included);
                            widget.onSaveLiquidNetPools(_liquidNetPools);
                          },
                        );
                      }).toList(),
                    ),
                    _buildSubSectionCard(
                      title: 'Future Metrics',
                      subtitle: 'Select which pools update future metrics',
                      children: [
                        ..._pools.keys.map((poolKey) {
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(poolKey.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                            value: _prognosisPools[poolKey] ?? false,
                            onChanged: (val) {
                              setState(() {
                                _prognosisPools[poolKey] = val ?? false;
                              });
                              widget.onSavePrognosisPools(_prognosisPools);
                            },
                          );
                        }),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'Liabilities',
                      subtitle: 'Edit remaining balances, installments, interest rates, due dates, and projection end dates',
                      children: [
                        Text(
                          'Active Liabilities & Loans',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _liabilitiesList.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'No liabilities configured yet.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _liabilitiesList.length,
                                itemBuilder: (context, index) {
                                  final item = _liabilitiesList[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      item.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Balance: €${item.remainingBalance.toStringAsFixed(2)} | Inst: €${item.monthlyInstallment.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF64748B),
                                      ),
                                      onPressed: () => _showEditLiabilityDialog(item),
                                      tooltip: 'Edit Liability Parameters & Reproject',
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'Savings Goals',
                      subtitle: 'Edit target amounts, names, and assigned owners for active savings goals',
                      children: [
                        Text(
                          'Active Savings Goals',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _savingsGoalsList.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'No savings goals configured yet.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _savingsGoalsList.length,
                                itemBuilder: (context, index) {
                                  final goal = _savingsGoalsList[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      goal.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Target: €${goal.targetAmount.toStringAsFixed(2)} | Saved: €${goal.currentAmount.toStringAsFixed(2)} (${goal.owner})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit,
                                            size: 16,
                                            color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF64748B),
                                          ),
                                          onPressed: () => _showEditSavingsGoalDialog(goal),
                                          tooltip: 'Edit Savings Goal',
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            size: 16,
                                            color: _isZaznamityMode ? const Color(0xFFEF4444) : const Color(0xFFDC2626),
                                          ),
                                          onPressed: () async {
                                            if (goal.id != null) {
                                              await DatabaseHelper.instance.deleteSavingsGoal(goal.id!);
                                              await _loadSavingsGoals();
                                              if (widget.onLiabilityUpdated != null) {
                                                widget.onLiabilityUpdated!();
                                              }
                                            }
                                          },
                                          tooltip: 'Delete Savings Goal',
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'Budgets',
                      subtitle: 'Edit target amounts, limits, and assigned owners for active budgets',
                      children: [
                        Text(
                          'Active Budgets',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: DatabaseHelper.instance.getBudgets(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'No budgets configured yet.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              );
                            }
                            final budgetsList = snapshot.data!;
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: budgetsList.length,
                              itemBuilder: (context, index) {
                                final b = budgetsList[index];
                                final budgetId = b['id'] as int;
                                final labelId = b['label_id'] ?? b['labelId'];
                                double limitAmount = ((b['limit_amount'] ?? b['limitAmount'] ?? 0) as num).toDouble();
                                String owner = b['owner'] ?? (_owners.isNotEmpty ? _owners.first : 'Shared');
                                String currency = b['currency'] ?? _primaryCurrency;

                                final labelObj = widget.labels.firstWhere(
                                  (l) => l.id == labelId,
                                  orElse: () => LabelModel(id: -1, name: b['label_name'] ?? 'General', color: '582F95'),
                                );

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    labelObj.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Limit: $currency ${limitAmount.toStringAsFixed(2)} ($owner)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          size: 16,
                                          color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                                        ),
                                        onPressed: () => _showEditSingleBudgetDialog(b, () => setState(() {})),
                                        tooltip: 'Edit Budget',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          size: 16,
                                          color: _isZaznamityMode ? const Color(0xFFEF4444) : const Color(0xFFDC2626),
                                        ),
                                        onPressed: () async {
                                          await DatabaseHelper.instance.deleteBudget(budgetId);
                                          setState(() {});
                                          if (widget.onLiabilityUpdated != null) {
                                            widget.onLiabilityUpdated!();
                                          }
                                        },
                                        tooltip: 'Delete Budget',
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Enable Budget Rollover', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                          subtitle: Text('Rollover unspent budget amounts to the next period', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                          value: _budgetRolloverEnabled,
                          onChanged: (val) async {
                            setState(() => _budgetRolloverEnabled = val);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('set_budget_rollover', val);
                          },
                        ),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'Transfers & Analytics',
                      subtitle: 'Configure how internal pool-to-pool transfers affect insights',
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Exclude Transfers from Insights & Analytics', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                          subtitle: Text('Prevents internal transfers from skewing spending drivers and category charts', style: TextStyle(fontSize: 10, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                          value: _excludeTransfersFromInsights,
                          onChanged: (val) async {
                            setState(() => _excludeTransfersFromInsights = val);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('exclude_transfers_insights', val);
                          },
                        ),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'Liquid Trend',
                      subtitle: 'Toggle visibility of Future Zaznams in chart',
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Show Future Zaznams in Chart', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                          value: _liquidTrendShowFuture,
                          onChanged: (val) async {
                            setState(() => _liquidTrendShowFuture = val);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('set_liquidTrend_show_future', val);
                          },
                        ),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'Pools Trends',
                      subtitle: 'Toggle Future Zaznams and individual pool visibility',
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Show Future Zaznams in Chart', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                          value: _poolsTrendsShowFuture,
                          onChanged: (val) async {
                            setState(() => _poolsTrendsShowFuture = val);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('set_poolsTrends_show_future', val);
                          },
                        ),
                        const SizedBox(height: 12),
                        Text('Individual Pool Visibility in Trends', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                        const SizedBox(height: 4),
                        ..._pools.keys.map((poolKey) {
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(poolKey.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                            value: _poolsTrendsVisibility[poolKey] ?? true,
                            onChanged: (val) async {
                              final visible = val ?? true;
                              setState(() {
                                _poolsTrendsVisibility[poolKey] = visible;
                              });
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('set_poolsTrends_pool_visible_$poolKey', visible);
                            },
                          );
                        }),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'Calendar',
                      subtitle: 'Start the week with Sunday or Monday',
                      children: [
                        Text('Start week with:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _calendarStartDay,
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                          items: [
                            DropdownMenuItem(value: 'Monday', child: Text('Monday', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))),
                            DropdownMenuItem(value: 'Sunday', child: Text('Sunday', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))),
                          ],
                          onChanged: (val) async {
                            if (val != null) {
                              setState(() => _calendarStartDay = val);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('calendarStartDay', val);
                            }
                          },
                        ),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'All Zaznams',
                      subtitle: 'Configure compact All Zaznams display view and quick toggle on and off in All Zaznams card',
                      children: [
                        HistoryDisplaySettingsWidget(
                          isZaznamityMode: _isZaznamityMode,
                          onPrefsChanged: () {
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                // ==========================================
                // GROUP 3: ORGANIZATION & STRUCTURE
                // ==========================================
                _buildMainCategoryGroup(
                  title: 'Organization & Structure',
                  subtitle: 'Manage Currencies, Labels, Owners and Pools',
                  children: [

                    _buildSubSectionCard(
                      title: 'Currency Preferences',
                      subtitle: 'Set 1 primary and up to 3 secondary currencies for multi-currency tracking',
                      children: [
                        Text('Primary Currency (required)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _primaryCurrency,
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                          items: _availableCurrencies
                              .where((c) => c['code'] != _secondaryCurrency1 && c['code'] != _secondaryCurrency2 && c['code'] != _secondaryCurrency3)
                              .map((c) => DropdownMenuItem(value: c['code'], child: Text(c['name']!, style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))))
                              .toList(),
                          onChanged: (val) async {
                            if (val != null) {
                              setState(() => _primaryCurrency = val);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('primaryCurrency', val);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Text('Second Currency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String?>(
                          initialValue: _secondaryCurrency1,
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                          items: [
                            DropdownMenuItem<String?>(value: null, child: Text('None (Disabled)', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))),
                            ..._availableCurrencies
                                .where((c) => c['code'] != _primaryCurrency && c['code'] != _secondaryCurrency2 && c['code'] != _secondaryCurrency3)
                                .map((c) => DropdownMenuItem<String?>(value: c['code'], child: Text(c['name']!, style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))))),
                          ],
                          onChanged: (val) async {
                            setState(() => _secondaryCurrency1 = val);
                            final prefs = await SharedPreferences.getInstance();
                            if (val == null) {
                              await prefs.remove('secondaryCurrency1');
                            } else {
                              await prefs.setString('secondaryCurrency1', val);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Text('Third Currency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String?>(
                          initialValue: _secondaryCurrency2,
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                          items: [
                            DropdownMenuItem<String?>(value: null, child: Text('None (Disabled)', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))),
                            ..._availableCurrencies
                                .where((c) => c['code'] != _primaryCurrency && c['code'] != _secondaryCurrency1 && c['code'] != _secondaryCurrency3)
                                .map((c) => DropdownMenuItem<String?>(value: c['code'], child: Text(c['name']!, style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))))),
                          ],
                          onChanged: (val) async {
                            setState(() => _secondaryCurrency2 = val);
                            final prefs = await SharedPreferences.getInstance();
                            if (val == null) {
                              await prefs.remove('secondaryCurrency2');
                            } else {
                              await prefs.setString('secondaryCurrency2', val);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Text('Fourth Currency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String?>(
                          initialValue: _secondaryCurrency3,
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                          items: [
                            DropdownMenuItem<String?>(value: null, child: Text('None (Disabled)', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))),
                            ..._availableCurrencies
                                .where((c) => c['code'] != _primaryCurrency && c['code'] != _secondaryCurrency1 && c['code'] != _secondaryCurrency2)
                                .map((c) => DropdownMenuItem<String?>(value: c['code'], child: Text(c['name']!, style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))))),
                          ],
                          onChanged: (val) async {
                            setState(() => _secondaryCurrency3 = val);
                            final prefs = await SharedPreferences.getInstance();
                            if (val == null) {
                              await prefs.remove('secondaryCurrency3');
                            } else {
                              await prefs.setString('secondaryCurrency3', val);
                            }
                          },
                        ),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'Labels Management',
                      subtitle: 'Create, edit color palettes, delete, bulk reassign, and configure Fixed vs Discretionary Labels',
                      children: [
                        Text('Add & Manage Individual Labels', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newLabelController,
                                style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
                                decoration: const InputDecoration(
                                  hintText: 'New label name...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95)),
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
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: widget.labels.length,
                            itemBuilder: (context, index) {
                              final label = widget.labels[index];
                              final labelColor = _parseColor(label.color);
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: labelColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                title: Text(label.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.palette_outlined, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                      tooltip: 'Change Color Palette',
                                      onPressed: () => _editLabelDialog(label),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit, size: 16, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                      tooltip: 'Edit Label Name',
                                      onPressed: () => _editLabelDialog(label),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, size: 16, color: _isZaznamityMode ? const Color(0xFFEF4444) : const Color(0xFFDC2626)),
                                      onPressed: () => widget.onDeleteLabel(label.id),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Divider(height: 24, color: _isZaznamityMode ? Colors.white24 : const Color(0xFFE2E8F0)),
                        Text('Fixed vs Discretionary Labels Mapping', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                        const SizedBox(height: 4),
                        Text('Check labels that should be categorized as Fixed expenses (unchecked are Discretionary):', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                        const SizedBox(height: 8),
                        widget.labels.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('No labels available.', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                              )
                            : ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: widget.labels.length,
                                  itemBuilder: (context, index) {
                                    final label = widget.labels[index];
                                    final isFixed = _multiLabelFixedCategories[label.name] ?? false;
                                    return CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: Text(label.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                                      subtitle: Text(isFixed ? 'Fixed Expense' : 'Discretionary Expense', style: TextStyle(fontSize: 10, color: isFixed ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)) : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)))),
                                      value: isFixed,
                                      onChanged: (val) async {
                                        final newVal = val ?? false;
                                        setState(() {
                                          _multiLabelFixedCategories[label.name] = newVal;
                                        });
                                        final prefs = await SharedPreferences.getInstance();
                                        await prefs.setBool('set_multilabel_fixed_${label.name}', newVal);
                                      },
                                    );
                                  },
                                ),
                              ),
                        Divider(height: 24, color: _isZaznamityMode ? Colors.white24 : const Color(0xFFE2E8F0)),
                        Text('Bulk Edit Zaznam Labels', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                        const SizedBox(height: 4),
                        Text(
                          'Reassign all existing Zaznams from one label to another in batch',
                          style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _showBulkEditLabelDialog,
                            icon: const Icon(Icons.edit_note, size: 18),
                            label: const Text('Bulk Edit Labels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Bulk Move Zaznams by label (Label → Pool)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                        const SizedBox(height: 4),
                        Text(
                          'Move all Zaznams for a specific owner and label into a target pool in batch',
                          style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _showBulkMoveLabelToPoolDialog,
                            icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                            label: const Text('Bulk Move Label to Pool', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'Owner Management',
                      subtitle: 'Manage local Zaznamity Owners',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Open Owner Management', style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155))),
                          trailing: Icon(Icons.arrow_forward_ios, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : null),
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
                      subtitle: 'Manage financial Pools',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Open Pool Manager', style: TextStyle(fontSize: 13, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155))),
                          trailing: Icon(Icons.arrow_forward_ios, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : null),
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
                  ],
                ),

                // ==========================================
                // GROUP 4: SECURITY & NOTIFICATIONS
                // ==========================================
                _buildMainCategoryGroup(
                  title: 'Security & Notifications',
                  subtitle: 'App security lock and reminder schedules',
                  children: [
                    _buildSubSectionCard(
                      title: 'Security',
                      subtitle: 'Secure app with a 4-digit Passcode',
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Enable Security Lock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
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
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _pinController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  obscureText: !_isPinVisible,
                                  style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 13),
                                  decoration: const InputDecoration(
                                    labelText: 'Set 4-Digit Passcode',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                                    isDense: true,
                                    counterText: '',
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
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                                  foregroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPinVisible = !_isPinVisible;
                                  });
                                },
                                icon: Icon(
                                  _isPinVisible ? Icons.visibility_off : Icons.visibility,
                                  size: 16,
                                ),
                                label: Text(
                                  _isPinVisible ? 'Hide ' : 'Show',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
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
                          title: Text('Enable Reminders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
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
                              Text('Days before: ', style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                              DropdownButton<int>(
                                value: _notifyDaysBefore,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 12),
                                items: [0, 1, 2, 3, 5, 7].map((d) => DropdownMenuItem(value: d, child: Text('$d day(s)'))).toList(),
                                onChanged: (val) {},
                              ),
                              const SizedBox(width: 20),
                              Text('Hours: ', style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                              DropdownButton<int>(
                                value: _notifyHoursBefore,
                                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 12),
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
                // GROUP 5: System Tools (With Delete Manager)
                // ==========================================
                _buildMainCategoryGroup(
                  title: 'System Tools',
                  subtitle: 'Zaznamity Reports, Delete Manager, Data Export & Backup, CSV Imports, and About',
                  children: [
                    _buildSubSectionCard(
                      title: 'Zaznamity Reports',
                      subtitle: 'Generate PDF reports and manage created reports',
                      children: [
                        Text(
                          'Generate flexible customized PDF reports with custom date ranges, filters (owners, pools, labels, currencies), custom card metrics, chart selections, and full Zaznams history lists.\n\n'
                          'Previously generated PDF Zaznamity Reports are logged below and can be opened or deleted directly.',
                          style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _showReportConfigModal,
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text('Configure Zaznamity Report', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Created Zaznamity Reports',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                        ),
                        const SizedBox(height: 4),
                        _savedReportsList.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('No saved reports found in local storage.', style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                              )
                            : ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 180),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _savedReportsList.length,
                                  itemBuilder: (context, index) {
                                    final file = _savedReportsList[index];
                                    final fileName = file.uri.pathSegments.last;
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      leading: Icon(Icons.description, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                      title: Text(fileName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 24)),
                                            onPressed: () => _openReportFile(file),
                                            child: Text('Open', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                            tooltip: 'Delete report',
                                            onPressed: () => _deleteReportFile(file),
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
                      title: 'Delete Manager',
                      subtitle: 'Manage deletion of labels, owners, pools, zaznams, or full data wipe',
                      children: [
                        Text(
                          'Centralized Delete Manager to safely remove all labels, owners, pools, zaznams, or perform a complete phone data wipe in one streamlined tool.',
                          style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), height: 1.4),
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
                            onPressed: _showDeleteManagerDialog,
                            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                            label: const Text('Open Delete Manager', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'Data Export / Backup',
                      subtitle: 'One-click export of Zaznams or complete system backups',
                      children: [
                        Text(
                          'Securely export your data for backups or to migrate between devices. Export All Zaznams history to CSV or JSON, or Export a Full System Backup (All Zaznams, Liabilities, Goals, Settings & Saved Preferences))',
                          style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Export All Zaznams only (ledger history)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _showExportPreviewDialog('csv'),
                                icon: const Icon(Icons.table_chart, size: 16),
                                label: const Text('Export CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _showExportPreviewDialog('json'),
                                icon: const Icon(Icons.code, size: 16),
                                label: const Text('Export JSON', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Export Full Zaznamity Backup',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95)),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _exportFullSystemBackup,
                            icon: const Icon(Icons.backup, size: 16),
                            label: const Text('Full System Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Created Exports / Backups',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95)),
                        ),
                        const SizedBox(height: 4),
                        _savedExportsList.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'No saved backups found in local storage.',
                                  style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                ),
                              )
                            : ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 180),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _savedExportsList.length,
                                  itemBuilder: (context, index) {
                                    final file = _savedExportsList[index];
                                    final fileName = file.uri.pathSegments.last;
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      leading: Icon(
                                        fileName.endsWith('.csv') ? Icons.table_view : Icons.data_object,
                                        size: 16,
                                        color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                                      ),
                                      title: Text(
                                        fileName,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 24)),
                                            onPressed: () => _openReportFile(file),
                                            child: Text('Open', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                            tooltip: 'Delete export',
                                            onPressed: () => _deleteReportFile(file),
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
                      title: 'CSV Import Mapper',
                      subtitle: 'Select, map, and import your CSV data',
                      children: [
                        Text(
                          'Upload any CSV file, match your columns to Zaznamity fields, choose to create labels, owners and pools, and detect future zaznams.\n\n'
                          'This feature is designed to help you import your financial data from other sources into Zaznamity with ease and efficiency.\n\n'
                          'INSTRUCTIONS : Before importing your data, please select in "Currency Preferences" your Primary Currency. Then proceed to importing your data.\n\n'
                          'After importing, please allow some time for data parsing - more Zaznams imported require more time to parse data.\n\n' 
                          'If you encounter a label or pool discrepency in your imported data, reassign errors with bulk actions in settings.',
                          style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95),
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
                            icon: const Icon(Icons.alt_route, size: 16),
                            label: const Text('CSV Import Mapper', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    _buildSubSectionCard(
                      title: 'About Zaznamity',
                      subtitle: 'App version, credits, and details',
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Welcome to Zaznamity v 1.0.0!\n\n'
                            '"Zaznam" in Slovak means record or transaction. Keep track of all your Zaznams and keep them secure on your phone — no cloud, no subscriptions.\n\n'
                            'Local-first (SQLite): Full privacy and ownership. Your financial data stays entirely on your device.\n\n'
                            'Features of this app:\n',
                            style: TextStyle(fontSize: 12, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
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
        color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        iconColor: _isZaznamityMode ? const Color(0xFFA855F7) : null,
        collapsedIconColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : null,
        title: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
            letterSpacing: 1.0,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
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
        color: _isZaznamityMode ? const Color(0xFF160D25) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        iconColor: _isZaznamityMode ? const Color(0xFFA855F7) : null,
        collapsedIconColor: _isZaznamityMode ? const Color(0xFFC4B5FD) : null,
        title: Text(
          title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
        ),
        children: children,
      ),
    );
  }
}