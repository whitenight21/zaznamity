// ignore_for_file: deprecated_member_use

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaznamity/models/card_config.dart';
import 'package:zaznamity/models/label.dart';
import 'package:zaznamity/models/transaction_model.dart';
import 'package:zaznamity/models/savings_goal_model.dart';
import 'package:zaznamity/models/liability_model.dart'; 
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
import '../widgets/title_card.dart';
import '../widgets/liabilities_card.dart'; 
import '../widgets/smart_insights_card.dart';

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
  List<LiabilityModel> _liabilities = []; 
  bool _isLoading = true;

  String? _globalSelectedOwner;
  String? _highlightedCardId;

  Map<String, Map<String, Map<String, double>>> _poolTotalsByCurrencyAndOwner = {};
  Map<String, Map<String, double>> _totalPoolTotalsByCurrency = {};
  Map<String, Map<String, double>> _liquidNetByCurrencyAndOwner = {};
  Map<String, Map<String, double>> _totalLiquidNetByCurrency = {};
  Map<String, Map<String, Map<String, double>>> _ownerBreakdownByCurrency = {};
  
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

  List<String> _availableCurrencies = ['USD'];
  final Map<String, String> _currencyFlags = {
    'USD': '🇺🇸',
    'EUR': '🇪🇺',
    'JPY': '🇯🇵',
    'GBP': '🇬🇧',
    'CNY': '🇨🇳',
    'AUD': '🇦🇺',
    'CAD': '🇨🇦',
    'CHF': '🇨🇭',
    'HKD': '🇭🇰',
    'SGD': '🇸🇬',
  };

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

  final CardConfig _titleCardConfig = CardConfig(id: 'title_card', title: 'Title Card', key: GlobalKey());

  late final List<CardConfig> _cards = [
    CardConfig(id: 'settings', title: 'Zaznamity Settings', key: GlobalKey(), isVisible: false),
    CardConfig(id: 'metrics', title: 'Metrics', key: GlobalKey()),
    CardConfig(id: 'smart_insights', title: 'Health & Insights', key: GlobalKey()),
    CardConfig(id: 'future_metrics', title: 'Future Metrics', key: GlobalKey()),
    CardConfig(id: 'liabilities_card', title: 'Liabilities', key: GlobalKey()),    
    CardConfig(id: 'savings_goals', title: 'Savings Goals', key: GlobalKey()),
    CardConfig(id: 'label_focus', title: 'Single-Label Analysis', key: GlobalKey()),
    CardConfig(id: 'income_expenses_labels', title: 'Multi-Label Analytics', key: GlobalKey()),
    CardConfig(id: 'transaction_search', title: 'Search Zaznams', key: GlobalKey()),
    CardConfig(id: 'new_entry', title: 'New Zaznam', key: GlobalKey()),
    CardConfig(id: 'transfer', title: 'Transfer Funds', key: GlobalKey()),
    CardConfig(id: 'budget', title: 'Budgets', key: GlobalKey()),
    CardConfig(id: 'trend_chart', title: 'Liquid Trend', key: GlobalKey()),
    CardConfig(id: 'savings_chart', title: 'Savings Trend', key: GlobalKey()),
    CardConfig(id: 'pools_analytics', title: 'Pools Trends', key: GlobalKey()),
    CardConfig(id: 'sankey_flow', title: 'Sankey Flow Trend', key: GlobalKey()),
    CardConfig(id: 'monthly_trend', title: 'Cash Flow Trend', key: GlobalKey()),
    CardConfig(id: 'calendar', title: 'Calendar', key: GlobalKey()),
    CardConfig(id: 'history', title: 'All Zaznams', key: GlobalKey()),
  ];

  bool _isZaznamityMode = true;

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
    final primary = prefs.getString('primaryCurrency') ?? 'USD';
    final sec1 = prefs.getString('secondaryCurrency1');
    final sec2 = prefs.getString('secondaryCurrency2');
    final sec3 = prefs.getString('secondaryCurrency3');

    List<String> currencies = [primary];
    if (sec1 != null && sec1.isNotEmpty) currencies.add(sec1);
    if (sec2 != null && sec2.isNotEmpty) currencies.add(sec2);
    if (sec3 != null && sec3.isNotEmpty) currencies.add(sec3);

    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    bool isZaznamity = (savedTheme == 'zaznamity');
    setState(() {
      _isZaznamityMode = isZaznamity;
    });
    if (widget.onThemeChanged != null) {
      widget.onThemeChanged!(isZaznamity);
    }

    final savedCardOrderStrings = prefs.getStringList('savedCardOrderList');
    
    if (savedCardOrderStrings != null && savedCardOrderStrings.isNotEmpty) {
      List<CardConfig> reorderedCards = [];
      
      for (var id in savedCardOrderStrings) {
        final existingCard = _cards.firstWhere((c) => c.id == id, orElse: () => _cards.first);
        reorderedCards.add(existingCard);
      }
      for (var c in _cards) {
        if (!reorderedCards.any((rc) => rc.id == c.id)) {
          reorderedCards.add(c);
        }
      }

      for (var c in reorderedCards) {
        c.isVisible = prefs.getBool('card_visible_${c.id}') ?? c.isVisible;
        c.isWide = prefs.getBool('card_wide_${c.id}') ?? c.isWide;
      }

      setState(() {
        _cards.clear();
        _cards.addAll(reorderedCards);
      });
    }

    setState(() {
      _availableCurrencies = currencies;
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

  Future<void> _saveCardLayoutPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> cardIds = _cards.map((c) => c.id).toList();
    await prefs.setStringList('savedCardOrderList', cardIds);
    for (var c in _cards) {
      await prefs.setBool('card_visible_${c.id}', c.isVisible);
      await prefs.setBool('card_wide_${c.id}', c.isWide);
    }
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
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        title: Text(
          'Select Owner (Master Filter)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.people_outline, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
              title: Text(
                'All Owners',
                style: TextStyle(fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87),
              ),
              onTap: () {
                setState(() {
                  _globalSelectedOwner = null;
                  calculateMetrics();
                });
                Navigator.pop(ctx);
              },
            ),
            Divider(color: _isZaznamityMode ? Colors.white24 : Colors.black12),
            ..._owners.map((owner) => ListTile(
                  leading: Icon(Icons.person, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                  title: Text(owner, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)),
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
      _highlightedCardId = cardId;
    });
    _saveCardLayoutPreferences();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _highlightedCardId == cardId) {
        setState(() {
          _highlightedCardId = null;
        });
      }
    });

    int targetTab = 0;
    if (['metrics', 'smart_insights', 'future_metrics', 'liabilities_card', 'savings_goals', 'budget'].contains(cardId)) {
      targetTab = 0;
    } else if (['monthly_trend', 'trend_chart', 'savings_chart', 'pools_analytics', 'sankey_flow'].contains(cardId)) {
      targetTab = 1;
    } else if (['label_focus', 'income_expenses_labels', 'calendar'].contains(cardId)) {
      targetTab = 2;
    } else {
      targetTab = 3;
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
            alignment: 0.08,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  void _jumpToHistoryForDate(DateTime date) {
    setState(() {
      _historyStartDate = date;
      _historyEndDate = date;
      final historyCard = _cards.firstWhere((c) => c.id == 'history');
      historyCard.isVisible = true;
      _highlightedCardId = 'history';
    });
    _saveCardLayoutPreferences();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _highlightedCardId == 'history') {
        setState(() {
          _highlightedCardId = null;
        });
      }
    });

    _tabController.animateTo(
      3,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final historyCard = _cards.firstWhere((c) => c.id == 'history');
        final context = historyCard.key.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.08,
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
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        alignment: Alignment.center,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: StatefulBuilder(
          builder: (stateContext, setModalState) {
            final metricsCards = cards.where((c) => ['metrics', 'smart_insights', 'future_metrics', 'liabilities_card', 'savings_goals', 'budget'].contains(c.id)).toList();
            final trendsCards = cards.where((c) => ['monthly_trend', 'trend_chart', 'savings_chart', 'pools_analytics', 'sankey_flow'].contains(c.id)).toList();
            final analyticsCards = cards.where((c) => ['label_focus', 'income_expenses_labels', 'calendar'].contains(c.id)).toList();
            final actionsCards = cards.where((c) => ['new_entry', 'transfer', 'transaction_search', 'history', 'settings'].contains(c.id)).toList();

            Widget buildCategorySection(String title, List<CardConfig> catCards, {bool isReorderable = false, List<CardConfig>? masterCardsRef}) {
              final headerWidget = Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                decoration: BoxDecoration(
                  color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _isZaznamityMode ? const Color(0xFF582F95) : Colors.white,
                  ),
                ),
              );

              final listContent = ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: catCards.length,
                itemBuilder: (context, index) {
                  final card = catCards[index];
                  final tileWidget = SizedBox(
                    height: 28,
                    child: ListTile(
                      key: ValueKey(card.id),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: const VisualDensity(vertical: -4),
                      title: Text(
                        card.title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: SizedBox(
                        height: 22,
                        width: 22,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            card.isVisible ? Icons.visibility : Icons.visibility_off,
                            size: 14,
                            color: card.isVisible 
                                ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)) 
                                : Colors.grey,
                          ),
                          onPressed: () {
                            setModalState(() {
                              onToggleVisibility(card);
                            });
                            setState(() {});
                            _saveCardLayoutPreferences();
                          },
                        ),
                      ),
                      onTap: () {
                        if (!card.isVisible) {
                          setModalState(() {
                            card.isVisible = true;
                          });
                          _saveCardLayoutPreferences();
                        }
                        Navigator.pop(ctx);
                        _navigateToCard(card.id);
                      },
                    ),
                  );

                  if (!isReorderable || masterCardsRef == null) {
                    return tileWidget;
                  }

                  return LongPressDraggable<CardConfig>(
                    data: card,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 180,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF3B1E63) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Text(
                          card.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0.3, child: tileWidget),
                    child: DragTarget<CardConfig>(
                      onAcceptWithDetails: (details) {
                        final draggedCard = details.data;
                        if (draggedCard.id != card.id && catCards.any((c) => c.id == draggedCard.id)) {
                          setModalState(() {
                            int oldIdx = catCards.indexWhere((c) => c.id == draggedCard.id);
                            int newIdx = catCards.indexWhere((c) => c.id == card.id);
                            if (oldIdx != -1 && newIdx != -1) {
                              catCards.removeAt(oldIdx);
                              catCards.insert(newIdx, draggedCard);

                              for (var c in catCards) {
                                masterCardsRef.remove(c);
                              }
                              int insertPos = masterCardsRef.indexWhere((c) => c.id == catCards.first.id);
                              if (insertPos == -1) insertPos = masterCardsRef.length;
                              masterCardsRef.insertAll(insertPos, catCards);
                            }
                          });
                          setState(() {});
                          _saveCardLayoutPreferences();
                        }
                      },
                      builder: (context, candidateData, rejectedData) => tileWidget,
                    ),
                  );
                },
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  headerWidget,
                  const SizedBox(height: 2),
                  listContent,
                ],
              );
            }

            return Container(
              width: MediaQuery.of(context).size.width * 0.95,
              constraints: const BoxConstraints(maxWidth: 650, maxHeight: 540),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Cards Manager',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (infoCtx) => AlertDialog(
                                  backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                  title: Text('Cards Manager Guide', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.bold)),
                                  content: Text(
                                    '• Click the title of any card to jump directly to it (unhides it automatically if hidden).\n\n'
                                    '• Long press any card title to rearrange its position within its tab.\n\n'
                                    '• Toggle card visibility with the eye icon.\n\n'
                                    '• Zaznamity settings are hidden by default.',
                                    style: TextStyle(color: _isZaznamityMode ? Colors.white70 : Colors.black87, fontSize: 12),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(infoCtx),
                                      child: const Text('Got it'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Icon(
                              Icons.info_outline,
                              size: 16,
                              color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.close, size: 16, color: _isZaznamityMode ? Colors.white70 : Colors.black54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Divider(color: _isZaznamityMode ? Colors.white24 : Colors.black12, height: 6),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                buildCategorySection('Metrics', metricsCards, isReorderable: true, masterCardsRef: cards),
                                const SizedBox(height: 8),
                                buildCategorySection('Analytics', analyticsCards, isReorderable: true, masterCardsRef: cards),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                buildCategorySection('Trends', trendsCards, isReorderable: true, masterCardsRef: cards),
                                const SizedBox(height: 8),
                                buildCategorySection('Actions', actionsCards, isReorderable: true, masterCardsRef: cards),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> loadData({bool showLoading = false}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    
    await DatabaseHelper.instance.checkAndApplyAutomaticLiabilityPayments();

    final txs = await DatabaseHelper.instance.getTransactions();
    final lbls = await DatabaseHelper.instance.getLabels();
    final bdgs = await DatabaseHelper.instance.getBudgets();
    final gls = await DatabaseHelper.instance.getSavingsGoals();
    final liabs = await DatabaseHelper.instance.getLiabilities(); 

    setState(() {
      _transactions = txs;
      _labels = lbls;
      _budgets = List<Map<String, dynamic>>.from(bdgs);
      _goals = List<SavingsGoalModel>.from(gls);
      _liabilities = List<LiabilityModel>.from(liabs); 
      calculateMetrics();
      _isLoading = false;
    });
  }

  Future<void> _handleSaveLiability(LiabilityModel liability) async {
    final labelName = '${liability.name} (L)';

    int targetLabelId;
    final existingLabel = _labels
        .where((l) => l.name.toLowerCase() == labelName.toLowerCase())
        .firstOrNull;
    
    if (existingLabel != null) {
      targetLabelId = existingLabel.id;
    } else {
      await DatabaseHelper.instance.insertLabel(labelName, '#582F95');
      final updatedLabels = await DatabaseHelper.instance.getLabels();
      final newlyCreated = updatedLabels.firstWhere(
        (l) => l.name.toLowerCase() == labelName.toLowerCase(),
        orElse: () => updatedLabels.first,
      );
      targetLabelId = newlyCreated.id;
    }

    await DatabaseHelper.instance.insertLiability(liability);
    await DatabaseHelper.instance.checkAndApplyAutomaticLiabilityPayments();

    await Future.delayed(const Duration(milliseconds: 150));
    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Liability added, label created & future payments scheduled!')),
    );
  }

  Future<void> _handleSaveGoal(SavingsGoalModel goal) async {
    await DatabaseHelper.instance.insertSavingsGoal(goal);
    await Future.delayed(const Duration(milliseconds: 150));
    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Savings goal created!')));
  }

  Future<void> _handleAddFundsToGoal(int goalId, double amountToAdd, String owner, String fromPool, String goalName, String currency) async {
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
      currencyCode: currency,
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
      currencyCode: currency,
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
    final activeCurrencies = _availableCurrencies;

    Map<String, Map<String, Map<String, double>>> currencyOwnerPools = {};
    Map<String, Map<String, double>> currencyTotalPools = {};
    Map<String, Map<String, double>> currencyTotalLiquidNet = {};
    Map<String, Map<String, double>> currencyOwnerLiquidNet = {};
    Map<String, Map<String, Map<String, double>>> currencyOwnerBreakdown = {};

    for (var curr in activeCurrencies) {
      currencyOwnerPools[curr] = {};
      currencyTotalPools[curr] = {};
      currencyTotalLiquidNet[curr] = {'total': 0.0};
      currencyOwnerLiquidNet[curr] = {};
      currencyOwnerBreakdown[curr] = {};

      for (var owner in _owners) {
        currencyOwnerPools[curr]![owner] = {};
        for (var poolKey in _pools.keys) {
          currencyOwnerPools[curr]![owner]![poolKey] = 0.0;
        }
        currencyOwnerLiquidNet[curr]![owner] = 0.0;
        currencyOwnerBreakdown[curr]![owner] = {'liquidNet': 0.0};
      }
      for (var poolKey in _pools.keys) {
        currencyTotalPools[curr]![poolKey] = 0.0;
      }
    }

    double totFuture = 0;
    double totPrognosis = 0;
    Map<String, double> futureByOwner = {};
    Map<String, double> prognosisByOwnerMap = {};
    for (var owner in _owners) {
      futureByOwner[owner] = 0.0;
      prognosisByOwnerMap[owner] = 0.0;
    }

    for (var t in _transactions) {
      if (_globalSelectedOwner != null && t.owner != _globalSelectedOwner) continue;
      if (t.isConfirmed == -1) continue;

      final txDate = DateTime.tryParse(t.createdAt) ?? now;
      final isFuture = txDate.isAfter(now);
      double amount = t.type == 'income' ? t.amount : -t.amount;
      String owner = _owners.contains(t.owner) ? t.owner : (_owners.isNotEmpty ? t.owner : 'Shared');
      String curr = t.currencyCode.isNotEmpty ? t.currencyCode : (_availableCurrencies.firstOrNull ?? 'USD');

      if (!currencyTotalPools.containsKey(curr)) {
        curr = _availableCurrencies.firstOrNull ?? 'USD';
      }

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
        currencyTotalPools[curr]![t.pool] = (currencyTotalPools[curr]![t.pool] ?? 0.0) + amount;
        if (currencyOwnerPools[curr]!.containsKey(owner)) {
          currencyOwnerPools[curr]![owner]![t.pool] = (currencyOwnerPools[curr]![owner]![t.pool] ?? 0.0) + amount;
        }

        if (_liquidNetPools[t.pool] == true) {
          currencyTotalLiquidNet[curr]!['total'] = (currencyTotalLiquidNet[curr]!['total'] ?? 0.0) + amount;
          currencyOwnerLiquidNet[curr]![owner] = (currencyOwnerLiquidNet[curr]![owner] ?? 0.0) + amount;
          if (currencyOwnerBreakdown[curr]!.containsKey(owner)) {
            currencyOwnerBreakdown[curr]![owner]!['liquidNet'] = (currencyOwnerBreakdown[curr]![owner]!['liquidNet'] ?? 0.0) + amount;
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

    setState(() {
      _poolTotalsByCurrencyAndOwner = currencyOwnerPools;
      _totalPoolTotalsByCurrency = currencyTotalPools;
      _liquidNetByCurrencyAndOwner = currencyOwnerLiquidNet;
      _totalLiquidNetByCurrency = currencyTotalLiquidNet;
      _ownerBreakdownByCurrency = currencyOwnerBreakdown;

      _totalFutureFlow = totFuture;
      _futureFlowByOwner = {for (var o in _owners) o: futureByOwner[o] ?? 0.0};
      _totalPrognosis = totPrognosis;
      _prognosisByOwner = {for (var o in _owners) o: prognosisByOwnerMap[o] ?? 0.0};
    });
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
      SnackBar(content: Text('Successfully deleted $deletedCount zaznams!')),
    );
  }

  Future<void> _bulkUpdateTransactionsLabel(String oldLabel, String newLabel) async {
    int count = await DatabaseHelper.instance.bulkUpdateTransactionsLabel(oldLabel, newLabel);
    await loadData(showLoading: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully updated $count zaznams from "$oldLabel" to "$newLabel"!')),
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
        SnackBar(content: Text('Successfully imported $importedCount zaznams!')),
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
    await DatabaseHelper.instance.insertBudget(labelId, limitAmount, owner);
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaznam deleted & funds restored!')));
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
      currencyCode: tx.currencyCode,
    );
    await DatabaseHelper.instance.updateTransaction(confirmedTx);
    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaznam confirmed!')));
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
    required String currencyCode,
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
        currencyCode: currencyCode,
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
    required String fromCurrency,
    required String toCurrency,
    required double exchangeRate,
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
      currencyCode: fromCurrency,
    );

    final convertedAmount = amount * exchangeRate;
    final inbound = TransactionModel(
      createdAt: date.toIso8601String(),
      description: description.isNotEmpty ? 'Transfer in: $description' : 'Transfer in from $fromPool',
      amount: convertedAmount,
      type: 'income',
      labelId: transferLabelId,
      owner: toOwner,
      pool: toPool,
      isConfirmed: 1,
      isSavings: 0,
      currencyCode: toCurrency,
    );

    await DatabaseHelper.instance.insertTransaction(outbound);
    await DatabaseHelper.instance.insertTransaction(inbound);

    await loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Multi-currency transfer executed successfully!')));
  }

  Future<void> _addLabel(String name) async {
    if (name.isEmpty) return;
    await DatabaseHelper.instance.insertLabel(name, '#4338CA');
    await loadData();
  }

  Future<void> _updateLabel(int id, String newName, String newColor) async {
    if (newName.isEmpty) return;
    await DatabaseHelper.instance.updateLabel(id, newName, newColor);
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
    String editCurrency = tx.currencyCode.isNotEmpty ? tx.currencyCode : (_availableCurrencies.firstOrNull ?? 'USD');
    
    DateTime selectedDate = DateTime.tryParse(tx.createdAt) ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stateContext, setDialogState) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Zaznam',
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
                  Text('DATE & TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: stateContext,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (pickedDate != null) {
                              setDialogState(() => selectedDate = pickedDate);
                            }
                          },
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 14, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('MM/dd/yyyy').format(selectedDate), 
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final pickedTime = await showTimePicker(
                              context: stateContext,
                              initialTime: selectedTime,
                            );
                            if (pickedTime != null) {
                              setDialogState(() => selectedTime = pickedTime);
                            }
                          },
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 14, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                const SizedBox(width: 6),
                                Text(
                                  selectedTime.format(stateContext), 
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('CURRENCY & AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: editCurrency,
                              isDense: true,
                              isExpanded: true,
                              dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                              items: _availableCurrencies.map((c) => DropdownMenuItem(
                                value: c,
                                child: Row(
                                  children: [
                                    Text(_currencyFlags[c] ?? '💵', style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 6),
                                    Text(c, style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B))),
                                  ],
                                ),
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => editCurrency = val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1))),
                            filled: true,
                            fillColor: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Type', isDense: true, border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Income (+)')),
                      DropdownMenuItem(value: 'expense', child: Text('Expense (-)'))
                    ],
                    onChanged: (val) => type = val ?? type,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: owner,
                    dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Owner', isDense: true, border: OutlineInputBorder()),
                    items: _owners.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                    onChanged: (val) => owner = val ?? owner,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _pools.containsKey(pool) ? pool : _pools.keys.first,
                    dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Pool', isDense: true, border: OutlineInputBorder()),
                    items: _pools.keys.map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
                    onChanged: (val) => pool = val ?? pool,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedLabelId,
                    isExpanded: true,
                    dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Label', isDense: true, border: OutlineInputBorder()),
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
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController, 
                    style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Description', isDense: true, border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? tx.amount;
                final combinedDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
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
                  currencyCode: editCurrency,
                );
                await DatabaseHelper.instance.updateTransaction(updatedTx);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                await loadData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaznam updated!')));
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
    void Function(DateTime?, DateTime?) onRangeSelected,
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
      case 'smart_insights':
        return SmartInsightsCard(
          transactions: _transactions,
          labels: _labels,
          futureFlowByOwner: _futureFlowByOwner,
          prognosisByOwner: _prognosisByOwner,
          isWide: card.isWide,
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
        );
      case 'savings_goals':
        return SavingsGoalsCard(
          goals: _goals,
          labels: _labels,
          owners: _owners,
          pools: _pools.keys.toList(),
          selectedOwner: _globalSelectedOwner,
          onSaveGoal: _handleSaveGoal,
          onAddFundsToGoal: (goalId, amountToAdd, owner, fromPool, goalName, currency) {
            _handleAddFundsToGoal(goalId, amountToAdd, owner, fromPool, goalName, currency);
          },
          onDeleteGoal: _deleteSavingsGoal,
          onCompleteGoal: _completeSavingsGoal,
          isWide: card.isWide,
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
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
          onThemeChanged: (isZaz) {
            setState(() {
              _isZaznamityMode = isZaz;
            });
            if (widget.onThemeChanged != null) {
              widget.onThemeChanged!(isZaz);
            }
          },
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
            _saveCardLayoutPreferences();
          },
          onAddLabel: (name) => _addLabel(name),
          onUpdateLabel: (id, name, color) => _updateLabel(id, name, color),
          onDeleteLabel: (id) => _deleteLabel(id),
          onImportCsv: () => _importCsvFile(context),
          onDeleteBulkTransactions: _deleteBulkTransactions,
          onDeleteTransactionsByLabel: (labelId) async {
            final targetLabel = _labels.firstWhere((l) => l.id == labelId, orElse: () => LabelModel(id: labelId, name: '', color: ''));
            int count = await DatabaseHelper.instance.deleteTransactionsByLabelId(labelId);
            await loadData(showLoading: false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Successfully deleted Zaznams associated with label "${targetLabel.name}"!')),
            );
          },
          onBulkUpdateTransactionsLabel: _bulkUpdateTransactionsLabel,
          onBulkUpdateTransactionsPool: (owner, labelName, targetPool) async {
            final labelObj = _labels.firstWhere(
              (l) => l.name.toLowerCase() == labelName.toLowerCase(),
              orElse: () => _labels.first,
            );

            int count = await DatabaseHelper.instance.bulkUpdateTransactionsPoolByOwnerAndLabel(
              owner: owner,
              labelId: labelObj.id,
              targetPool: targetPool,
            );

            await loadData(showLoading: false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Successfully moved $count zaznams for "$owner" labeled "$labelName" to pool "$targetPool"!')),
            );
          },
          onLiabilityUpdated: () async {
            await loadData(showLoading: false);
            if (mounted) {
              setState(() {
                calculateMetrics();
              });
            }
          },
          isWide: card.isWide,
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
        );
      case 'metrics':
        return SummaryMetricsCard(
          owners: _owners,
          selectedOwner: _globalSelectedOwner ?? 'All Owners',
          poolTotalsByCurrencyAndOwner: _poolTotalsByCurrencyAndOwner,
          totalPoolTotalsByCurrency: _totalPoolTotalsByCurrency,
          liquidNetByCurrencyAndOwner: _liquidNetByCurrencyAndOwner,
          totalLiquidNetByCurrency: _totalLiquidNetByCurrency,
          ownerBreakdownByCurrency: _ownerBreakdownByCurrency,
          transactions: _transactions,
          isWide: card.isWide,
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
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
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
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
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
        );
      case 'future_metrics':
        return FutureMetricsCard(
          owners: _owners,
          selectedOwner: _futureMetricsSelectedOwner ?? _globalSelectedOwner,
          futureFlowByOwner: _futureFlowByOwner,
          totalFutureFlow: _totalFutureFlow,
          prognosisByOwner: _prognosisByOwner,
          totalPrognosis: _totalPrognosis,
          transactions: _transactions,
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
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
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
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
        );
      case 'new_entry':
        return NewZaznamCard(
          labels: _labels,
          pools: _pools.keys.toList(),
          owners: _owners,
          transactions: _transactions,
          selectedGlobalOwner: _globalSelectedOwner,
          isWide: card.isWide,
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
          onSubmit: (description, amount, type, labelId, owner, pool, isRecurring, frequency, dayOfMonth, excludedWeekdays, excludedMonths, repeatUntilDate, date, currencyCode) {
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
              currencyCode: currencyCode,
            );
          },
        );
      case 'transfer':
        return TransferFundsCard(
          pools: _pools.keys.toList(),
          owners: _owners,
          selectedGlobalOwner: _globalSelectedOwner,
          isWide: card.isWide,
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
          onTransfer: (fromPool, toPool, fromOwner, toOwner, amount, description, date, fromCurrency, toCurrency, exchangeRate) {
            _handleTransferFunds(
              fromPool: fromPool,
              toPool: toPool,
              fromOwner: fromOwner,
              toOwner: toOwner,
              amount: amount,
              description: description,
              date: date,
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              exchangeRate: exchangeRate,
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
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
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
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
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
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
        );
      case 'pools_analytics':
        return PoolsAnalyticsCard(
          transactions: _transactions,
          pools: _pools,
          owners: _owners,
          selectedOwner: _globalSelectedOwner,
          onOwnerChanged: (owner) => setState(() => _globalSelectedOwner = owner),
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
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
        );
      case 'calendar':
        return CalendarCard(
          transactions: _transactions,
          owners: _owners,
          selectedOwner: _calendarSelectedOwner ?? _globalSelectedOwner,
          onOwnerChanged: (owner) => setState(() => _calendarSelectedOwner = owner),
          isWide: card.isWide,
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
          historyKey: _cards.firstWhere((c) => c.id == 'history').key,
          onDateSelected: (selectedDate) {
            _jumpToHistoryForDate(selectedDate);
          },
        );
      case 'liabilities_card':
        final filteredLiabilities = _liabilities.where((item) {
          if (_globalSelectedOwner == null || _globalSelectedOwner == 'All' || _globalSelectedOwner == 'Shared') {
            return true;
          }
          return item.owner == _globalSelectedOwner || item.owner == 'Shared';
        }).toList();

        return LiabilitiesCard(
          liabilities: filteredLiabilities.map((item) => LiabilityItem(
            id: item.id.toString(),
            name: item.name,
            remainingBalance: item.remainingBalance,
            monthlyInstallment: item.monthlyInstallment,
            interestRate: item.interestRate,
            dueDay: item.dueDay ?? 1,
            owner: item.owner,
          )).toList(),
          owners: _owners,
          selectedOwner: _globalSelectedOwner,
          currencySymbol: '€',
          onAddLiability: () {},
          onSaveLiability: (item) {
            final model = LiabilityModel(
              name: item.name,
              remainingBalance: item.remainingBalance,
              monthlyInstallment: item.monthlyInstallment,
              interestRate: item.interestRate,
              dueDay: item.dueDay,
              owner: item.owner,
              lastProcessedDate: DateTime.now().toIso8601String(),
            );
            _handleSaveLiability(model);
          },
          onDeleteLiability: (liabilityId, liabilityName) async {
            await DatabaseHelper.instance.deleteLiability(int.parse(liabilityId), liabilityName);

            setState(() {
              _liabilities.removeWhere((l) => l.id.toString() == liabilityId.toString());
              _transactions.removeWhere((tx) => 
                (tx.labelName ?? '').toLowerCase().contains(liabilityName.toLowerCase()) ||
                tx.description.toLowerCase().contains(liabilityName.toLowerCase())
              );
            });
          },
          isWide: card.isWide,
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
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
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
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
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
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
          onToggleWidth: () {
            setState(() => card.isWide = !card.isWide);
            _saveCardLayoutPreferences();
          },
          onHide: () {
            setState(() => card.isVisible = false);
            _saveCardLayoutPreferences();
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showZoomOutSnapshotModal() {
    final metricsCards = _cards.where((c) => c.isVisible && ['metrics', 'smart_insights', 'future_metrics', 'liabilities_card', 'savings_goals', 'budget'].contains(c.id)).toList();
    final trendsCards = _cards.where((c) => c.isVisible && ['monthly_trend', 'trend_chart', 'savings_chart', 'pools_analytics', 'sankey_flow'].contains(c.id)).toList();
    final analyticsCards = _cards.where((c) => c.isVisible && ['label_focus', 'income_expenses_labels', 'calendar'].contains(c.id)).toList();
    final actionsCards = _cards.where((c) => c.isVisible && ['new_entry', 'transfer', 'transaction_search', 'history', 'settings'].contains(c.id)).toList();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1333),
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.fromLTRB(12, 32, 12, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.96,
          height: MediaQuery.of(context).size.height * 0.78,
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
                        'Dashboard Snapshot',
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
                      _buildTabSnapshotColumn('Metrics', metricsCards, 0),
                      const SizedBox(width: 12),
                      _buildTabSnapshotColumn('Trends', trendsCards, 1),
                      const SizedBox(width: 12),
                      _buildTabSnapshotColumn('Analytics', analyticsCards, 2),
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

  Widget _buildCardTabContent(List<CardConfig> sectionCards, double screenWidth, {bool isMetricsTab = false}) {
    final rows = _chunkCardsIntoRows(sectionCards, screenWidth);
    if (rows.isEmpty && !isMetricsTab) {
      return const Center(
        child: Text('No active cards in this tab', style: TextStyle(color: Colors.grey)),
      );
    }

    const double sidePadding = 4.0; 
    final double netWidth = screenWidth - sidePadding;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 85),
      child: Column(
        children: [
          if (isMetricsTab) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                key: _titleCardConfig.key,
                width: netWidth,
                child: TitleCard(
                  owners: _owners,
                  isWide: _titleCardConfig.isWide,
                  onToggleWidth: () => setState(() => _titleCardConfig.isWide = !_titleCardConfig.isWide),
                  onHide: () {},
                ),
              ),
            ),
          ],
          ...rows.map((rowCards) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
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

                  final bool isHighlighted = _highlightedCardId == card.id;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: rowCards.last == card ? 0 : 10,
                      ),
                      child: SizedBox(
                        key: card.key,
                        width: cardWidth,
                        child: RepaintBoundary(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isHighlighted ? const Color(0xFFA855F7) : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: _buildCardWidget(card),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
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

                          final metricsCards = _cards.where((c) => c.isVisible && ['metrics', 'smart_insights', 'liabilities_card', 'future_metrics', 'savings_goals', 'budget'].contains(c.id)).toList();
                          final trendsCards = _cards.where((c) => c.isVisible && ['monthly_trend', 'trend_chart', 'savings_chart', 'pools_analytics', 'sankey_flow'].contains(c.id)).toList();
                          final analyticsCards = _cards.where((c) => c.isVisible && ['label_focus', 'income_expenses_labels', 'calendar'].contains(c.id)).toList();
                          final actionsCards = _cards.where((c) => c.isVisible && ['new_entry', 'transfer', 'transaction_search', 'history', 'settings'].contains(c.id)).toList();

                          return TabBarView(
                            controller: _tabController,
                            children: [
                              _buildCardTabContent(metricsCards, screenWidth, isMetricsTab: true),
                              _buildCardTabContent(trendsCards, screenWidth),
                              _buildCardTabContent(analyticsCards, screenWidth),
                              _buildCardTabContent(actionsCards, screenWidth),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),

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
                        (card) {
                          setState(() => card.isVisible = !card.isVisible);
                          _saveCardLayoutPreferences();
                        },
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
                        _saveCardLayoutPreferences();
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}