import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaznamity/models/card_config.dart';
import 'package:zaznamity/models/label.dart';
import 'package:zaznamity/models/transaction_model.dart';
import 'package:zaznamity/models/savings_goal_model.dart';
import 'package:zaznamity/services/database_helper.dart';
import 'package:intl/intl.dart';

import '../widgets/summary_metrics_card.dart';
import '../widgets/future_metrics_card.dart';
import '../widgets/new_zaznam_card.dart';
import '../widgets/transfer_funds_card.dart';
import '../widgets/liquid_trend_chart_card.dart';
import '../widgets/savings_chart_card.dart';
import '../widgets/income_expenses_by_labels_card.dart';
import '../widgets/transaction_history_card.dart';
import '../widgets/app_settings_card.dart';
import '../widgets/bottom_card_nav_bar.dart';
import '../widgets/calendar_card.dart';
import '../widgets/budget_progress_card.dart';
import '../widgets/selected_label_focus_card.dart';
import '../widgets/transaction_search_card.dart';
import '../widgets/sankey_flow_card.dart';
import '../widgets/pools_analytics_card.dart';
import '../widgets/monthly_cashflow_trend_card.dart';
import '../widgets/savings_goals_card.dart';

class DashboardScreen extends StatefulWidget {
  final Function(bool)? onThemeChanged;
  final Function(bool, String)? onPinSettingsChanged;

  const DashboardScreen({
    super.key,
    this.onThemeChanged,
    this.onPinSettingsChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late final TabController _tabController;

  List<TransactionModel> _transactions = [];
  List<LabelModel> _labels = [];
  List<Map<String, dynamic>> _budgets = [];
  List<SavingsGoalModel> _goals = [];
  bool _isLoading = true;

  String? _globalSelectedOwner;

  double _totalLiquidNet = 0;
  Map<String, double> _totalPoolTotals = {};
  Map<String, Map<String, double>> _poolTotalsByOwner = {};
  Map<String, double> _liquidNetByOwner = {};
  Map<String, Map<String, double>> _ownerBreakdownForLiquidNet = {};
  
  Map<String, double> _futureFlowByOwner = {};
  double _totalFutureFlow = 0;
  Map<String, double> _prognosisByOwner = {};
  double _totalPrognosis = 0;

  DateTime? _historyStartDate;
  DateTime? _historyEndDate;
  int? _historySelectedLabelId;
  String? _historySelectedOwner;
  String? _historySelectedType;

  DateTime? _labelsCardStartDate;
  DateTime? _labelsCardEndDate;
  String? _labelsCardSelectedOwner;

  DateTime? _trendStartDate;
  DateTime? _trendEndDate;
  String? _trendSelectedOwner;

  DateTime? _savingsChartStartDate;
  DateTime? _savingsChartEndDate;
  String? _savingsChartSelectedOwner;

  DateTime? _futureMetricsStartDate;
  DateTime? _futureMetricsEndDate;
  String? _futureMetricsSelectedOwner;

  String? _calendarSelectedOwner;
  String? _budgetSelectedOwner;

  int? _labelFocusSelectedLabelId;
  String? _labelFocusSelectedOwner;
  DateTime? _labelFocusStartDate;
  DateTime? _labelFocusEndDate;

  DateTime? _sankeyStartDate;
  DateTime? _sankeyEndDate;
  String? _sankeySelectedOwner;
  String? _sankeySelectedPool;

  String? _monthlyTrendSelectedOwner;

  List<String> _leftNavItems = ['owner', 'metrics', 'budget'];
  List<String> _rightNavItems = ['history', 'calendar', 'snapshot'];

  Map<String, bool> _pools = {
    'checking': true,
    'cash': true,
    'savings': false,
    'loan': false,
    'goals': true,
  };

  Map<String, bool> _liquidNetPools = {
    'checking': true,
    'cash': true,
    'savings': false,
    'loan': false,
    'goals': false,
  };

  Map<String, bool> _prognosisPools = {
    'checking': true,
    'cash': false,
    'savings': false,
    'loans': false,
  };

  List<String> _owners = ['Mathias', 'Julia', 'Shared'];

  late final List<CardConfig> _cards = [
    CardConfig(id: 'settings', title: 'Zaznamity Settings', key: GlobalKey(), isVisible: false),
    CardConfig(id: 'metrics', title: 'Metrics', key: GlobalKey()),
    CardConfig(id: 'savings_goals', title: 'Savings Goals', key: GlobalKey()),
    CardConfig(id: 'future_metrics', title: 'Future Metrics', key: GlobalKey()),
    CardConfig(id: 'label_focus', title: 'Single-Label Analysis', key: GlobalKey()),
    CardConfig(id: 'income_expenses_labels', title: 'Multi-Label Analytics', key: GlobalKey()),
    CardConfig(id: 'transaction_search', title: 'Search Zaznams', key: GlobalKey()),
    CardConfig(id: 'new_entry', title: 'New Zaznam', key: GlobalKey()),
    CardConfig(id: 'transfer', title: 'Transfer Funds', key: GlobalKey()),
    CardConfig(id: 'budget', title: 'Budget', key: GlobalKey()),
    CardConfig(id: 'trend_chart', title: 'Liquid Trend', key: GlobalKey()),
    CardConfig(id: 'savings_chart', title: 'Savings Trend', key: GlobalKey()),
    CardConfig(id: 'pools_analytics', title: 'Pools Analytics', key: GlobalKey()),
    CardConfig(id: 'sankey_flow', title: 'Sankey Flow Trend', key: GlobalKey()),
    CardConfig(id: 'monthly_trend', title: 'Cashflow Trend', key: GlobalKey()),
    CardConfig(id: 'calendar', title: 'Calendar', key: GlobalKey()),
    CardConfig(id: 'history', title: 'All Zaznams', key: GlobalKey()),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    final now = DateTime.now();
    _labelsCardStartDate = DateTime(now.year, now.month, 1);
    _labelsCardEndDate = DateTime(now.year, now.month + 1, 0);

    _historyStartDate = now.subtract(const Duration(days: 15));
    _historyEndDate = now;

    _loadPreferences();
    loadData(showLoading: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final leftSaved = prefs.getStringList('leftNavItems');
      if (leftSaved != null) _leftNavItems = leftSaved;
      final rightSaved = prefs.getStringList('rightNavItems');
      if (rightSaved != null) _rightNavItems = rightSaved;
      
      final ownersSaved = prefs.getStringList('savedOwners');
      if (ownersSaved != null && ownersSaved.isNotEmpty) {
        _owners = ownersSaved;
      }

      final poolsSaved = prefs.getStringList('savedPoolKeys');
      if (poolsSaved != null && poolsSaved.isNotEmpty) {
        Map<String, bool> loadedPools = {};
        for (var p in poolsSaved) {
          loadedPools[p] = prefs.getBool('pool_active_$p') ?? true;
        }
        if (!loadedPools.containsKey('goals')) loadedPools['goals'] = true;
        _pools = loadedPools;
      }
    });
  }

  Future<void> _savePoolsPreferences(Map<String, bool> updatedPools) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pools = updatedPools;
      for (var entry in updatedPools.entries) {
        if (!_liquidNetPools.containsKey(entry.key)) {
          _liquidNetPools[entry.key] = false;
        }
        if (!_prognosisPools.containsKey(entry.key)) {
          _prognosisPools[entry.key] = false;
        }
      }
    });
    await prefs.setStringList('savedPoolKeys', updatedPools.keys.toList());
    for (var entry in updatedPools.entries) {
      await prefs.setBool('pool_active_${entry.key}', entry.value);
    }
    calculateMetrics();
  }

  void _showOwnerSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Owner (Master Filter)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people_outline, color: Color(0xFF582F95)),
              title: const Text('All Owners', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                setState(() {
                  _globalSelectedOwner = null;
                  calculateMetrics();
                });
                Navigator.pop(ctx);
              },
            ),
            const Divider(),
            ..._owners.map((owner) => ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF582F95)),
                  title: Text(owner),
                  selected: _globalSelectedOwner == owner,
                  onTap: () {
                    setState(() {
                      _globalSelectedOwner = owner;
                      calculateMetrics();
                    });
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _navigateToCard(String cardId) {
    if (cardId == 'owner') {
      _showOwnerSelectionDialog();
      return;
    }

    final cardConfig = _cards.firstWhere(
      (c) => c.id == cardId,
      orElse: () => _cards.first,
    );

    setState(() {
      cardConfig.isVisible = true;
    });

    int targetTab = 0;
    if (['metrics', 'savings_goals', 'future_metrics'].contains(cardId)) {
      targetTab = 0; // Overview Tab
    } else if (['monthly_trend', 'trend_chart', 'savings_chart', 'pools_analytics', 'sankey_flow'].contains(cardId)) {
      targetTab = 1; // Analytics Tab
    } else if (['budget', 'label_focus', 'income_expenses_labels', 'calendar'].contains(cardId)) {
      targetTab = 2; // Analysis Tab
    } else {
      targetTab = 3; // Actions & History Tab
    }

    _tabController.animateTo(
      targetTab,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = cardConfig.key.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  void showCardStackManager(
    BuildContext context,
    List<CardConfig> cards,
    Function(CardConfig) onToggleVisibility,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => StatefulBuilder(
        builder: (stateContext, setModalState) {
          final overviewCards = cards.where((c) => ['metrics', 'savings_goals', 'future_metrics'].contains(c.id)).toList();
          final analyticsCards = cards.where((c) => ['monthly_trend', 'trend_chart', 'savings_chart', 'pools_analytics', 'sankey_flow'].contains(c.id)).toList();
          final analysisCards = cards.where((c) => ['budget', 'label_focus', 'income_expenses_labels', 'calendar'].contains(c.id)).toList();
          final actionsCards = cards.where((c) => ['new_entry', 'transfer', 'transaction_search', 'history', 'settings'].contains(c.id)).toList();

          Widget buildCategorySection(String title, List<CardConfig> catCards) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF582F95)),
                  ),
                ),
                ...catCards.map((card) => ListTile(
                      key: ValueKey(card.id),
                      title: Text(card.title),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              card.isVisible ? Icons.visibility : Icons.visibility_off,
                              color: card.isVisible ? const Color(0xFF582F95) : Colors.grey,
                            ),
                            onPressed: () {
                              setModalState(() {
                                onToggleVisibility(card);
                              });
                              setState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            onPressed: () {
                              int index = cards.indexOf(card);
                              if (index > 0) {
                                setModalState(() {
                                  cards.removeAt(index);
                                  cards.insert(index - 1, card);
                                });
                                setState(() {});
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            onPressed: () {
                              int index = cards.indexOf(card);
                              if (index < cards.length - 1) {
                                setModalState(() {
                                  cards.removeAt(index);
                                  cards.insert(index + 1, card);
                                });
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(modalContext);
                        _navigateToCard(card.id);
                      },
                    )),
                const Divider(),
              ],
            );
          }

          return Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cards Stack Manager',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      buildCategorySection('Overview', overviewCards),
                      buildCategorySection('Analytics', analyticsCards),
                      buildCategorySection('Analysis', analysisCards),
                      buildCategorySection('Actions', actionsCards),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> loadData({bool showLoading = false}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    
    final txs = await DatabaseHelper.instance.getTransactions();
    final lbls = await DatabaseHelper.instance.getLabels();
    final bdgs = await DatabaseHelper.instance.getBudgets();
    final gls = await DatabaseHelper.instance.getSavingsGoals();

    setState(() {
      _transactions = txs;
      _labels = lbls;
      _budgets = bdgs;
      _goals = gls;
      calculateMetrics();
      _isLoading = false;
    });
  }

  Future<void> _handleSaveGoal(SavingsGoalModel goal) async {
    await DatabaseHelper.instance.insertSavingsGoal(goal);
    await Future.delayed(const Duration(milliseconds: 150));
    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Savings goal created!')));
  }

  Future<void> _handleAddFundsToGoal(int goalId, double amountToAdd, String owner, String fromPool, String goalName) async {
    final goal = _goals.firstWhere((g) => g.id == goalId);
    final updatedAmount = goal.currentAmount + amountToAdd;

    await DatabaseHelper.instance.updateSavingsGoalCurrentAmount(goalId, updatedAmount);

    final labelObj = _labels.firstWhere(
      (l) => l.name.toLowerCase() == 'goals',
      orElse: () => _labels.first,
    );

    int transferLabelId = _labels.isNotEmpty ? _labels.first.id : 1;
    for (var label in _labels) {
      if (label.name.toLowerCase() == 'transfer') {
        transferLabelId = label.id;
        break;
      }
    }

    final outboundTx = TransactionModel(
      description: 'Transfer out to Goal: $goalName',
      amount: amountToAdd,
      type: 'expense',
      pool: fromPool,
      labelId: transferLabelId,
      owner: owner,
      createdAt: DateTime.now().toIso8601String(),
      isConfirmed: 1,
      isSavings: 0,
    );

    final inboundTx = TransactionModel(
      description: 'Contribution to Goal: $goalName',
      amount: amountToAdd,
      type: 'income',
      pool: 'goals',
      labelId: labelObj.id,
      owner: owner,
      createdAt: DateTime.now().toIso8601String(),
      isConfirmed: 1,
      isSavings: 0,
    );

    await DatabaseHelper.instance.insertTransaction(outboundTx);
    await DatabaseHelper.instance.insertTransaction(inboundTx);

    await Future.delayed(const Duration(milliseconds: 150));
    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funds transferred to goal pool successfully!')));
  }

  Future<void> _deleteSavingsGoal(int id) async {
    final goalToDelete = _goals.firstWhere((g) => g.id == id, orElse: () => _goals.first);
    final matchingTxs = _transactions.where((tx) => tx.description.contains(goalToDelete.name)).toList();
    for (var tx in matchingTxs) {
      if (tx.id != null) {
        await DatabaseHelper.instance.deleteTransaction(tx.id!);
      }
    }

    await DatabaseHelper.instance.deleteSavingsGoal(id);
    await Future.delayed(const Duration(milliseconds: 150));
    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Savings goal removed and funds restored!')));
  }

  Future<void> _completeSavingsGoal(int id) async {
    await DatabaseHelper.instance.deleteSavingsGoal(id);
    await Future.delayed(const Duration(milliseconds: 150));
    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Goal completed and achieved!')));
  }

  void calculateMetrics() {
    final now = DateTime.now();
    final activeOwnersForCards = _globalSelectedOwner != null 
        ? [_globalSelectedOwner!] 
        : _owners;

    Map<String, Map<String, double>> poolByOwner = {};
    Map<String, double> totalPools = {};
    Map<String, double> liquidNetOwner = {};
    Map<String, Map<String, double>> liquidNetBreakdown = {};
    Map<String, double> futureByOwner = {};
    Map<String, double> prognosisByOwnerMap = {};

    for (var owner in _owners) {
      poolByOwner[owner] = {};
      for (var poolKey in _pools.keys) {
        poolByOwner[owner]![poolKey] = 0.0;
      }
      liquidNetOwner[owner] = 0.0;
      liquidNetBreakdown[owner] = {'liquidNet': 0.0};
      futureByOwner[owner] = 0.0;
      prognosisByOwnerMap[owner] = 0.0;
    }

    for (var poolKey in _pools.keys) {
      totalPools[poolKey] = 0.0;
    }

    double totLiquidNet = 0;
    double totFuture = 0;
    double totPrognosis = 0;

    for (var t in _transactions) {
      if (_globalSelectedOwner != null && t.owner != _globalSelectedOwner) continue;
      if (t.isConfirmed != 1) continue;

      final txDate = DateTime.tryParse(t.createdAt) ?? now;
      final isFuture = txDate.isAfter(now);
      double amount = t.type == 'income' ? t.amount : -t.amount;
      String owner = _owners.contains(t.owner) ? t.owner : (_owners.isNotEmpty ? _owners.first : 'Shared');

      bool matchesFutureDateRange = true;
      if (isFuture) {
        if (_futureMetricsStartDate != null) {
          final startClean = DateTime(_futureMetricsStartDate!.year, _futureMetricsStartDate!.month, _futureMetricsStartDate!.day);
          if (txDate.isBefore(startClean)) matchesFutureDateRange = false;
        }
        if (_futureMetricsEndDate != null) {
          final endClean = DateTime(_futureMetricsEndDate!.year, _futureMetricsEndDate!.month, _futureMetricsEndDate!.day, 23, 59, 59);
          if (txDate.isAfter(endClean)) matchesFutureDateRange = false;
        }
      }

      if (isFuture && matchesFutureDateRange) {
        totFuture += amount;
        futureByOwner[owner] = (futureByOwner[owner] ?? 0) + amount;
      } else if (!isFuture) {
        totalPools[t.pool] = (totalPools[t.pool] ?? 0) + amount;
        if (poolByOwner.containsKey(owner)) {
          poolByOwner[owner]![t.pool] = (poolByOwner[owner]![t.pool] ?? 0) + amount;
        }

        if (_liquidNetPools[t.pool] == true) {
          totLiquidNet += amount;
          liquidNetOwner[owner] = (liquidNetOwner[owner] ?? 0) + amount;
          if (liquidNetBreakdown.containsKey(owner)) {
            liquidNetBreakdown[owner]!['liquidNet'] = (liquidNetBreakdown[owner]!['liquidNet'] ?? 0) + amount;
          }
        }
      }

      bool includeInProg = t.pool == 'checking';
      if (t.pool == 'cash' && (_prognosisPools['cash'] == true)) includeInProg = true;
      if (t.pool == 'savings' && (_prognosisPools['savings'] == true)) includeInProg = true;
      if ((t.pool == 'loans' || t.pool == 'loan') && (_prognosisPools['loans'] == true)) includeInProg = true;

      bool matchesPrognosisDateRange = true;
      if (isFuture) {
        if (_futureMetricsStartDate != null) {
          final startClean = DateTime(_futureMetricsStartDate!.year, _futureMetricsStartDate!.month, _futureMetricsStartDate!.day);
          if (txDate.isBefore(startClean)) matchesPrognosisDateRange = false;
        }
        if (_futureMetricsEndDate != null) {
          final endClean = DateTime(_futureMetricsEndDate!.year, _futureMetricsEndDate!.month, _futureMetricsEndDate!.day, 23, 59, 59);
          if (txDate.isAfter(endClean)) matchesPrognosisDateRange = false;
        }
      }

      if (includeInProg && (!isFuture || matchesPrognosisDateRange)) {
        totPrognosis += amount;
        prognosisByOwnerMap[owner] = (prognosisByOwnerMap[owner] ?? 0) + amount;
      }
    }

    _totalLiquidNet = totLiquidNet;
    _totalPoolTotals = totalPools;
    _poolTotalsByOwner = {for (var o in activeOwnersForCards) o: poolByOwner[o] ?? {}};
    _liquidNetByOwner = {for (var o in activeOwnersForCards) o: liquidNetOwner[o] ?? 0.0};
    _ownerBreakdownForLiquidNet = {for (var o in activeOwnersForCards) o: liquidNetBreakdown[o] ?? {'liquidNet': 0.0}};
    _totalFutureFlow = totFuture;
    _futureFlowByOwner = {for (var o in activeOwnersForCards) o: futureByOwner[o] ?? 0.0};
    _totalPrognosis = totPrognosis;
    _prognosisByOwner = {for (var o in activeOwnersForCards) o: prognosisByOwnerMap[o] ?? 0.0};
  }

  Future<void> _deleteBulkTransactions(String mode, {int? year, int? month}) async {
    int deletedCount = 0;
    final txsCopy = List.from(_transactions);

    for (var tx in txsCopy) {
      if (tx.id == null) continue;
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null) continue;

      bool shouldDelete = false;
      if (mode == 'all') {
        shouldDelete = true;
      } else if (mode == 'year' && year != null) {
        if (txDate.year == year) shouldDelete = true;
      } else if (mode == 'month' && year != null && month != null) {
        if (txDate.year == year && txDate.month == month) shouldDelete = true;
      }

      if (shouldDelete) {
        await DatabaseHelper.instance.deleteTransaction(tx.id!);
        deletedCount++;
      }
    }

    await loadData(showLoading: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully deleted $deletedCount transactions!')),
    );
  }

  Future<void> _bulkUpdateTransactionsLabel(String oldLabel, String newLabel) async {
    int count = await DatabaseHelper.instance.bulkUpdateTransactionsLabel(oldLabel, newLabel);
    await loadData(showLoading: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully updated $count transactions from "$oldLabel" to "$newLabel"!')),
    );
  }

  Future<void> _importCsvFile(BuildContext context) async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Spreadsheets',
        extensions: <String>['csv', 'txt', 'xls', 'xlsx'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (file == null) return;

      String content = await file.readAsString();
      if (content.isEmpty) return;

      List<String> lines = content.split('\n');
      if (lines.isEmpty) return;

      int importedCount = 0;
      int startIndex = 0;
      String firstLine = lines[0].toLowerCase();
      if (firstLine.contains('date') || firstLine.contains('amount') || firstLine.contains('description') || firstLine.contains('id')) {
        startIndex = 1;
      }

      for (int i = startIndex; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isEmpty) continue;

        List<String> cols = _parseCsvRow(line);
        if (cols.length < 5) continue;

        try {
          String dateStr = cols.length > 1 ? cols[1].replaceAll('"', '').trim() : DateTime.now().toIso8601String();
          DateTime? parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
          
          String description = cols.length > 2 ? cols[2].replaceAll('"', '').trim() : '';
          double amount = cols.length > 3 ? double.tryParse(cols[3].replaceAll('"', '').replaceAll('\$', '').trim()) ?? 0.0 : 0.0;
          String type = cols.length > 4 ? cols[4].replaceAll('"', '').trim().toLowerCase() : 'expense';
          if (type != 'income' && type != 'expense') type = 'expense';
          
          String owner = cols.length > 5 ? cols[5].replaceAll('"', '').trim() : (_owners.isNotEmpty ? _owners.first : 'Shared');
          if (!_owners.contains(owner) && _owners.isNotEmpty) owner = _owners.first;

          String pool = cols.length > 6 ? cols[6].replaceAll('"', '').trim().toLowerCase() : 'checking';
          if (!_pools.containsKey(pool)) pool = 'checking';

          String labelName = cols.length > 7 ? cols[7].replaceAll('"', '').trim() : 'General';
          int labelId = _labels.isNotEmpty ? _labels.first.id : 1;
          for (var l in _labels) {
            if (l.name.toLowerCase() == labelName.toLowerCase()) {
              labelId = l.id;
              break;
            }
          }

          int confirmed = 1;
          if (cols.length > 8) {
            confirmed = int.tryParse(cols[8].replaceAll('"', '').trim()) ?? 1;
          }

          final newTx = TransactionModel(
            createdAt: parsedDate.toIso8601String(),
            description: description,
            amount: amount,
            type: type,
            labelId: labelId,
            owner: owner,
            pool: pool,
            isConfirmed: confirmed,
            isSavings: pool == 'savings' ? 1 : 0,
          );

          await DatabaseHelper.instance.insertTransaction(newTx);
          importedCount++;
        } catch (_) {}
      }

      await loadData(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully imported $importedCount transactions!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing file: $e')),
      );
    }
  }

  List<String> _parseCsvRow(String line) {
    List<String> result = [];
    bool inQuotes = false;
    StringBuffer currentVal = StringBuffer();
    
    for (int i = 0; i < line.length; i++) {
      String char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if ((char == ',' || char == ';') && !inQuotes) {
        result.add(currentVal.toString());
        currentVal.clear();
      } else {
        currentVal.write(char);
      }
    }
    result.add(currentVal.toString());
    return result;
  }

  Future<void> _addBudget(int labelId, double limitAmount, String owner) async {
    await DatabaseHelper.instance.insertBudget(labelId, limitAmount);
    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget created!')));
  }

  Future<void> _deleteBudget(int budgetId) async {
    await DatabaseHelper.instance.deleteBudget(budgetId);
    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget removed!')));
  }

  Future<void> _deleteTransaction(int id) async {
    final txToDelete = _transactions.firstWhere((tx) => tx.id == id, orElse: () => _transactions.first);
    
    if (txToDelete.description.contains('Goal:')) {
      final goalName = txToDelete.description.split(':').last.trim();
      await DatabaseHelper.instance.subtractFromSavingsGoalByName(goalName, txToDelete.amount);

      final matchingTx = _transactions.firstWhere(
        (tx) => tx.id != id && 
                tx.description.contains(goalName) && 
                tx.amount == txToDelete.amount &&
                tx.createdAt == txToDelete.createdAt,
        orElse: () => txToDelete,
      );

      if (matchingTx.id != txToDelete.id && matchingTx.id != null) {
        await DatabaseHelper.instance.deleteTransaction(matchingTx.id!);
      }
    }

    await DatabaseHelper.instance.deleteTransaction(id);
    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction deleted & funds restored!')));
  }

  Future<void> _confirmTransaction(TransactionModel tx) async {
    final confirmedTx = TransactionModel(
      id: tx.id,
      createdAt: tx.createdAt,
      description: tx.description,
      amount: tx.amount,
      type: tx.type,
      labelId: tx.labelId,
      owner: tx.owner,
      pool: tx.pool,
      isConfirmed: 1,
      isSavings: tx.isSavings,
    );
    await DatabaseHelper.instance.updateTransaction(confirmedTx);
    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction confirmed!')));
  }

  Future<void> _handleNewZaznamSubmit({
    required String description,
    required double amount,
    required String type,
    required int? labelId,
    required String owner,
    required String pool,
    required bool isRecurring,
    required String frequency,
    required int dayOfMonth,
    required List<int> excludedWeekdays,
    required List<int> excludedMonths,
    required DateTime? repeatUntilDate,
    required DateTime date,
  }) async {
    if (amount <= 0) return;

    List<DateTime> datesToGenerate = [];

    if (!_isExcluded(date, excludedWeekdays, excludedMonths)) {
      datesToGenerate.add(date);
    }

    if (isRecurring) {
      final endDate = repeatUntilDate ?? date.add(const Duration(days: 365));
      DateTime current = date;

      while (true) {
        if (frequency == 'Daily') {
          current = current.add(const Duration(days: 1));
        } else if (frequency == 'Weekly') {
          current = current.add(const Duration(days: 7));
        } else if (frequency == 'Yearly') {
          int targetYear = current.year + 1;
          int targetMonth = current.month;
          int targetDay = current.day;
          int maxDaysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
          if (targetDay > maxDaysInMonth) targetDay = maxDaysInMonth;
        
          current = DateTime(targetYear, targetMonth, targetDay, current.hour, current.minute);
        } else {
          int targetYear = current.month == 12 ? current.year + 1 : current.year;
          int targetMonth = current.month == 12 ? 1 : current.month + 1;
          int maxDaysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
          int actualDay = dayOfMonth > maxDaysInMonth ? maxDaysInMonth : dayOfMonth;

          current = DateTime(targetYear, targetMonth, actualDay, current.hour, current.minute);
        }

        if (current.isAfter(endDate)) {
          break;
        }

        if (!_isExcluded(current, excludedWeekdays, excludedMonths)) {
          datesToGenerate.add(current);
        }
      }
    }

    for (var dt in datesToGenerate) {
      final newTx = TransactionModel(
        createdAt: dt.toIso8601String(),
        description: description,
        amount: amount,
        type: type,
        labelId: labelId ?? (_labels.isNotEmpty ? _labels.first.id : 1),
        owner: owner,
        pool: pool,
        isConfirmed: 1,
        isSavings: pool == 'savings' ? 1 : 0,
      );
      await DatabaseHelper.instance.insertTransaction(newTx);
    }

    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(datesToGenerate.length > 1 ? '${datesToGenerate.length} recurring entries added!' : 'Zaznam saved successfully!')),
    );
  }

  bool _isExcluded(DateTime date, List<int> excludedWeekdays, List<int> excludedMonths) {
    if (excludedWeekdays.contains(date.weekday)) return true;
    if (excludedMonths.contains(date.month)) return true;
    return false;
  }

  Future<void> _handleTransferFunds({
    required String fromPool,
    required String toPool,
    required String fromOwner,
    required String toOwner,
    required double amount,
    required String description,
    required DateTime date,
  }) async {
    if (amount <= 0) return;

    int transferLabelId = _labels.isNotEmpty ? _labels.first.id : 1;
    for (var label in _labels) {
      if (label.name.toLowerCase() == 'transfer') {
        transferLabelId = label.id;
        break;
      }
    }

    final outbound = TransactionModel(
      createdAt: date.toIso8601String(),
      description: description.isNotEmpty ? 'Transfer out: $description' : 'Transfer out to $toPool',
      amount: amount,
      type: 'expense',
      labelId: transferLabelId,
      owner: fromOwner,
      pool: fromPool,
      isConfirmed: 1,
      isSavings: 0,
    );

    final inbound = TransactionModel(
      createdAt: date.toIso8601String(),
      description: description.isNotEmpty ? 'Transfer in: $description' : 'Transfer in from $fromPool',
      amount: amount,
      type: 'income',
      labelId: transferLabelId,
      owner: toOwner,
      pool: toPool,
      isConfirmed: 1,
      isSavings: 0,
    );

    await DatabaseHelper.instance.insertTransaction(outbound);
    await DatabaseHelper.instance.insertTransaction(inbound);

    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer executed successfully!')));
  }

  Future<void> _addLabel(String name) async {
    if (name.isEmpty) return;
    await DatabaseHelper.instance.insertLabel(name, '#4338CA');
    await loadData();
  }

  Future<void> _updateLabel(int id, String newName) async {
    if (newName.isEmpty) return;
    await DatabaseHelper.instance.updateLabel(id, newName, '#4338CA');
    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Label updated!')));
  }

  Future<void> _deleteLabel(int id) async {
    await DatabaseHelper.instance.deleteLabel(id);
    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Label removed!')));
  }

  Future<void> showEditTransactionDialog(TransactionModel tx) async {
    final descController = TextEditingController(text: tx.description);
    final amountController = TextEditingController(text: tx.amount.toString());
    String type = tx.type;
    String owner = tx.owner;
    String pool = tx.pool;
    int? selectedLabelId = tx.labelId;
    DateTime selectedDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stateContext, setDialogState) => AlertDialog(
          title: const Text('Edit Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: stateContext,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    child: Text(DateFormat('MM/dd/yyyy').format(selectedDate)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 12),
                TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'income', child: Text('Income (+)')),
                    DropdownMenuItem(value: 'expense', child: Text('Expense (-)'))
                  ],
                  onChanged: (val) => type = val ?? type,
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: owner,
                  items: _owners.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                  onChanged: (val) => owner = val ?? owner,
                  decoration: const InputDecoration(labelText: 'Owner'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _pools.containsKey(pool) ? pool : _pools.keys.first,
                  items: _pools.keys.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
                  onChanged: (val) => pool = val ?? pool,
                  decoration: const InputDecoration(labelText: 'Pool'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedLabelId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('General'),
                    ),
                    ..._labels.map((l) => DropdownMenuItem<int>(
                          value: l.id,
                          child: Text(l.name),
                        )),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedLabelId = val;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? tx.amount;
                final originalTime = DateTime.tryParse(tx.createdAt);
                final combinedDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  originalTime?.hour ?? DateTime.now().hour,
                  originalTime?.minute ?? DateTime.now().minute,
                );

                final updatedTx = TransactionModel(
                  id: tx.id,
                  createdAt: combinedDateTime.toIso8601String(),
                  description: descController.text,
                  amount: amount,
                  type: type,
                  labelId: selectedLabelId ?? 0,
                  owner: owner,
                  pool: pool,
                  isConfirmed: tx.isConfirmed,
                  isSavings: pool == 'savings' ? 1 : 0,
                );
                await DatabaseHelper.instance.updateTransaction(updatedTx);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                await loadData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction updated!')));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange(
    BuildContext context,
    DateTime? currentStart,
    DateTime? currentEnd,
    Function(DateTime?, DateTime?) onRangeSelected,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: (currentStart != null && currentEnd != null)
          ? DateTimeRange(start: currentStart, end: currentEnd)
          : null,
    );

    if (picked != null) {
      onRangeSelected(picked.start, picked.end);
    }
  }

  Widget _buildCardWidget(CardConfig card) {
    switch (card.id) {
      case 'savings_goals':
        return SavingsGoalsCard(
          goals: _goals,
          labels: _labels,
          owners: _owners,
          pools: _pools.keys.toList(),
          selectedOwner: _globalSelectedOwner,
          onSaveGoal: _handleSaveGoal,
          onAddFundsToGoal: _handleAddFundsToGoal,
          onDeleteGoal: _deleteSavingsGoal,
          onCompleteGoal: _completeSavingsGoal,
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      case 'settings':
        return AppSettingsCard(
          initialPools: _pools,
          initialLiquidNetPools: _liquidNetPools,
          initialPrognosisPools: _prognosisPools,
          initialOwners: _owners,
          initialLeftNavItems: _leftNavItems,
          initialRightNavItems: _rightNavItems,
          labels: _labels,
          cards: _cards,
          onThemeChanged: widget.onThemeChanged,
          onPinSettingsChanged: widget.onPinSettingsChanged,
          onSavePools: (updatedPools) => _savePoolsPreferences(updatedPools),
          onSaveLiquidNetPools: (updatedLiquidNet) {
            setState(() {
              _liquidNetPools = updatedLiquidNet;
              calculateMetrics();
            });
          },
          onSavePrognosisPools: (updatedProg) {
            setState(() {
              _prognosisPools = updatedProg;
              calculateMetrics();
            });
          },
          onSaveOwners: (updatedOwners) {
            setState(() {
              _owners = updatedOwners;
              calculateMetrics();
            });
          },
          onSaveNavItems: (left, right) {
            setState(() {
              _leftNavItems = left;
              _rightNavItems = right;
            });
          },
          onSaveCardOrder: (List<CardConfig> newCardsOrder) {
            setState(() {
              _cards.clear();
              _cards.addAll(newCardsOrder);
            });
          },
          onAddLabel: (name) => _addLabel(name),
          onUpdateLabel: (id, name) => _updateLabel(id, name),
          onDeleteLabel: (id) => _deleteLabel(id),
          onImportCsv: () => _importCsvFile(context),
          onDeleteBulkTransactions: _deleteBulkTransactions,
          onBulkUpdateTransactionsLabel: _bulkUpdateTransactionsLabel,
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      case 'metrics':
        return SummaryMetricsCard(
          owners: _owners,
          selectedOwner: _globalSelectedOwner ?? 'All Owners',
          poolTotalsByOwner: _poolTotalsByOwner,
          totalPoolTotals: _totalPoolTotals,
          liquidNetByOwner: _liquidNetByOwner,
          totalLiquidNet: _totalLiquidNet,
          ownerBreakdownForLiquidNet: _ownerBreakdownForLiquidNet,
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      case 'label_focus':
        return SelectedLabelFocusCard(
          transactions: _transactions,
          labels: _labels,
          owners: _owners,
          startDate: _labelFocusStartDate,
          endDate: _labelFocusEndDate,
          selectedOwner: _labelFocusSelectedOwner ?? _globalSelectedOwner,
          selectedLabelId: _labelFocusSelectedLabelId,
          onLabelChanged: (val) => setState(() => _labelFocusSelectedLabelId = val),
          onOwnerChanged: (val) => setState(() => _labelFocusSelectedOwner = val),
          onSelectStartDate: () => _pickDateRange(context, _labelFocusStartDate, _labelFocusEndDate, (start, end) => setState(() {
            _labelFocusStartDate = start;
            _labelFocusEndDate = end;
          })),
          onSelectEndDate: () => _pickDateRange(context, _labelFocusStartDate, _labelFocusEndDate, (start, end) => setState(() {
            _labelFocusStartDate = start;
            _labelFocusEndDate = end;
          })),
          onClearDateFilter: () => setState(() {
            _labelFocusStartDate = null;
            _labelFocusEndDate = null;
          }),
          onJumpToHistory: (labelId, owner, start, end) {
            setState(() {
              _historySelectedLabelId = labelId;
              _historySelectedOwner = owner;
              _historyStartDate = start;
              _historyEndDate = end;
            });
            _navigateToCard('history');
          },
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      case 'transaction_search':
        return TransactionSearchCard(
          transactions: _transactions,
          labels: _labels,
          owners: _owners,
          pools: _pools.keys.toList(),
          onDeleteTransaction: _deleteTransaction,
          onEditTransaction: showEditTransactionDialog,
          onConfirmTransaction: _confirmTransaction,
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      case 'future_metrics':
        return FutureMetricsCard(
          owners: _owners,
          selectedOwner: _futureMetricsSelectedOwner ?? _globalSelectedOwner,
          futureFlowByOwner: _futureFlowByOwner,
          totalFutureFlow: _totalFutureFlow,
          prognosisByOwner: _prognosisByOwner,
          totalPrognosis: _totalPrognosis,
          startDate: _futureMetricsStartDate,
          endDate: _futureMetricsEndDate,
          onDateRangeChanged: (start, end) {
            setState(() {
              _futureMetricsStartDate = start;
              _futureMetricsEndDate = end;
              calculateMetrics();
            });
          },
          onClearDateFilter: () {
            setState(() {
              _futureMetricsStartDate = null;
              _futureMetricsEndDate = null;
              calculateMetrics();
            });
          },
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      case 'budget':
        return BudgetProgressCard(
          budgets: _budgets,
          transactions: _transactions,
          labels: _labels,
          owners: _owners,
          selectedOwner: _budgetSelectedOwner ?? _globalSelectedOwner,
          onOwnerChanged: (owner) => setState(() => _budgetSelectedOwner = owner),
          onAddBudget: (labelId, limitAmount, owner) => _addBudget(labelId, limitAmount, owner),
          onUpdateBudgetLimit: (budgetId, newLimit) async {
            await DatabaseHelper.instance.updateBudgetLimit(budgetId, newLimit);
            await loadData();
          },
          onDeleteBudget: _deleteBudget,
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      case 'new_entry':
        return NewZaznamCard(
          labels: _labels,
          pools: _pools.keys.toList(),
          owners: _owners,
          selectedGlobalOwner: _globalSelectedOwner,
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
          onSubmit: (description, amount, type, labelId, owner, pool, isRecurring, frequency, dayOfMonth, excludedWeekdays, excludedMonths, repeatUntilDate, date) {
            _handleNewZaznamSubmit(
              description: description,
              amount: amount,
              type: type,
              labelId: labelId,
              owner: owner,
              pool: pool,
              isRecurring: isRecurring,
              frequency: frequency,
              dayOfMonth: dayOfMonth,
              excludedWeekdays: excludedWeekdays,
              excludedMonths: excludedMonths,
              repeatUntilDate: repeatUntilDate,
              date: date,
            );
          },
        );
      case 'transfer':
        return TransferFundsCard(
          pools: _pools.keys.toList(),
          owners: _owners,
          selectedGlobalOwner: _globalSelectedOwner,
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
          onTransfer: (fromPool, toPool, fromOwner, toOwner, amount, description, date) {
            _handleTransferFunds(
              fromPool: fromPool,
              toPool: toPool,
              fromOwner: fromOwner,
              toOwner: toOwner,
              amount: amount,
              description: description,
              date: date,
            );
          },
        );
      case 'monthly_trend':
        return MonthlyCashflowTrendCard(
          transactions: _transactions,
          owners: _owners,
          pools: _pools.keys.toList(),
          selectedOwner: _monthlyTrendSelectedOwner ?? _globalSelectedOwner,
          onOwnerChanged: (owner) => setState(() => _monthlyTrendSelectedOwner = owner),
          selectedPool: _sankeySelectedPool,
          onPoolChanged: (pool) => setState(() => _sankeySelectedPool = pool),
          onJumpToHistory: (monthKey, type, owner) {
            final parts = monthKey.split('-');
            final year = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final start = DateTime(year, month, 1);
            final end = DateTime(year, month + 1, 0);

            setState(() {
              _historyStartDate = start;
              _historyEndDate = end;
              _historySelectedType = type;
              _historySelectedOwner = owner;
            });

            _navigateToCard('history');
          },
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      case 'trend_chart':
        return LiquidTrendChartCard(
          transactions: _transactions,
          liquidNetPools: _liquidNetPools,
          owners: _owners,
          selectedOwner: _trendSelectedOwner ?? _globalSelectedOwner,
          onOwnerChanged: (owner) => setState(() => _trendSelectedOwner = owner),
          startDate: _trendStartDate,
          endDate: _trendEndDate,
          onSelectStartDate: () => _pickDateRange(context, _trendStartDate, _trendEndDate, (start, end) => setState(() {
            _trendStartDate = start;
            _trendEndDate = end;
          })),
          onSelectEndDate: () => _pickDateRange(context, _trendStartDate, _trendEndDate, (start, end) => setState(() {
            _trendStartDate = start;
            _trendEndDate = end;
          })),
          onClearDateFilter: () => setState(() {
            _trendStartDate = null;
            _trendEndDate = null;
          }),
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      case 'savings_chart':
        return SavingsChartCard(
          transactions: _transactions,
          labels: _labels,
          owners: _owners,
          selectedOwner: _savingsChartSelectedOwner ?? _globalSelectedOwner,
          onOwnerChanged: (owner) => setState(() => _savingsChartSelectedOwner = owner),
          startDate: _savingsChartStartDate,
          endDate: _savingsChartEndDate,
          onSelectStartDate: () => _pickDateRange(context, _savingsChartStartDate, _savingsChartEndDate, (start, end) => setState(() {
            _savingsChartStartDate = start;
            _savingsChartEndDate = end;
          })),
          onSelectEndDate: () => _pickDateRange(context, _savingsChartStartDate, _savingsChartEndDate, (start, end) => setState(() {
            _savingsChartStartDate = start;
            _savingsChartEndDate = end;
          })),
          onClearDateFilter: () => setState(() {
            _savingsChartStartDate = null;
            _savingsChartEndDate = null;
          }),
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      case 'pools_analytics':
        return PoolsAnalyticsCard(
          transactions: _transactions,
          pools: _pools,
          owners: _owners,
          selectedOwner: _globalSelectedOwner,
          onOwnerChanged: (owner) => setState(() => _globalSelectedOwner = owner),
          startDate: _savingsChartStartDate, // or create dedicated pool analytics date state if preferred
          endDate: _savingsChartEndDate,
          onSelectStartDate: () => _pickDateRange(context, _savingsChartStartDate, _savingsChartEndDate, (start, end) => setState(() {
            _savingsChartStartDate = start;
            _savingsChartEndDate = end;
          })),
          onSelectEndDate: () => _pickDateRange(context, _savingsChartStartDate, _savingsChartEndDate, (start, end) => setState(() {
            _savingsChartStartDate = start;
            _savingsChartEndDate = end;
          })),
          onClearDateFilter: () => setState(() {
            _savingsChartStartDate = null;
            _savingsChartEndDate = null;
          }),
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      case 'calendar':
        return CalendarCard(
          transactions: _transactions,
          owners: _owners,
          selectedOwner: _calendarSelectedOwner ?? _globalSelectedOwner,
          onOwnerChanged: (owner) => setState(() => _calendarSelectedOwner = owner),
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
          historyKey: _cards.firstWhere((c) => c.id == 'history').key,
          onDateSelected: (selectedDate) {
            setState(() {
              _historyStartDate = selectedDate;
              _historyEndDate = selectedDate;
            });
          },
        );
      case 'sankey_flow':
        return SankeyFlowCard(
          transactions: _transactions,
          labels: _labels,
          owners: _owners,
          pools: _pools.keys.toList(),
          selectedOwner: _sankeySelectedOwner ?? _globalSelectedOwner,
          selectedPool: _sankeySelectedPool,
          startDate: _sankeyStartDate,
          endDate: _sankeyEndDate,
          onDateRangeChanged: (start, end) => setState(() {
            _sankeyStartDate = start;
            _sankeyEndDate = end;
          }),
          onOwnerChanged: (owner) => setState(() => _sankeySelectedOwner = owner),
          onPoolChanged: (pool) => setState(() => _sankeySelectedPool = pool),
          onClearDateFilter: () => setState(() {
            _sankeyStartDate = null;
            _sankeyEndDate = null;
            _sankeySelectedPool = null;
          }),
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      case 'income_expenses_labels':
        return IncomeExpensesByLabelsCard(
          transactions: _transactions,
          labels: _labels,
          owners: _owners,
          startDate: _labelsCardStartDate,
          endDate: _labelsCardEndDate,
          selectedOwner: _labelsCardSelectedOwner ?? _globalSelectedOwner,
          onSelectStartDate: () => _pickDateRange(context, _labelsCardStartDate, _labelsCardEndDate, (start, end) => setState(() {
            _labelsCardStartDate = start;
            _labelsCardEndDate = end;
          })),
          onSelectEndDate: () => _pickDateRange(context, _labelsCardStartDate, _labelsCardEndDate, (start, end) => setState(() {
            _labelsCardStartDate = start;
            _labelsCardEndDate = end;
          })),
          onOwnerChanged: (owner) => setState(() => _labelsCardSelectedOwner = owner),
          onClearDateFilter: () => setState(() {
            _labelsCardStartDate = null;
            _labelsCardEndDate = null;
          }),
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      case 'history':
        final effectiveHistoryOwner = _historySelectedOwner ?? _globalSelectedOwner;
        return TransactionHistoryCard(
          transactions: _transactions.where((tx) {
            final txDate = DateTime.tryParse(tx.createdAt);
            if (txDate == null) return true;
            if (_historyStartDate != null) {
              final startClean = DateTime(_historyStartDate!.year, _historyStartDate!.month, _historyStartDate!.day);
              if (txDate.isBefore(startClean)) return false;
            }
            if (_historyEndDate != null) {
              final endClean = DateTime(_historyEndDate!.year, _historyEndDate!.month, _historyEndDate!.day, 23, 59, 59);
              if (txDate.isAfter(endClean)) return false;
            }
            if (_historySelectedLabelId != null) {
              if (tx.labelId != _historySelectedLabelId) return false;
            }
            if (effectiveHistoryOwner != null) {
              if (tx.owner != effectiveHistoryOwner) return false;
            }
            if (_historySelectedType != null) {
              if (tx.type != _historySelectedType) return false;
            }
            return true;
          }).toList(),
          labels: _labels,
          owners: _owners,
          startDate: _historyStartDate,
          endDate: _historyEndDate,
          selectedLabelId: _historySelectedLabelId,
          selectedOwner: effectiveHistoryOwner,
          onSelectStartDate: () => _pickDateRange(context, _historyStartDate, _historyEndDate, (start, end) => setState(() {
            _historyStartDate = start;
            _historyEndDate = end;
          })),
          onSelectEndDate: () => _pickDateRange(context, _historyStartDate, _historyEndDate, (start, end) => setState(() {
            _historyStartDate = start;
            _historyEndDate = end;
          })),
          onLabelChanged: (labelId) => setState(() => _historySelectedLabelId = labelId),
          onOwnerChanged: (owner) => setState(() => _historySelectedOwner = owner),
          onClearDateFilter: () => setState(() {
            _historyStartDate = null;
            _historyEndDate = null;
          }),
          onDeleteTransaction: _deleteTransaction,
          onEditTransaction: showEditTransactionDialog,
          onConfirmTransaction: _confirmTransaction,
          isWide: card.isWide,
          onToggleWidth: () => setState(() => card.isWide = !card.isWide),
          onHide: () => setState(() => card.isVisible = false),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showZoomOutSnapshotModal() {
    final overviewCards = _cards.where((c) => c.isVisible && ['metrics', 'future_metrics', 'savings_goals'].contains(c.id)).toList();
    final analyticsCards = _cards.where((c) => c.isVisible && ['monthly_trend', 'trend_chart', 'savings_chart', 'pools_analytics', 'sankey_flow'].contains(c.id)).toList();
    final analysisCards = _cards.where((c) => c.isVisible && ['budget', 'label_focus', 'income_expenses_labels', 'calendar'].contains(c.id)).toList();
    final actionsCards = _cards.where((c) => c.isVisible && ['new_entry', 'transfer', 'transaction_search', 'history', 'settings'].contains(c.id)).toList();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1333),
        // Positioned higher up to prevent bottom navigation bar overlap
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.fromLTRB(12, 32, 12, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.96,
          height: MediaQuery.of(context).size.height * 0.78, // Reduced overall height
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.grid_view_rounded, color: Color(0xFFA855F7), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Zaznamity Dashboard Snapshot',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTabSnapshotColumn('Overview', overviewCards, 0),
                      const SizedBox(width: 12),
                      _buildTabSnapshotColumn('Analytics', analyticsCards, 1),
                      const SizedBox(width: 12),
                      _buildTabSnapshotColumn('Analysis', analysisCards, 2),
                      const SizedBox(width: 12),
                      _buildTabSnapshotColumn('Actions', actionsCards, 3),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSnapshotColumn(String title, List<CardConfig> cards, int tabIndex) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B4E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.pop(context);
              _tabController.animateTo(tabIndex, duration: const Duration(milliseconds: 180), curve: Curves.easeInOut);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFA855F7))),
                  const Icon(Icons.open_in_new, size: 10, color: Colors.white54),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 6),
          Expanded(
            child: cards.isEmpty
                ? const Center(child: Text('No visible cards', style: TextStyle(fontSize: 9, color: Colors.white38)))
                : ListView.builder(
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _navigateToCard(card.id);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  color: const Color(0xFFF1F5F9),
                                  child: Text(
                                    card.title,
                                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF582F95)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // IgnorePointer disables child widget touch/button interactions entirely
                                IgnorePointer(
                                  child: SizedBox(
                                    height: 144,
                                    width: double.infinity,
                                    child: ClipRect(
                                      child: OverflowBox(
                                        alignment: Alignment.topLeft,
                                        maxWidth: MediaQuery.of(context).size.width,
                                        maxHeight: MediaQuery.of(context).size.height,
                                        child: Transform.scale(
                                          scale: 0.25,
                                          alignment: Alignment.topLeft,
                                          child: SizedBox(
                                            width: MediaQuery.of(context).size.width - 40,
                                            child: _buildCardWidget(card),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<List<CardConfig>> _chunkCardsIntoRows(List<CardConfig> sectionCards, double screenWidth) {
    List<List<CardConfig>> rows = [];
    List<CardConfig> currentRow = [];
    int currentCols = 0;
    int maxCols = screenWidth >= 1200 ? 3 : (screenWidth >= 768 ? 2 : 1);

    for (var card in sectionCards) {
      int cardCols = card.isWide ? maxCols : 1;
      if (currentCols > 0 && (currentCols + cardCols > maxCols || card.isWide)) {
        rows.add(List.from(currentRow));
        currentRow.clear();
        currentCols = 0;
      }
      currentRow.add(card);
      currentCols += cardCols;
      if (card.isWide) {
        rows.add(List.from(currentRow));
        currentRow.clear();
        currentCols = 0;
      }
    }
    if (currentRow.isNotEmpty) {
      rows.add(currentRow);
    }
    return rows;
  }

  Widget _buildCardTabContent(List<CardConfig> sectionCards, double screenWidth) {
    final rows = _chunkCardsIntoRows(sectionCards, screenWidth);
    if (rows.isEmpty) {
      return const Center(
        child: Text('No active cards in this tab', style: TextStyle(color: Colors.grey)),
      );
    }

    const double sidePadding = 4.0; 
    final double netWidth = screenWidth - sidePadding;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 140), // Added top padding to prevent sitting flat against the top
      child: Column(
        children: rows.map((rowCards) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowCards.map((card) {
                double cardWidth;
                if (card.isWide) {
                  cardWidth = netWidth;
                } else {
                  if (screenWidth >= 1200) {
                    cardWidth = (netWidth - 40) / 3;
                  } else if (screenWidth >= 768) {
                    cardWidth = (netWidth - 20) / 2;
                  } else {
                    cardWidth = netWidth;
                  }
                }

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: rowCards.last == card ? 0 : 16,
                    ),
                    child: SizedBox(
                      key: card.key,
                      width: cardWidth,
                      child: RepaintBoundary(
                        child: _buildCardWidget(card),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final screenWidth = constraints.maxWidth;

                          final overviewCards = _cards.where((c) => c.isVisible && ['metrics', 'future_metrics', 'savings_goals'].contains(c.id)).toList();
                          final analyticsCards = _cards.where((c) => c.isVisible && ['monthly_trend', 'trend_chart', 'savings_chart', 'pools_analytics', 'sankey_flow'].contains(c.id)).toList();
                          final analysisCards = _cards.where((c) => c.isVisible && ['budget', 'label_focus', 'income_expenses_labels', 'calendar'].contains(c.id)).toList();
                          final actionsCards = _cards.where((c) => c.isVisible && ['new_entry', 'transfer', 'transaction_search', 'history', 'settings'].contains(c.id)).toList();

                          return TabBarView(
                            controller: _tabController,
                            children: [
                              _buildCardTabContent(overviewCards, screenWidth),
                              _buildCardTabContent(analyticsCards, screenWidth),
                              _buildCardTabContent(analysisCards, screenWidth),
                              _buildCardTabContent(actionsCards, screenWidth),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // Docked Bottom/Side Control Bar
                // Docked Bottom/Side Control Bar
                Positioned(
                  left: isLandscape ? 0 : 0,
                  right: isLandscape ? null : 0,
                  bottom: 0,
                  top: isLandscape ? 0 : null,
                  child: Align(
                    alignment: isLandscape ? Alignment.centerRight : Alignment.bottomCenter,
                    child: BottomCardNavBar(
                      cards: _cards,
                      leftItems: _leftNavItems,
                      rightItems: _rightNavItems,
                      isLandscape: isLandscape,
                      currentTabIndex: _tabController.index,
                      onTabSelected: (index) {
                        _tabController.animateTo(
                          index,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                        );
                      },
                      onOpenManager: () => showCardStackManager(
                        context,
                        _cards,
                        (card) => setState(() => card.isVisible = !card.isVisible),
                      ),
                      onQuickAdd: () => _navigateToCard('new_entry'),
                      onSelectOwner: _showOwnerSelectionDialog,
                      onNavigateToCard: (cardId) {
                        if (cardId == 'snapshot') {
                          _showZoomOutSnapshotModal();
                        } else {
                          _navigateToCard(cardId);
                        }
                      },
                      onToggleVisibility: (card) {
                        setState(() {
                          card.isVisible = true;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}