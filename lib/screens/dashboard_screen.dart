import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaznamity/models/card_config.dart';
import 'package:zaznamity/models/label.dart';
import 'package:zaznamity/models/transaction_model.dart';
import 'package:zaznamity/services/database_helper.dart';
import 'package:intl/intl.dart';

import '../widgets/summary_metrics_card.dart';
import '../widgets/new_zaznam_card.dart';
import '../widgets/transfer_funds_card.dart';
import '../widgets/liquid_trend_chart_card.dart';
import '../widgets/income_expenses_by_labels_card.dart';
import '../widgets/transaction_history_card.dart';
import '../widgets/app_settings_card.dart';
import '../widgets/bottom_card_nav_bar.dart';
import '../widgets/calendar_card.dart';
import '../widgets/budget_progress_card.dart';

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

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  
  List<TransactionModel> _transactions = [];
  List<LabelModel> _labels = [];
  List<Map<String, dynamic>> _budgets = [];
  bool _isLoading = true;

  double _liquidNetTotal = 0;
  double _mathiasCash = 0;
  double _juliaCash = 0;
  double _checkingTotal = 0;
  double _cashTotal = 0;
  double _savingsTotal = 0;
  double _loansTotal = 0;
  double _futureFlowTotal = 0;
  double _prognosisTotal = 0;

  Map<String, double> _poolTotals = {};

  DateTime? _historyStartDate;
  DateTime? _historyEndDate;
  int? _historySelectedLabelId;
  String? _historySelectedOwner;

  DateTime? _labelsCardStartDate;
  DateTime? _labelsCardEndDate;
  String? _labelsCardSelectedOwner;

  List<String> _leftNavItems = ['metrics', 'budget'];
  List<String> _rightNavItems = ['history', 'settings'];

  final Map<String, bool> _pools = {
    'checking': true,
    'cash': true,
    'savings': false,
    'loan': false,
  };

  Map<String, bool> _countedPools = {
    'checking': true,
    'cash': true,
    'savings': false,
    'loan': false,
  };

  Map<String, bool> _liquidNetPools = {
    'checking': true,
    'cash': true,
    'savings': false,
    'loan': false,
  };

  Map<String, bool> _prognosisPools = {
    'cash': false,
    'savings': false,
    'loans': false,
  };

  List<String> _owners = ['Mathias', 'Julia', 'Shared'];

  late final List<CardConfig> _cards = [
    CardConfig(id: 'settings', title: 'Settings', key: GlobalKey(), isVisible: false),
    CardConfig(id: 'metrics', title: 'Metrics', key: GlobalKey()),
    CardConfig(id: 'budget', title: 'Budget Progress', key: GlobalKey()),
    CardConfig(id: 'new_entry', title: 'New Zaznam', key: GlobalKey()),
    CardConfig(id: 'transfer', title: 'Transfer Funds', key: GlobalKey()),
    CardConfig(id: 'trend_chart', title: 'Liquid Trend', key: GlobalKey()),
    CardConfig(id: 'income_expenses_labels', title: 'Label Analytics', key: GlobalKey()),
    CardConfig(id: 'calendar', title: 'Calendar', key: GlobalKey()),
    CardConfig(id: 'history', title: 'Zaznam History', key: GlobalKey()),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _labelsCardStartDate = DateTime(now.year, now.month, 1);
    _labelsCardEndDate = DateTime(now.year, now.month + 1, 0);
    _loadNavPreferences();
    loadData(showLoading: true);
  }

  Future<void> _loadNavPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final leftSaved = prefs.getStringList('leftNavItems');
      if (leftSaved != null) _leftNavItems = leftSaved;
      final rightSaved = prefs.getStringList('rightNavItems');
      if (rightSaved != null) _rightNavItems = rightSaved;
    });
  }

  void _scrollToCard(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void showCardStackManager(
    BuildContext context,
    List<CardConfig> cards,
    Function(CardConfig) onToggleVisibility,
    Function(GlobalKey) onScrollTo,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => StatefulBuilder(
        builder: (stateContext, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.6,
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
                child: ReorderableListView.builder(
                  itemCount: cards.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setModalState(() {
                      final item = cards.removeAt(oldIndex);
                      cards.insert(newIndex, item);
                    });
                    setState(() {});
                  },
                  itemBuilder: (itemContext, index) {
                    final card = cards[index];
                    return ListTile(
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
                            },
                          ),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(modalContext);
                        setState(() {
                          card.isVisible = true;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          onScrollTo(card.key);
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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

    setState(() {
      _transactions = txs;
      _labels = lbls;
      _budgets = bdgs;
      calculateMetrics();
      _isLoading = false;
    });
  }

  void calculateMetrics() {
    double mCash = 0, jCash = 0, chk = 0, csh = 0, sav = 0, loans = 0, fut = 0, prog = 0, liquidNet = 0;
    final now = DateTime.now();

    Map<String, double> pTotals = {};
    for (var poolKey in _pools.keys) {
      pTotals[poolKey] = 0;
    }

    for (var t in _transactions) {
      if (t.isConfirmed != 1) continue;

      final txDate = DateTime.tryParse(t.createdAt) ?? now;
      final isFuture = txDate.isAfter(now);

      double amount = t.type == 'income' ? t.amount : -t.amount;

      if (isFuture) {
        fut += amount;
      } else {
        if (pTotals.containsKey(t.pool)) {
          pTotals[t.pool] = (pTotals[t.pool] ?? 0) + amount;
        } else {
          pTotals[t.pool] = amount;
        }

        if (t.pool == 'checking') {
          chk += amount;
        } else if (t.pool == 'cash') {
          csh += amount;
        } else if (t.pool == 'savings') {
          sav += amount;
        } else if (t.pool == 'loans' || t.pool == 'loan') {
          loans += amount;
        }

        if (_countedPools[t.pool] == true) {
          if (t.owner == 'Mathias') {
            mCash += amount;
          } else if (t.owner == 'Julia') {
            jCash += amount;
          }
        }
      }

      if (_liquidNetPools[t.pool] == true && !isFuture) {
        liquidNet += amount;
      }

      bool includeInProg = t.pool == 'checking';
      if (t.pool == 'cash' && (_prognosisPools['cash'] == true)) includeInProg = true;
      if (t.pool == 'savings' && (_prognosisPools['savings'] == true)) includeInProg = true;
      if ((t.pool == 'loans' || t.pool == 'loan') && (_prognosisPools['loans'] == true)) includeInProg = true;

      if (includeInProg) {
        prog += amount;
      }
    }

    _mathiasCash = mCash;
    _juliaCash = jCash;
    _liquidNetTotal = liquidNet;
    _checkingTotal = chk;
    _cashTotal = csh;
    _savingsTotal = sav;
    _loansTotal = loans;
    _futureFlowTotal = fut;
    _prognosisTotal = prog;
    _poolTotals = pTotals;
  }

  Future<void> _addBudget(int labelId, double limitAmount) async {
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
    await DatabaseHelper.instance.deleteTransaction(id);
    await loadData();
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
    required DateTime? repeatUntilDate,
    required DateTime date,
  }) async {
    if (amount <= 0) return;

    List<DateTime> datesToGenerate = [date];

    if (isRecurring) {
      final endDate = repeatUntilDate ?? date.add(const Duration(days: 365));
      DateTime current = date;

      while (true) {
        if (frequency == 'Weekly') {
          current = current.add(const Duration(days: 7));
        } else if (frequency == 'Yearly') {
          current = DateTime(current.year + 1, current.month, current.day, current.hour, current.minute);
        } else {
          current = DateTime(current.year, current.month + 1, dayOfMonth, current.hour, current.minute);
        }

        if (current.isAfter(endDate)) {
          break;
        }
        datesToGenerate.add(current);
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

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()).toUpperCase();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final screenWidth = constraints.maxWidth;
                            return Wrap(
                              spacing: 20,
                              runSpacing: 20,
                              children: _cards.where((card) => card.isVisible).map((card) {
                                Widget cardWidget;
                                switch (card.id) {
                                  case 'settings':
                                    cardWidget = AppSettingsCard(
                                      initialPools: _countedPools,
                                      initialLiquidNetPools: _liquidNetPools,
                                      initialPrognosisPools: _prognosisPools,
                                      initialOwners: _owners,
                                      initialLeftNavItems: _leftNavItems,
                                      initialRightNavItems: _rightNavItems,
                                      labels: _labels,
                                      cards: _cards,
                                      onThemeChanged: widget.onThemeChanged,
                                      onPinSettingsChanged: widget.onPinSettingsChanged,
                                      onSavePools: (updatedPools) {
                                        setState(() {
                                          _countedPools = updatedPools;
                                          calculateMetrics();
                                        });
                                      },
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
                                      isWide: card.isWide,
                                      onToggleWidth: () => setState(() => card.isWide = !card.isWide),
                                      onHide: () => setState(() => card.isVisible = false),
                                    );
                                    break;
                                  case 'metrics':
                                    cardWidget = SummaryMetricsCard(
                                      mathiasCash: _mathiasCash,
                                      juliaCash: _juliaCash,
                                      liquidNetTotal: _liquidNetTotal,
                                      poolTotals: _poolTotals,
                                      futureFlowTotal: _futureFlowTotal,
                                      prognosisTotal: _prognosisTotal,
                                      isWide: card.isWide,
                                      onToggleWidth: () => setState(() => card.isWide = !card.isWide),
                                      onHide: () => setState(() => card.isVisible = false),
                                    );
                                    break;
                                  case 'budget':
                                    cardWidget = BudgetProgressCard(
                                      budgets: _budgets,
                                      transactions: _transactions,
                                      labels: _labels,
                                      onAddBudget: _addBudget,
                                      onDeleteBudget: _deleteBudget,
                                      isWide: card.isWide,
                                      onToggleWidth: () => setState(() => card.isWide = !card.isWide),
                                      onHide: () => setState(() => card.isVisible = false),
                                    );
                                    break;
                                  case 'new_entry':
                                    cardWidget = NewZaznamCard(
                                      labels: _labels,
                                      pools: _pools.keys.toList(),
                                      isWide: card.isWide,
                                      onToggleWidth: () => setState(() => card.isWide = !card.isWide),
                                      onHide: () => setState(() => card.isVisible = false),
                                      onSubmit: (description, amount, type, labelId, owner, pool, isRecurring, frequency, dayOfMonth, repeatUntilDate, date) {
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
                                          repeatUntilDate: repeatUntilDate,
                                          date: date,
                                        );
                                      },
                                    );
                                    break;
                                  case 'transfer':
                                    cardWidget = TransferFundsCard(
                                      pools: _pools.keys.toList(),
                                      owners: _owners,
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
                                    break;
                                  case 'trend_chart':
                                    cardWidget = LiquidTrendChartCard(
                                      transactions: _transactions,
                                      liquidNetPools: _liquidNetPools,
                                      isWide: card.isWide,
                                      onToggleWidth: () => setState(() => card.isWide = !card.isWide),
                                      onHide: () => setState(() => card.isVisible = false),
                                    );
                                    break;
                                  case 'calendar':
                                    cardWidget = CalendarCard(
                                      transactions: _transactions,
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
                                    break;
                                  case 'income_expenses_labels':
                                    cardWidget = IncomeExpensesByLabelsCard(
                                      transactions: _transactions,
                                      labels: _labels,
                                      startDate: _labelsCardStartDate,
                                      endDate: _labelsCardEndDate,
                                      selectedOwner: _labelsCardSelectedOwner,
                                      onSelectStartDate: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _labelsCardStartDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2030),
                                        );
                                        if (picked != null) setState(() => _labelsCardStartDate = picked);
                                      },
                                      onSelectEndDate: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _labelsCardEndDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2030),
                                        );
                                        if (picked != null) setState(() => _labelsCardEndDate = picked);
                                      },
                                      onOwnerChanged: (owner) => setState(() => _labelsCardSelectedOwner = owner),
                                      onClearDateFilter: () => setState(() {
                                        _labelsCardStartDate = null;
                                        _labelsCardEndDate = null;
                                      }),
                                      isWide: card.isWide,
                                      onToggleWidth: () => setState(() => card.isWide = !card.isWide),
                                      onHide: () => setState(() => card.isVisible = false),
                                    );
                                    break;
                                  case 'history':
                                    cardWidget = TransactionHistoryCard(
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
                                        if (_historySelectedOwner != null) {
                                          if (tx.owner != _historySelectedOwner) return false;
                                        }
                                        return true;
                                      }).toList(),
                                      labels: _labels,
                                      startDate: _historyStartDate,
                                      endDate: _historyEndDate,
                                      selectedLabelId: _historySelectedLabelId,
                                      selectedOwner: _historySelectedOwner,
                                      onSelectStartDate: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _historyStartDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2030),
                                        );
                                        if (picked != null) setState(() => _historyStartDate = picked);
                                      },
                                      onSelectEndDate: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _historyEndDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2030),
                                        );
                                        if (picked != null) setState(() => _historyEndDate = picked);
                                      },
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
                                    break;
                                  default:
                                    cardWidget = const SizedBox.shrink();
                                }

                                double cardWidth = screenWidth;
                                if (card.isWide) {
                                  cardWidth = screenWidth;
                                } else {
                                  if (screenWidth >= 1200) {
                                    cardWidth = (screenWidth - 40) / 3;
                                  } else if (screenWidth >= 768) {
                                    cardWidth = (screenWidth - 20) / 2;
                                  } else {
                                    cardWidth = screenWidth;
                                  }
                                }

                                return SizedBox(
                                  key: card.key,
                                  width: cardWidth,
                                  child: cardWidget,
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Align(
                    alignment: Alignment.center,
                    child: BottomCardNavBar(
                      cards: _cards,
                      leftItems: _leftNavItems,
                      rightItems: _rightNavItems,
                      onOpenManager: () => showCardStackManager(
                        context,
                        _cards,
                        (card) => setState(() => card.isVisible = !card.isVisible),
                        (key) => _scrollToCard(key),
                      ),
                      onQuickAdd: () {
                        final index = _cards.indexWhere((c) => c.id == 'new_entry');
                        if (index != -1) {
                          setState(() {
                            _cards[index].isVisible = true;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _scrollToCard(_cards[index].key);
                          });
                        }
                      },
                      onOpenSettings: () {
                        final index = _cards.indexWhere((c) => c.id == 'settings');
                        if (index != -1) {
                          setState(() {
                            _cards[index].isVisible = true;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _scrollToCard(_cards[index].key);
                          });
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