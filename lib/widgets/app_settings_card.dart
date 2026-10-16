// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:zaznamity/models/card_config.dart';
import 'package:zaznamity/models/label.dart';
import 'package:zaznamity/models/transaction_model.dart';
import 'package:zaznamity/services/database_helper.dart';
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
  bool _isPinVisible = false;

  String _primaryCurrency = 'USD';
  String? _secondaryCurrency1;
  String? _secondaryCurrency2;
  String? _secondaryCurrency3;

  String _calendarStartDay = 'Monday';
  String _defaultOpenCard = 'history';

  // Title Card configuration state variables
  bool _titleCardShowMessage = true;
  final TextEditingController _titleCardMessageController = TextEditingController();

  // Card-specific settings state variables (Non-date range parameters)
  final Map<String, bool> _multiLabelFixedCategories = {};

  bool _liquidTrendShowFuture = false;
  bool _poolsTrendsShowOnlyFunded = false;
  bool _poolsTrendsShowFuture = false;
  final Map<String, bool> _poolsTrendsVisibility = {};

  bool _budgetRolloverEnabled = false;

  List<File> _savedReportsList = [];

  final List<Map<String, String>> _availableCurrencies = [
    {'code': 'USD', 'name': '🇺🇸 US Dollar (\$)'},
    {'code': 'EUR', 'name': '🇪🇺 Euro (€)'},
    {'code': 'JPY', 'name': '🇯🇵 Japanese Yen (¥)'},
    {'code': 'GBP', 'name': '🇬🇧 British Pound (£)'},
    {'code': 'CNY', 'name': '🇨🇳 Chinese Yuan (¥)'},
    {'code': 'AUD', 'name': '🇦🇺 Australian Dollar (A\$)'},
    {'code': 'CAD', 'name': '🇨🇦 Canadian Dollar (C\$)'},
    {'code': 'CHF', 'name': '🇨🇭 Swiss Franc (CHF)'},
    {'code': 'HKD', 'name': '🇭🇰 Hong Kong Dollar (HK\$)'},
    {'code': 'SGD', 'name': '🇸🇬 Singapore Dollar (S\$)'},
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
  }

  @override
  void dispose() {
    _titleCardMessageController.dispose();
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
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
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
      _defaultOpenCard = prefs.getString('defaultOpenCard') ?? 'history';

      // Load Title Card preferences
      _titleCardShowMessage = prefs.getBool('titleCardShowMessage') ?? true;
      final savedMsg = prefs.getString('titleCardCustomMessage');
      if (savedMsg != null && savedMsg.isNotEmpty) {
        _titleCardMessageController.text = savedMsg;
      } else {
        _titleCardMessageController.text = _owners.isNotEmpty ? _owners.first : 'Mathias';
      }

      for (var label in widget.labels) {
        _multiLabelFixedCategories[label.name] = prefs.getBool('set_multilabel_fixed_${label.name}') ?? false;
      }

      for (var poolKey in _pools.keys) {
        _poolsTrendsVisibility[poolKey] = prefs.getBool('set_poolsTrends_pool_visible_$poolKey') ?? true;
        _liquidNetPools[poolKey] = prefs.getBool('set_liquidNet_pool_$poolKey') ?? true;
      }

      _liquidTrendShowFuture = prefs.getBool('set_liquidTrend_show_future') ?? false;
      _poolsTrendsShowOnlyFunded = prefs.getBool('set_poolsTrends_funded_only') ?? false;
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

  Future<void> _loadSavedReports() async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null && await directory.exists()) {
        final files = directory.listSync();
        final pdfFiles = files
            .where((entity) => entity is File && entity.path.toLowerCase().endsWith('.pdf') && entity.path.contains('ZaznamityReport'))
            .map((entity) => entity as File)
            .toList();
        
        pdfFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

        setState(() {
          _savedReportsList = pdfFiles;
        });
      }
    } catch (_) {}
  }

  Future<void> _openReportFile(File file) async {
    try {
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${result.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening report: $e')),
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
        const SnackBar(content: Text('Report log deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting report file: $e')),
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
        child: Text(entry.value, style: const TextStyle(fontSize: 13)),
      );
    }).toList();
  }

  void _editLabelDialog(LabelModel label) {
    final controller = TextEditingController(text: label.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Label', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          title: const Text('Configure Budgets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
          content: SizedBox(
            width: 450,
            child: budgets.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No budgets configured yet. Create budgets in the Budgets card.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B)))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: budgets.length,
                    itemBuilder: (context, index) {
                      final b = budgets[index];
                      final budgetId = b['id'] as int;
                      final labelId = b['label_id'] ?? b['labelId'];
                      double limitAmount = ((b['limit_amount'] ?? b['limitAmount'] ?? 0) as num).toDouble();
                      String owner = b['owner'] ?? _owners.firstOrNull ?? 'Shared';
                      String currency = b['currency'] ?? _primaryCurrency;

                      final labelObj = widget.labels.firstWhere(
                        (l) => l.id == labelId,
                        orElse: () => LabelModel(id: -1, name: b['label_name'] ?? 'General', color: '582F95'),
                      );

                      final limitController = TextEditingController(text: limitAmount.toStringAsFixed(0));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(labelObj.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                  onPressed: () async {
                                    await DatabaseHelper.instance.deleteBudget(budgetId);
                                    final updated = await DatabaseHelper.instance.getBudgets();
                                    setDialogState(() => budgets = updated);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: limitController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Amount Limit', isDense: true, border: OutlineInputBorder()),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val);
                                      if (parsed != null) {
                                        b['limit_amount'] = parsed;
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _owners.contains(owner) ? owner : (_owners.isNotEmpty ? _owners.first : owner),
                                    decoration: const InputDecoration(labelText: 'Owner', isDense: true, border: OutlineInputBorder()),
                                    items: _owners.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12)))).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() => owner = val);
                                        b['owner'] = val;
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: [_primaryCurrency, if (_secondaryCurrency1 != null) _secondaryCurrency1!, if (_secondaryCurrency2 != null) _secondaryCurrency2!].contains(currency) ? currency : _primaryCurrency,
                                    decoration: const InputDecoration(labelText: 'Currency', isDense: true, border: OutlineInputBorder()),
                                    items: [
                                      _primaryCurrency,
                                      if (_secondaryCurrency1 != null) _secondaryCurrency1!,
                                      if (_secondaryCurrency2 != null) _secondaryCurrency2!,
                                      if (_secondaryCurrency3 != null) _secondaryCurrency3!,
                                    ].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() => currency = val);
                                        b['currency'] = val;
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                                onPressed: () async {
                                  final finalLimit = double.tryParse(limitController.text) ?? limitAmount;
                                  await DatabaseHelper.instance.updateBudget(budgetId, finalLimit);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget updated successfully')));
                                  }
                                },
                                child: const Text('Save Changes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF582F95), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
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
          title: const Text('Configure Zaznamity Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. SELECT CUSTOM DATE RANGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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

                  const Text('2. FLEXIBLE DRILL-DOWN FILTERS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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

                  const Text('3. CARD PARAMETERS & METRICS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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

                  const Text('4. CHART VISUALIZATIONS (Checkmark Select)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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

                  const Text('5. DATA GROUPING & HISTORY TABLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF582F95), foregroundColor: Colors.white),
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
                          childrenWidgets.add(pw.Text('• Summary Metrics & Assets Overview', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))));
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
                                    pw.Text('Net Balance: \$${netBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF582F95))),
                                  ],
                                ),
                              ],
                            ),
                          ));
                          childrenWidgets.add(pw.SizedBox(height: 14));
                        }

                        if (includeFutureMetricsCard) {
                          childrenWidgets.add(pw.Text('• Future Metrics & Scheduled Flow', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))));
                          childrenWidgets.add(pw.SizedBox(height: 6));
                          childrenWidgets.add(pw.Container(height: 25, alignment: pw.Alignment.centerLeft, child: pw.Text('[Future metrics parameters and prognosis included]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))));
                          childrenWidgets.add(pw.SizedBox(height: 14));
                        }

                        if (includeSavingsGoalsCard || includeBudgetCard) {
                          childrenWidgets.add(pw.Text('• Savings Goals & Budget Status', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))));
                          childrenWidgets.add(pw.SizedBox(height: 6));
                          childrenWidgets.add(pw.Container(height: 25, alignment: pw.Alignment.centerLeft, child: pw.Text('[Goals and budget parameters included]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))));
                          childrenWidgets.add(pw.SizedBox(height: 14));
                        }

                        if (includeBarChart) {
                          childrenWidgets.add(pw.Text('• Visual Chart: Bar Chart', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))));
                          childrenWidgets.add(pw.SizedBox(height: 4));
                          childrenWidgets.add(pw.Container(height: 45, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)), child: pw.Text('[Bar Chart Rendering]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))));
                          childrenWidgets.add(pw.SizedBox(height: 10));
                        }

                        if (includePieChart) {
                          childrenWidgets.add(pw.Text('• Visual Chart: Pie Chart', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))));
                          childrenWidgets.add(pw.SizedBox(height: 4));
                          childrenWidgets.add(pw.Container(height: 45, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)), child: pw.Text('[Pie Chart Rendering]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))));
                          childrenWidgets.add(pw.SizedBox(height: 10));
                        }

                        if (includeLineChart) {
                          childrenWidgets.add(pw.Text('• Visual Chart: Liquid Trend', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))));
                          childrenWidgets.add(pw.SizedBox(height: 4));
                          childrenWidgets.add(pw.Container(height: 45, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)), child: pw.Text('[Line Chart Rendering]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))));
                          childrenWidgets.add(pw.SizedBox(height: 10));
                        }

                        if (includeTransactionTableHistory) {
                          childrenWidgets.add(pw.SizedBox(height: 6));
                          childrenWidgets.add(pw.Text('• All Zaznams (${filteredTxs.length})', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))));
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
                    SnackBar(content: Text('Report saved to Downloads & Log: $fileName (${filteredTxs.length} transactions included)')),
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
                subtitle: 'Theme preferences, app launch card, and navigation layout',
                children: [
                  _buildSubSectionCard(
                    title: 'On App Open',
                    subtitle: 'Choose which card is displayed by default upon launching the app',
                    children: [
                      const Text('Default Landing Card', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _buildNavDropdownItems().any((item) => item.value == _defaultOpenCard) ? _defaultOpenCard : 'history',
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                        items: _buildNavDropdownItems(),
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() => _defaultOpenCard = val);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('defaultOpenCard', val);
                          }
                        },
                      ),
                    ],
                  ),
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
              // GROUP 2: CARDS SETTINGS
              // ==========================================
              _buildMainCategoryGroup(
                title: 'Cards Settings',
                subtitle: 'Configure default behaviors, parameters, and filters for each dashboard card',
                children: [
                  _buildSubSectionCard(
                    title: 'Title Card',
                    subtitle: 'Dashboard header badge & personal greeting message',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show Personal Message / Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Display your custom greeting or name badge on the dashboard title card', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        value: _titleCardShowMessage,
                        onChanged: (val) async {
                          setState(() => _titleCardShowMessage = val);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('titleCardShowMessage', val);
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Custom Message / Display Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _titleCardMessageController,
                              decoration: const InputDecoration(
                                hintText: 'Enter name or message (e.g. Mathias)...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                                isDense: true,
                              ),
                              onChanged: (val) async {
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('titleCardCustomMessage', val.trim());
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF582F95),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('titleCardCustomMessage', _titleCardMessageController.text.trim());
                              await prefs.setBool('titleCardShowMessage', _titleCardShowMessage);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Title card settings saved successfully!')),
                                );
                              }
                            },
                            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildSubSectionCard(
                    title: 'All Zaznams',
                    subtitle: 'Data management & bulk operations',
                    children: [
                      const Text('Zaznams Management - DANGER ZONE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                      const SizedBox(height: 4),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                        onPressed: _showBulkDeleteDialog,
                        icon: const Icon(Icons.delete_sweep, size: 16),
                        label: const Text('Delete Zaznams Configurator (Bulk)', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  _buildSubSectionCard(
                    title: 'Multi-Label Analytics',
                    subtitle: 'Fixed vs discretionary category mappings',
                    children: [
                      const Text('Fixed vs Discretionary Labels Configuration', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                      const SizedBox(height: 4),
                      const Text('Check labels that should be categorized as Fixed expenses (unchecked are Discretionary):', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(height: 8),
                      widget.labels.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('No labels available. Add labels in the Organization group.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
                                    title: Text(label.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    subtitle: Text(isFixed ? 'Fixed Expense' : 'Discretionary Expense', style: TextStyle(fontSize: 10, color: isFixed ? const Color(0xFF582F95) : const Color(0xFF64748B))),
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
                    ],
                  ),
                  _buildSubSectionCard(
                    title: 'Calendar',
                    subtitle: 'Start day of the week',
                    children: [
                      const Text('Start Day', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _calendarStartDay,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                        items: const [
                          DropdownMenuItem(value: 'Monday', child: Text('Monday')),
                          DropdownMenuItem(value: 'Sunday', child: Text('Sunday')),
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
                    title: 'Liquid Trend',
                    subtitle: 'Future zaznams visibility',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show Future Zaznams in Chart', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                    subtitle: 'Funded pools filter, future zaznams, and individual pool visibility',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show Only Pools with Funds', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        value: _poolsTrendsShowOnlyFunded,
                        onChanged: (val) async {
                          setState(() => _poolsTrendsShowOnlyFunded = val);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('set_poolsTrends_funded_only', val);
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Show Future Zaznams in Chart', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        value: _poolsTrendsShowFuture,
                        onChanged: (val) async {
                          setState(() => _poolsTrendsShowFuture = val);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('set_poolsTrends_show_future', val);
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Pool Visibility in Trends', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                      const SizedBox(height: 4),
                      ..._pools.keys.map((poolKey) {
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(poolKey.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
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
                    title: 'Metrics',
                    subtitle: 'Select which pools contribute to liquid net calculation',
                    children: _pools.keys.map((poolKey) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(poolKey.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
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
                    subtitle: 'Selector for pools updating future metrics',
                    children: [
                      const Text('Prognosis Counting Pools', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                      const SizedBox(height: 4),
                      const Text('Configure which pools update future metrics/prognosis:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(height: 8),
                      ..._pools.keys.map((poolKey) {
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
                      }),
                    ],
                  ),
                  _buildSubSectionCard(
                    title: 'Budgets',
                    subtitle: 'Budget configurator and rollover preferences',
                    children: [
                      const Text('Configure Existing Budgets', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF582F95),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _showConfigureBudgetsDialog,
                          icon: const Icon(Icons.tune, size: 16),
                          label: const Text('Configure Budgets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Budget Rollover', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Rollover unspent budget amounts to the next period', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        value: _budgetRolloverEnabled,
                        onChanged: (val) async {
                          setState(() => _budgetRolloverEnabled = val);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('set_budget_rollover', val);
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
                subtitle: 'Labels, owners, pools, and currencies',
                children: [
                  _buildSubSectionCard(
                    title: 'Currency Preferences',
                    subtitle: 'Set 1 primary currency and up to 3 secondary currencies for multi-currency tracking',
                    children: [
                      const Text('Primary Currency (1 required)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _primaryCurrency,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                        items: _availableCurrencies
                            .where((c) => c['code'] != _secondaryCurrency1 && c['code'] != _secondaryCurrency2 && c['code'] != _secondaryCurrency3)
                            .map((c) => DropdownMenuItem(value: c['code'], child: Text(c['name']!)))
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
                      const Text('Second Currency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String?>(
                        initialValue: _secondaryCurrency1,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('None (Disabled)')),
                          ..._availableCurrencies
                              .where((c) => c['code'] != _primaryCurrency && c['code'] != _secondaryCurrency2 && c['code'] != _secondaryCurrency3)
                              .map((c) => DropdownMenuItem<String?>(value: c['code'], child: Text(c['name']!))),
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
                      const Text('Third Currency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String?>(
                        initialValue: _secondaryCurrency2,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('None (Disabled)')),
                          ..._availableCurrencies
                              .where((c) => c['code'] != _primaryCurrency && c['code'] != _secondaryCurrency1 && c['code'] != _secondaryCurrency3)
                              .map((c) => DropdownMenuItem<String?>(value: c['code'], child: Text(c['name']!))),
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
                      const Text('Fourth Currency', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String?>(
                        initialValue: _secondaryCurrency3,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('None (Disabled)')),
                          ..._availableCurrencies
                              .where((c) => c['code'] != _primaryCurrency && c['code'] != _secondaryCurrency1 && c['code'] != _secondaryCurrency2)
                              .map((c) => DropdownMenuItem<String?>(value: c['code'], child: Text(c['name']!))),
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
                    subtitle: 'Create, edit, delete labels, and bulk reassign Zaznam labels',
                    children: [
                      const Text('Add & Manage Individual Labels', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                      const SizedBox(height: 6),
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
                        constraints: const BoxConstraints(maxHeight: 180),
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
                      const Divider(height: 24, color: Color(0xFFE2E8F0)),
                      const Text('Bulk Edit Zaznam Labels', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                      const SizedBox(height: 4),
                      const Text(
                        'Reassign all existing Zaznams from one label to another in batch',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 88, 47, 149),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _showBulkEditLabelDialog,
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: const Text('Bulk Edit Labels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                    title: 'Security & App Lock',
                    subtitle: 'Secure app with PIN, Face ID, or Touch ID',
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
                        DropdownButtonFormField<String>(
                          initialValue: ['PIN', 'Face ID', 'Touch ID'].contains(_biometricType) ? _biometricType : 'PIN',
                          decoration: const InputDecoration(labelText: 'Authentication Method', isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'PIN', child: Text('4-Digit PIN Code')),
                            DropdownMenuItem(value: 'Face ID', child: Text('Face ID (Biometrics)')),
                            DropdownMenuItem(value: 'Touch ID', child: Text('Touch ID / Fingerprint')),
                          ],
                          onChanged: (val) async {
                            if (val != null) {
                              setState(() => _biometricType = val);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('biometricType', val);
                            }
                          },
                        ),
                        if (_biometricType == 'PIN') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _pinController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  obscureText: !_isPinVisible,
                                  decoration: const InputDecoration(
                                    labelText: 'Set 4-Digit PIN',
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
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  foregroundColor: const Color(0xFF582F95),
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
                                  _isPinVisible ? 'Hide PIN' : 'Show PIN',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
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
              // GROUP 5: DATA MANAGEMENT & SYSTEM
              // ==========================================
              _buildMainCategoryGroup(
                title: 'Data Management & System',
                subtitle: 'Reports, logs, CSV imports, and zone actions',
                children: [
                  _buildSubSectionCard(
                    title: 'Zaznamity Reports',
                    subtitle: 'Generate PDF reports and manage previous reports',
                    children: [
                      const Text(
                        'Generate flexible customized PDF reports with custom date ranges, drill-down filters (owners, pools, labels, currencies), custom card metrics, checkmark chart selections, and full transaction history lists.\n\n'
                        'Previously generated reports are logged below and can be opened or deleted directly.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                      ),
                      const SizedBox(height: 16),
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
                          label: const Text('Configure Zaznamity Report', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Created Zaznamity Reports', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
                      const SizedBox(height: 4),
                      _savedReportsList.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('No saved reports found in local storage.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
                                    leading: const Icon(Icons.description, size: 16, color: Color(0xFF582F95)),
                                    title: Text(fileName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 24)),
                                          onPressed: () => _openReportFile(file),
                                          child: const Text('Open', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF582F95))),
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
                          'Welcome to Zaznamity v 1.0.0!\n\n'
                          '"Zaznam" in Slovak means record or transaction. Keep track of all your Zaznams and keep them secure on your phone — no cloud, no subscriptions.\n\n'
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