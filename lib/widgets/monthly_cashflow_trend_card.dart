// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/label.dart';

class MonthlyCashflowTrendCard extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<LabelModel> labels;
  final List<String> owners;
  final List<String> pools;
  final String? selectedOwner;
  final String? selectedPool;
  final Function(String?)? onOwnerChanged;
  final Function(String?)? onPoolChanged;
  final Function(String monthKey, String type, String? owner)? onJumpToHistory;

  const MonthlyCashflowTrendCard({
    super.key,
    required this.transactions,
    this.labels = const [],
    required this.owners,
    required this.pools,
    this.selectedOwner,
    this.selectedPool,
    this.onOwnerChanged,
    this.onPoolChanged,
    this.onJumpToHistory,
  });

  @override
  State<MonthlyCashflowTrendCard> createState() => _MonthlyCashflowTrendCardState();
}

class _MonthlyCashflowTrendCardState extends State<MonthlyCashflowTrendCard> {
  String _selectedTimeframe = 'All time';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  Set<int> _selectedLabelIds = {}; // Empty means All Labels
  bool _showNetTrendLine = true;
  bool _excludeTransfers = true;
  bool _isZaznamityMode = true;
  bool _isCollapsed = false;
  bool _showYearOverYear = false;
  String _primaryCurrency = 'USD';

  final ScrollController _chartScrollController = ScrollController();

  List<BarChartGroupData> _cachedBarGroups = [];
  List<FlSpot> _cachedNetSpots = [];
  List<FlSpot> _cachedRollingNetSpots = [];
  List<String> _cachedSortedKeys = [];
  List<String> _cachedMonthLabels = [];
  Map<String, Map<String, double>> _cachedMonthlyRawData = {};
  Set<String> _cachedAnomalyMonths = {};
  String? _cachedBestMonth;
  String? _cachedWorstMonth;
  double _cachedAvgExpense = 0.0;
  double _cachedAvgNet = 0.0;
  double _cachedMaxY = 1000.0;
  double _cachedMinY = -1000.0;

  String? _lastCacheKey;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _chartScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final collapsed = prefs.getBool('set_monthlyCashflow_collapsed') ?? false;
    final timeframe = prefs.getString('set_cashFlow_range') ?? 'All time';
    final excludeTr = prefs.getBool('exclude_transfers_insights') ?? true;
    final primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';
    final newZaznamityMode = (savedTheme == 'zaznamity');

    final savedLabelIdsList = prefs.getStringList('monthly_cashflow_selected_labels');
    Set<int> loadedLabelIds = {};
    if (savedLabelIdsList != null) {
      final validIds = widget.labels.map((l) => l.id).toSet();
      loadedLabelIds = savedLabelIdsList
          .map((idStr) => int.tryParse(idStr))
          .where((id) => id != null && validIds.contains(id))
          .cast<int>()
          .toSet();
    }

    if (mounted) {
      setState(() {
        _selectedTimeframe = timeframe;
        _excludeTransfers = excludeTr;
        _isZaznamityMode = newZaznamityMode;
        _isCollapsed = collapsed;
        _primaryCurrency = primaryCurrency;
        if (savedLabelIdsList != null) {
          _selectedLabelIds = loadedLabelIds;
        }
      });
    }
  }

  Future<void> _saveTimeframe(String timeframe) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('set_cashFlow_range', timeframe);
    setState(() {
      _selectedTimeframe = timeframe;
    });
  }

  Future<void> _saveLabelPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final listToSave = _selectedLabelIds.map((id) => id.toString()).toList();
    await prefs.setStringList('monthly_cashflow_selected_labels', listToSave);
  }

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': 
      case 'CNY': return '¥';
      case 'CAD': return 'C\$';
      case 'AUD': return 'A\$';
      case 'HKD': return 'HK\$';
      case 'SGD': return 'S\$';
      case 'CZK': return 'Kč';
      case 'HUF': return 'Ft';
      case 'PLN': return 'zł';
      case 'CHF': return 'CHF';
      case 'RUB': return '₽';
      case 'BRL': return 'R\$';
      case 'MXN': 
      case 'CLP': 
      case 'COP': return '\$';
      default: return '\$';
    }
  }

  String _formatCurrency(double amount, {bool compact = false}) {
    final symbol = _getCurrencySymbol(_primaryCurrency).trim();
    const trailingSymbols = ['€', 'Ft', 'Kč', 'zł', 'CHF'];
    bool isTrailing = trailingSymbols.any((s) => symbol.toLowerCase() == s.toLowerCase());

    String formattedNumber;
    if (compact) {
      formattedNumber = NumberFormat.compact(locale: 'en_US').format(amount);
    } else {
      formattedNumber = NumberFormat('#,##0.00', 'en_US').format(amount);
    }

    if (isTrailing) {
      return '$formattedNumber $symbol';
    } else {
      return '$symbol$formattedNumber';
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chartScrollController.hasClients) {
        _chartScrollController.jumpTo(_chartScrollController.position.maxScrollExtent);
      }
    });
  }

  void _showCashFlowInfoModal(BuildContext context) {
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
                  'Cash Flow Trend',
                  style: TextStyle(
                    color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              'Cash Flow Trend provides insights into your spending patterns over your selected timeframe.\n\n'
              '• Filter by pool, timeframe, or multi-select labels.\n'
              '• The chart features an emphasized zero baseline, nice rounded axis steps, and horizontal scrolling starting at the latest month.\n'
              '• Anomalies are flagged with warning borders based on leave-one-out median analysis.\n'
              '• Current month pacing shows your progress so far compared to your usual pace and projected month-end figures.\n'
              '• Dashed reference lines show average expenses and net cash flow.\n'
              '• Badges indicate your best and worst months, alongside a rolling 3-month net average line.\n\n',
              style: TextStyle(
                fontSize: 13,
                color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569),
                height: 1.4,
              ),
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
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
    await prefs.setBool('set_monthlyCashflow_collapsed', _isCollapsed);
    if (!_isCollapsed) {
      _scrollToLatest();
    }
  }

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: (_customStartDate != null && _customEndDate != null)
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 90)), end: DateTime.now()),
      builder: (context, child) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 1.0,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: child!,
              ),
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      await _saveTimeframe('Custom Range');
      _scrollToLatest();
    }
  }

  void _showLabelsCheckmarkModal(BuildContext context) {
    Set<int> tempSelectedIds = _selectedLabelIds.isEmpty 
        ? widget.labels.map((l) => l.id).toSet() 
        : Set.from(_selectedLabelIds);

    showModalBottomSheet(
      context: context,
      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool allSelected = tempSelectedIds.length == widget.labels.length;

            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Labels',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempSelectedIds = widget.labels.map((l) => l.id).toSet();
                              });
                            },
                            child: const Text('Select All', style: TextStyle(color: Color(0xFFA855F7))),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempSelectedIds.clear();
                              });
                            },
                            child: const Text('Clear All', style: TextStyle(color: Color(0xFFF87171))),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  CheckboxListTile(
                    title: Text(
                      'All Labels',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    value: allSelected,
                    activeColor: const Color(0xFFA855F7),
                    onChanged: (bool? value) {
                      setModalState(() {
                        if (value == true) {
                          tempSelectedIds = widget.labels.map((l) => l.id).toSet();
                        } else {
                          tempSelectedIds.clear();
                        }
                      });
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.labels.length,
                      itemBuilder: (context, index) {
                        final label = widget.labels[index];
                        final isChecked = tempSelectedIds.contains(label.id);

                        return CheckboxListTile(
                          title: Text(
                            label.name,
                            style: TextStyle(
                              color: _isZaznamityMode ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                          value: isChecked,
                          activeColor: const Color(0xFFA855F7),
                          onChanged: (bool? value) {
                            setModalState(() {
                              if (value == true) {
                                tempSelectedIds.add(label.id);
                              } else {
                                tempSelectedIds.remove(label.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          if (tempSelectedIds.isEmpty || tempSelectedIds.length == widget.labels.length) {
                            _selectedLabelIds.clear();
                          } else {
                            _selectedLabelIds = tempSelectedIds;
                          }
                        });
                        _saveLabelPrefs();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getCacheKey() {
    final sortedLabels = _selectedLabelIds.toList()..sort();
    final txSig = widget.transactions
        .map((t) => '${t.id}:${t.amount}:${t.createdAt}:${t.isConfirmed}:${t.type}:${t.labelId}:${t.pool}')
        .join('|');
    return '$txSig|${widget.selectedOwner}|${widget.selectedPool}|$_selectedTimeframe|$_excludeTransfers|$_customStartDate|$_customEndDate|${sortedLabels.join(",")}|$_showYearOverYear|$_primaryCurrency';
  }

  bool _isTransferTransaction(TransactionModel tx) {
    if (tx.isSavings == 1) return true;
    final lowerDesc = tx.description.toLowerCase();
    if (lowerDesc.startsWith('withdrawal from') || lowerDesc.startsWith('deposit into')) {
      return true;
    }
    if (widget.labels.isNotEmpty) {
      final matchLbl = widget.labels.where((l) => l.id == tx.labelId).firstOrNull;
      if (matchLbl != null) {
        final lName = matchLbl.name.toLowerCase();
        if (lName == 'transfer' || lName == 'goal' || lName == 'goals' || lName == 'goalssavings') {
          return true;
        }
      }
    }
    return false;
  }

  double _median(List<double> list) {
    if (list.isEmpty) return 0.0;
    final sorted = List<double>.from(list)..sort();
    int middle = sorted.length ~/ 2;
    if (sorted.length % 2 == 1) {
      return sorted[middle];
    } else {
      return (sorted[middle - 1] + sorted[middle]) / 2.0;
    }
  }

  double _niceStep(double rawRange) {
    if (rawRange <= 0) return 1.0;
    final roughStep = rawRange / 5.0;
    final magnitude = math.pow(10, (math.log(roughStep) / math.ln10).floor()).toDouble();
    final residual = roughStep / magnitude;

    double niceResidual;
    if (residual <= 1.0) {
      niceResidual = 1.0;
    } else if (residual <= 2.0) {
      niceResidual = 2.0;
    } else if (residual <= 5.0) {
      niceResidual = 5.0;
    } else {
      niceResidual = 10.0;
    }
    return niceResidual * magnitude;
  }

  void _computeChartDataIfNeeded() {
    final currentKey = _getCacheKey();
    if (_lastCacheKey == currentKey) {
      return;
    }

    final now = DateTime.now();

    final filteredTxs = widget.transactions.where((tx) {
      if (tx.isConfirmed != 1) return false;

      if (_excludeTransfers && _isTransferTransaction(tx)) {
        return false;
      }

      if (_selectedLabelIds.isNotEmpty && !_selectedLabelIds.contains(tx.labelId)) {
        return false;
      }

      if (widget.selectedOwner != null && widget.selectedOwner!.isNotEmpty && tx.owner != widget.selectedOwner) {
        return false;
      }
      if (widget.selectedPool != null && widget.selectedPool!.isNotEmpty) {
        if (tx.pool.toLowerCase() != widget.selectedPool!.toLowerCase()) {
          return false;
        }
      }
      final txDate = DateTime.tryParse(tx.createdAt);
      if (txDate == null) return false;

      if (_selectedTimeframe == 'This Year') {
        if (txDate.year != now.year) return false;
      } else if (_selectedTimeframe == 'Last 6 Months') {
        final cutoff = DateTime(now.year, now.month - 5, 1);
        if (txDate.isBefore(cutoff)) return false;
      } else if (_selectedTimeframe == 'Last 12 Months') {
        final cutoff = DateTime(now.year, now.month - 11, 1);
        if (txDate.isBefore(cutoff)) return false;
      } else if (_selectedTimeframe == '90 Days') {
        final cutoff = DateTime(now.year, now.month - 3, now.day);
        if (txDate.isBefore(cutoff)) return false;
      } else if (_selectedTimeframe == 'Current Month') {
        if (txDate.year != now.year || txDate.month != now.month) return false;
      } else if (_selectedTimeframe == 'Last 30 Days') {
        final cutoff = DateTime(now.year, now.month - 1, now.day);
        if (txDate.isBefore(cutoff)) return false;
      } else if (_selectedTimeframe == 'Custom Range') {
        if (_customStartDate != null && txDate.isBefore(_customStartDate!)) return false;
        if (_customEndDate != null && txDate.isAfter(_customEndDate!)) return false;
      }
      return true;
    }).toList();

    final Map<String, Map<String, double>> monthlyData = {};

    for (var tx in filteredTxs) {
      final dt = DateTime.tryParse(tx.createdAt);
      if (dt == null) continue;
      final key = DateFormat('yyyy-MM').format(dt);
      
      monthlyData.putIfAbsent(key, () => {'income': 0.0, 'expense': 0.0});
      if (tx.type == 'income') {
        monthlyData[key]!['income'] = (monthlyData[key]!['income'] ?? 0) + tx.amount;
      } else if (tx.type == 'expense') {
        monthlyData[key]!['expense'] = (monthlyData[key]!['expense'] ?? 0) + tx.amount;
      }
    }

    final sortedKeys = monthlyData.keys.toList()..sort();

    List<BarChartGroupData> barGroups = [];
    List<FlSpot> netSpots = [];
    List<FlSpot> rollingNetSpots = [];
    List<String> monthLabels = [];

    double maxY = 1000.0;
    double minY = -1000.0;
    double totalExpenseSum = 0.0;
    double totalNetSum = 0.0;

    for (int i = 0; i < sortedKeys.length; i++) {
      String mKey = sortedKeys[i];
      double inc = monthlyData[mKey]!['income'] ?? 0.0;
      double exp = monthlyData[mKey]!['expense'] ?? 0.0;
      double net = inc - exp;

      totalExpenseSum += exp;
      totalNetSum += net;

      if (inc > maxY) maxY = inc;
      if (-exp < minY) minY = -exp;
      if (net > maxY) maxY = net;
      if (net < minY) minY = net;

      DateTime dt = DateTime.parse('$mKey-01');
      monthLabels.add(DateFormat('MMM').format(dt));

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: inc,
              fromY: -exp,
              color: Colors.transparent,
              width: 14,
              rodStackItems: [
                BarChartRodStackItem(-exp, 0, const Color(0xFFEF4444)),
                BarChartRodStackItem(0, inc, const Color(0xFF10B981)),
              ],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3), bottom: Radius.circular(3)),
            ),
          ],
        ),
      );

      netSpots.add(FlSpot(i.toDouble(), net));
    }

    // Rolling 3-month net average calculation
    for (int i = 0; i < sortedKeys.length; i++) {
      int startIdx = math.max(0, i - 2);
      double sum = 0;
      for (int j = startIdx; j <= i; j++) {
        double inc = monthlyData[sortedKeys[j]]!['income'] ?? 0.0;
        double exp = monthlyData[sortedKeys[j]]!['expense'] ?? 0.0;
        sum += (inc - exp);
      }
      double rollingAvg = sum / (i - startIdx + 1);
      rollingNetSpots.add(FlSpot(i.toDouble(), rollingAvg));
      if (rollingAvg > maxY) maxY = rollingAvg;
      if (rollingAvg < minY) minY = rollingAvg;
    }

    double avgExpense = sortedKeys.isNotEmpty ? totalExpenseSum / sortedKeys.length : 0.0;
    double avgNet = sortedKeys.isNotEmpty ? totalNetSum / sortedKeys.length : 0.0;

    // Anomaly Detection against leave-one-out median
    Set<String> anomalyMonths = {};
    if (sortedKeys.length >= 3) {
      List<double> expenses = sortedKeys.map((k) => monthlyData[k]!['expense'] ?? 0.0).toList();
      double medianExpense = _median(expenses);
      double medianAbsDev = _median(expenses.map((e) => (e - medianExpense).abs()).toList());
      double threshold = math.max(200.0, medianAbsDev * 2.5);

      for (int i = 0; i < sortedKeys.length; i++) {
        List<double> leaveOneOut = List.from(expenses)..removeAt(i);
        double looMedian = _median(leaveOneOut);
        if ((expenses[i] - looMedian).abs() > threshold && expenses[i] > medianExpense) {
          anomalyMonths.add(sortedKeys[i]);
          barGroups[i] = barGroups[i].copyWith(
            barRods: barGroups[i].barRods.map((rod) {
              return rod.copyWith(
                borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2),
              );
            }).toList(),
          );
        }
      }
    }

    // Best and Worst months by Net
    String? bestMonthKey;
    String? worstMonthKey;
    double maxNetVal = -double.infinity;
    double minNetVal = double.infinity;
    for (var k in sortedKeys) {
      double net = (monthlyData[k]!['income'] ?? 0.0) - (monthlyData[k]!['expense'] ?? 0.0);
      if (net > maxNetVal) {
        maxNetVal = net;
        bestMonthKey = k;
      }
      if (net < minNetVal) {
        minNetVal = net;
        worstMonthKey = k;
      }
    }

    List<String> computedSortedKeys = List.from(sortedKeys);

    // Forecast for complete months
    final currentMonthKey = DateFormat('yyyy-MM').format(now);
    final completeMonthKeys = sortedKeys.where((k) => k != currentMonthKey).toList();

    if (completeMonthKeys.length >= 3) {
      final recentKeys = completeMonthKeys.sublist(completeMonthKeys.length - 3);
      final incList = recentKeys.map((k) => monthlyData[k]!['income'] ?? 0.0).toList();
      final expList = recentKeys.map((k) => monthlyData[k]!['expense'] ?? 0.0).toList();

      double forecastInc = _median(incList);
      double forecastExp = _median(expList);
      double forecastNet = forecastInc - forecastExp;

      if (forecastInc > maxY) maxY = forecastInc;
      if (-forecastExp < minY) minY = -forecastExp;
      if (forecastNet > maxY) maxY = forecastNet;
      if (forecastNet < minY) minY = forecastNet;

      int forecastIndex = computedSortedKeys.length;
      
      try {
        DateTime lastDt = DateTime.parse('${computedSortedKeys.last}-01');
        DateTime nextDt = DateTime(lastDt.year, lastDt.month + 1, 1);
        monthLabels.add(DateFormat('MMM').format(nextDt));
      } catch (_) {
        monthLabels.add('Next');
      }

      monthlyData['Forecast'] = {'income': forecastInc, 'expense': forecastExp};

      barGroups.add(
        BarChartGroupData(
          x: forecastIndex,
          barRods: [
            BarChartRodData(
              toY: forecastInc,
              fromY: -forecastExp,
              color: Colors.transparent,
              width: 14,
              rodStackItems: [
                BarChartRodStackItem(-forecastExp, 0, const Color(0xFF9333EA).withValues(alpha: 0.5)),
                BarChartRodStackItem(0, forecastInc, const Color(0xFFA855F7).withValues(alpha: 0.5)),
              ],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3), bottom: Radius.circular(3)),
            ),
          ],
        ),
      );

      netSpots.add(FlSpot(forecastIndex.toDouble(), forecastNet));
      computedSortedKeys.add('Forecast');
    }

    _cachedBarGroups = barGroups;
    _cachedNetSpots = netSpots;
    _cachedRollingNetSpots = rollingNetSpots;
    _cachedSortedKeys = computedSortedKeys;
    _cachedMonthLabels = monthLabels;
    _cachedMonthlyRawData = monthlyData;
    _cachedAnomalyMonths = anomalyMonths;
    _cachedBestMonth = bestMonthKey;
    _cachedWorstMonth = worstMonthKey;
    _cachedAvgExpense = avgExpense;
    _cachedAvgNet = avgNet;
    _cachedMaxY = maxY;
    _cachedMinY = minY;

    _lastCacheKey = currentKey;
  }

  @override
  Widget build(BuildContext context) {
    _computeChartDataIfNeeded();

    final validPoolValue = (widget.selectedPool != null && widget.pools.contains(widget.selectedPool))
        ? widget.selectedPool
        : null;

    const availableTimeframes = [
      'All time',
      'Current Month',
      'Last 30 Days',
      'Last 6 Months',
      '90 Days',
      'This Year',
      'Last 12 Months',
      'Custom Range'
    ];
    final validTimeframeValue = availableTimeframes.contains(_selectedTimeframe)
        ? _selectedTimeframe
        : 'All time';

    String labelButtonText = 'All Labels';
    if (_selectedLabelIds.length == 1) {
      final singleLabel = widget.labels.where((l) => l.id == _selectedLabelIds.first).firstOrNull;
      labelButtonText = singleLabel?.name ?? '1 Selected';
    } else if (_selectedLabelIds.length > 1) {
      labelButtonText = '${_selectedLabelIds.length} Selected';
    }

    // Current month pacing calculations
    final now = DateTime.now();
    final currentMonthKey = DateFormat('yyyy-MM').format(now);
    final currentMonthData = _cachedMonthlyRawData[currentMonthKey];
    double currentMonthExpenseSoFar = currentMonthData?['expense'] ?? 0.0;
    int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    double pacingProjectedExpense = (now.day > 0) ? (currentMonthExpenseSoFar / now.day) * daysInMonth : 0.0;
    double usualExpenseMedian = _cachedAvgExpense;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 32;
        final double boxWidth = (fullWidth - 12) / 2;
        final double columnWidth = 44.0;
        final double chartWidth = math.max(fullWidth, _cachedSortedKeys.length * columnWidth);

        return Container(
          padding: EdgeInsets.all(_isCollapsed ? 12 : 16),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'CASH FLOW TREND',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.info_outline, size: 14, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey),
                          onPressed: () => _showCashFlowInfoModal(context),
                          tooltip: 'Cash Flow Trend',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ), 
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_cachedSortedKeys.length > 12) ...[
                        IconButton(
                          icon: Icon(
                            Icons.compare_arrows_rounded,
                            size: 18,
                            color: _showYearOverYear ? const Color(0xFFA855F7) : Colors.grey,
                          ),
                          onPressed: () => setState(() => _showYearOverYear = !_showYearOverYear),
                          tooltip: 'Year-over-Year Toggle',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ],
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
                          onPressed: _toggleCollapse,
                          icon: Icon(
                            _isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                            size: 16,
                          ),
                          tooltip: _isCollapsed ? 'Expand' : 'Collapse',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!_isCollapsed) ...[
                const SizedBox(height: 12),

                // Filters row 1: Pool & Date Selector
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
                            Icon(Icons.account_balance_wallet_outlined, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: validPoolValue,
                                  isDense: true,
                                  isExpanded: true,
                                  dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                  hint: Text('All Pools', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B))),
                                  items: [
                                    DropdownMenuItem<String>(value: null, child: Text('All Pools', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                                    ...widget.pools.map((p) => DropdownMenuItem<String>(value: p, child: Text(p.toUpperCase(), style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
                                  ],
                                  onChanged: widget.onPoolChanged,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                            Icon(Icons.calendar_today_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: validTimeframeValue,
                                  isDense: true,
                                  isExpanded: true,
                                  dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                                  items: availableTimeframes
                                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))))
                                      .toList(),
                                  onChanged: (val) async {
                                    if (val == 'Custom Range') {
                                      await _pickCustomDateRange(context);
                                    } else if (val != null) {
                                      setState(() {
                                        _customStartDate = null;
                                        _customEndDate = null;
                                      });
                                      await _saveTimeframe(val);
                                      _scrollToLatest();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filters row 2: Labels selector modal & Net Trend Line toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: boxWidth,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showLabelsCheckmarkModal(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                children: [
                                  Icon(Icons.label_outline_rounded, size: 16, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      labelButtonText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _isZaznamityMode ? Colors.white : const Color(0xFF334155),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down, size: 18, color: _isZaznamityMode ? Colors.white70 : Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: boxWidth,
                      child: InkWell(
                        onTap: () => setState(() => _showNetTrendLine = !_showNetTrendLine),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: _showNetTrendLine
                                ? (_isZaznamityMode ? const Color(0xFFA855F7).withValues(alpha: 0.25) : const Color(0xFF582F95).withValues(alpha: 0.15))
                                : (_isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _showNetTrendLine
                                  ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                  : (_isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.show_chart_rounded,
                                size: 15,
                                color: _showNetTrendLine
                                    ? (_isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))
                                    : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _showNetTrendLine ? 'Net Line: On' : 'Net Line: Off',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _showNetTrendLine
                                      ? (_isZaznamityMode ? Colors.white : const Color(0xFF334155))
                                      : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Current Month Pacing Banner (Two-row format as requested)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.speed_rounded, size: 18, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pacing (Month ${now.day}/$daysInMonth) : ${_formatCurrency(currentMonthExpenseSoFar, compact: true)} spent.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Projected: ${_formatCurrency(pacingProjectedExpense, compact: true)} (Usual ${_formatCurrency(usualExpenseMedian, compact: true)})',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (_selectedTimeframe == 'Custom Range' && _customStartDate != null && _customEndDate != null) ...[
                  Container(
                    width: double.infinity,
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Range: ${DateFormat('MMM dd, yyyy').format(_customStartDate!)} - ${DateFormat('MMM dd, yyyy').format(_customEndDate!)}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF334155)),
                        ),
                        InkWell(
                          onTap: () => _pickCustomDateRange(context),
                          child: Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                _cachedSortedKeys.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Text('No transaction history found for this view.', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontSize: 12)),
                        ),
                      )
                    : SingleChildScrollView(
                        controller: _chartScrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartWidth,
                          height: 310,
                          child: Stack(
                            children: [
                              BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: _cachedMaxY * 1.25,
                                  minY: _cachedMinY * 1.25,
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipColor: (_) => Colors.transparent,
                                      tooltipBorder: const BorderSide(color: Colors.transparent),
                                      getTooltipItem: (_, __, ___, ____) => null,
                                    ),
                                    touchCallback: (FlTouchEvent event, barTouchResponse) {
                                      if (event is FlTapUpEvent &&
                                          barTouchResponse != null &&
                                          barTouchResponse.spot != null) {
                                        final groupIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                                        if (groupIndex >= 0 && groupIndex < _cachedSortedKeys.length) {
                                          final monthKey = _cachedSortedKeys[groupIndex];
                                          final monthLabel = _cachedMonthLabels[groupIndex];
                                          final data = _cachedMonthlyRawData[monthKey] ?? {'income': 0.0, 'expense': 0.0};
                                          final inc = data['income'] ?? 0.0;
                                          final exp = data['expense'] ?? 0.0;
                                          final net = inc - exp;
                                          final savingsRate = inc > 0 ? (net / inc) * 100 : 0.0;
                                          final isForecast = monthKey == 'Forecast';
                                          final isAnomaly = _cachedAnomalyMonths.contains(monthKey);
                                          final isBest = monthKey == _cachedBestMonth;
                                          final isWorst = monthKey == _cachedWorstMonth;

                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                                              title: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        'View Zaznams',
                                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                                                      ),
                                                      if (isBest)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(6)),
                                                          child: const Text('Best Month', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                                        ),
                                                      if (isWorst)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(6)),
                                                          child: const Text('Worst Month', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    isForecast ? '$monthLabel (Est)' : monthLabel,
                                                    style: TextStyle(fontSize: 16, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (isAnomaly) ...[
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      margin: const EdgeInsets.only(bottom: 10),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: const Color(0xFFF59E0B)),
                                                      ),
                                                      child: const Row(
                                                        children: [
                                                          Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 16),
                                                          SizedBox(width: 6),
                                                          Expanded(child: Text('Anomaly detected: High spending spike!', style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold))),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text('Income: ${_formatCurrency(inc, compact: true)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
                                                        const SizedBox(height: 4),
                                                        Text('Expenses: ${_formatCurrency(exp, compact: true)}', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13)),
                                                        const SizedBox(height: 4),
                                                        Text('Net: ${_formatCurrency(net, compact: true)}', style: TextStyle(color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13)),
                                                        const SizedBox(height: 4),
                                                        Text('Savings Rate: ${savingsRate.toStringAsFixed(1)}%', style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13)),
                                                      ],
                                                    ),
                                                  ),
                                                  if (!isForecast && widget.onJumpToHistory != null) ...[
                                                    const SizedBox(height: 16),
                                                    Text('Display in All Zaznams:', style: TextStyle(color: _isZaznamityMode ? Colors.white70 : const Color(0xFF334155), fontWeight: FontWeight.w500)),
                                                  ],
                                                ],
                                              ),
                                              actions: [
                                                if (isForecast)
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                    ),
                                                    onPressed: () => Navigator.pop(ctx),
                                                    child: const Text('Close'),
                                                  )
                                                else if (widget.onJumpToHistory != null) ...[
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFEF4444),
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.pop(ctx);
                                                      widget.onJumpToHistory!(monthKey, 'expense', widget.selectedOwner);
                                                    },
                                                    child: const Text('Expenses'),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF10B981),
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.pop(ctx);
                                                      widget.onJumpToHistory!(monthKey, 'income', widget.selectedOwner);
                                                    },
                                                    child: const Text('Income'),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          int index = value.toInt();
                                          if (index >= 0 && index < _cachedMonthLabels.length && index < _cachedSortedKeys.length) {
                                            bool isForecast = index == _cachedSortedKeys.length - 1 && _cachedSortedKeys.last == 'Forecast';
                                            String mKey = _cachedSortedKeys[index];
                                            
                                            String labelText = _cachedMonthLabels[index];
                                            if (!isForecast) {
                                              try {
                                                DateTime dt = DateTime.parse('$mKey-01');
                                                if (index == 0 || DateTime.parse('${_cachedSortedKeys[index - 1]}-01').year != dt.year) {
                                                  labelText = '${_cachedMonthLabels[index]} \'${dt.year.toString().substring(2)}';
                                                }
                                              } catch (_) {}
                                            }

                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Transform.rotate(
                                                angle: -1.5708,
                                                child: Text(
                                                  isForecast ? '$labelText (Est)' : labelText,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: isForecast
                                                        ? const Color(0xFFA855F7)
                                                        : (_isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          return const Text('');
                                        },
                                        reservedSize: 50,
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 50,
                                        getTitlesWidget: (value, meta) {
                                          return Text(
                                            _formatCurrency(value, compact: true),
                                            style: TextStyle(fontSize: 9, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF94A3B8)),
                                          );
                                        },
                                      ),
                                    ),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: _niceStep(_cachedMaxY - _cachedMinY),
                                    getDrawingHorizontalLine: (value) {
                                      if (value == 0) {
                                        return FlLine(
                                          color: _isZaznamityMode ? Colors.white : Colors.black87,
                                          strokeWidth: 2,
                                        );
                                      }
                                      return FlLine(
                                        color: _isZaznamityMode ? Colors.white10 : const Color(0xFFE2E8F0),
                                        strokeWidth: 1,
                                      );
                                    },
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barGroups: _cachedBarGroups,
                                ),
                              ),
                              IgnorePointer(
                                child: LineChart(
                                  LineChartData(
                                    minX: -0.5,
                                    maxX: _cachedBarGroups.isNotEmpty ? _cachedBarGroups.length - 0.5 : 0.5,
                                    maxY: _cachedMaxY * 1.25,
                                    minY: _cachedMinY * 1.25,
                                    lineTouchData: const LineTouchData(enabled: false),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (_, __) => const SizedBox.shrink())),
                                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (_, __) => const SizedBox.shrink())),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    lineBarsData: [
                                      if (_showNetTrendLine) ...[
                                        LineChartBarData(
                                          spots: _cachedNetSpots,
                                          isCurved: true,
                                          color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                                          barWidth: 2.5,
                                          isStrokeCapRound: true,
                                          dotData: const FlDotData(show: true),
                                        ),
                                        LineChartBarData(
                                          spots: _cachedRollingNetSpots,
                                          isCurved: true,
                                          color: const Color(0xFF38BDF8),
                                          barWidth: 1.5,
                                          isStrokeCapRound: true,
                                          dashArray: [4, 4],
                                          dotData: const FlDotData(show: false),
                                        ),
                                      ],
                                      LineChartBarData(
                                        spots: [
                                          FlSpot(-0.5, -_cachedAvgExpense),
                                          FlSpot(_cachedBarGroups.isNotEmpty ? _cachedBarGroups.length - 0.5 : 0.5, -_cachedAvgExpense),
                                        ],
                                        isCurved: false,
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.7),
                                        barWidth: 1.5,
                                        dashArray: [5, 5],
                                        dotData: const FlDotData(show: false),
                                      ),
                                      LineChartBarData(
                                        spots: [
                                          FlSpot(-0.5, _cachedAvgNet),
                                          FlSpot(_cachedBarGroups.isNotEmpty ? _cachedBarGroups.length - 0.5 : 0.5, _cachedAvgNet),
                                        ],
                                        isCurved: false,
                                        color: const Color(0xFF10B981).withValues(alpha: 0.7),
                                        barWidth: 1.5,
                                        dashArray: [5, 5],
                                        dotData: const FlDotData(show: false),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ],
          ),
        );
      },
    );
  }
}