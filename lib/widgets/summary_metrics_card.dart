// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';

class SummaryMetricsCard extends StatefulWidget {
  final List<String> owners;
  final String? selectedOwner;
  final Map<String, Map<String, Map<String, double>>> poolTotalsByCurrencyAndOwner;
  final Map<String, Map<String, double>> totalPoolTotalsByCurrency;
  final Map<String, Map<String, double>> liquidNetByCurrencyAndOwner;
  final Map<String, Map<String, double>> totalLiquidNetByCurrency;
  final Map<String, Map<String, Map<String, double>>> ownerBreakdownByCurrency;
  final List<TransactionModel> transactions;
  final bool isWide;
  final VoidCallback? onToggleWidth;
  final VoidCallback? onHide;

  const SummaryMetricsCard({
    super.key,
    required this.owners,
    this.selectedOwner,
    required this.poolTotalsByCurrencyAndOwner,
    required this.totalPoolTotalsByCurrency,
    required this.liquidNetByCurrencyAndOwner,
    required this.totalLiquidNetByCurrency,
    required this.ownerBreakdownByCurrency,
    required this.transactions,
    this.isWide = false,
    this.onToggleWidth,
    this.onHide,
  });

  @override
  State<SummaryMetricsCard> createState() => _SummaryMetricsCardState();
}

class _SummaryMetricsCardState extends State<SummaryMetricsCard> {
  late String _selectedOwner;
  
  String _primaryCurrency = 'USD';
  String? _secondaryCurrency1;
  String? _secondaryCurrency2;
  String? _secondaryCurrency3;

  bool _isZaznamityMode = true;

  final Map<String, bool> _liquidNetPools = {};
  
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

  @override
  void initState() {
    super.initState();
    _selectedOwner = widget.selectedOwner ?? 'All Owners';
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    
    Set<String> allPools = {};
    widget.totalPoolTotalsByCurrency.values.forEach((map) {
      allPools.addAll(map.keys);
    });

    Map<String, bool> loadedPools = {};
    for (var pool in allPools) {
      loadedPools[pool] = prefs.getBool('set_liquidNet_pool_$pool') ?? true;
    }

    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';
        _secondaryCurrency1 = prefs.getString('secondaryCurrency1');
        _secondaryCurrency2 = prefs.getString('secondaryCurrency2');
        _secondaryCurrency3 = prefs.getString('secondaryCurrency3');
        _liquidNetPools.addAll(loadedPools);
      });
    }
  }

  @override
  void didUpdateWidget(covariant SummaryMetricsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOwner != oldWidget.selectedOwner) {
      setState(() {
        _selectedOwner = widget.selectedOwner ?? 'All Owners';
      });
    }
    _loadPrefs();
  }

  String _formatCurrency(double amount, String currencyCode) {
    String symbol = '\$';
    if (currencyCode == 'EUR') symbol = '€';
    else if (currencyCode == 'GBP') symbol = '£';
    else if (currencyCode == 'JPY') symbol = '¥';
    
    final format = NumberFormat.currency(symbol: symbol, decimalDigits: currencyCode == 'JPY' ? 0 : 2);
    return format.format(amount);
  }

  Color _getPoolColor(String poolName) {
    switch (poolName.toLowerCase()) {
      case 'checking':
        return _isZaznamityMode ? const Color(0xFF38BDF8) : const Color.fromARGB(255, 0, 132, 184);
      case 'cash':
        return _isZaznamityMode ? const Color(0xFF4ADE80) : const Color(0xFF56C435);
      case 'savings':
        return _isZaznamityMode ? const Color(0xFFFB923C) : const Color(0xFFFF7F27);
      case 'loan':
      case 'loans':
        return _isZaznamityMode ? const Color(0xFF94A3B8) : const Color.fromARGB(255, 105, 105, 105);
      default:
        return Colors.primaries[poolName.hashCode % Colors.primaries.length];
    }
  }

  double _calculateMonthlyTrend(String currencyCode) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    double startOfMonthBalance = 0;
    double currentBalance = 0;

    for (var tx in widget.transactions) {
      if (tx.isConfirmed != 1) continue;
      String curr = tx.currencyCode.isNotEmpty ? tx.currencyCode : _primaryCurrency;
      if (curr != currencyCode) continue;
      if (_selectedOwner != 'All Owners' && tx.owner != _selectedOwner) continue;
      if (_liquidNetPools[tx.pool] == false) continue;

      final dt = DateTime.tryParse(tx.createdAt);
      if (dt == null) continue;

      double signedVal = tx.type == 'income' ? tx.amount : -tx.amount;
      currentBalance += signedVal;
      if (dt.isBefore(startOfMonth)) {
        startOfMonthBalance += signedVal;
      }
    }

    if (startOfMonthBalance == 0) return 0.0;
    return ((currentBalance - startOfMonthBalance) / startOfMonthBalance.abs()) * 100;
  }

  void _showMetricInfo(BuildContext context, String title, String explanation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)))),
          ],
        ),
        content: Text(
          explanation,
          style: TextStyle(fontSize: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569), height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencySection(String currencyCode, double availableWidth, double boxWidth, double fullWidth) {
    final flag = _currencyFlags[currencyCode] ?? '';
    
    final totalPoolsForCurr = widget.totalPoolTotalsByCurrency[currencyCode] ?? {};
    final ownerPoolsMap = widget.poolTotalsByCurrencyAndOwner[currencyCode] ?? {};
    final breakdownCurrMap = widget.ownerBreakdownByCurrency[currencyCode] ?? {};

    Map<String, double> currentPools;
    List<Widget> wrapSubtitles = [];

    if (_selectedOwner == 'All Owners') {
      currentPools = Map.fromEntries(
        totalPoolsForCurr.entries.where((e) => e.value != 0.0)
      );
      
      wrapSubtitles = breakdownCurrMap.entries.map((e) {
        final ownerName = e.key;
        final ownerPools = ownerPoolsMap[ownerName] ?? {};
        double ownerLiquidNet = 0;
        ownerPools.forEach((poolName, balance) {
          if (_liquidNetPools[poolName] ?? true) {
            ownerLiquidNet += balance;
          }
        });
        return Text(
          '$ownerName: ${_formatCurrency(ownerLiquidNet, currencyCode)}',
          style: TextStyle(
            fontSize: 12,
            color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade700,
            fontWeight: FontWeight.w700,
          ),
        );
      }).toList();
    } else {
      final ownerPools = ownerPoolsMap[_selectedOwner] ?? {};
      currentPools = Map.fromEntries(
        ownerPools.entries.where((e) => e.value != 0.0)
      );
    }

    double currentLiquidNet = 0;
    currentPools.forEach((poolName, balance) {
      if (_liquidNetPools[poolName] ?? true) {
        currentLiquidNet += balance;
      }
    });

    final monthlyTrend = _calculateMonthlyTrend(currencyCode);

    final poolEntries = currentPools.entries.toList();
    List<List<MapEntry<String, double>>> poolRows = [];
    for (int i = 0; i < poolEntries.length; i += 2) {
      poolRows.add(
        poolEntries.sublist(
          i,
          i + 2 > poolEntries.length ? poolEntries.length : i + 2,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: boxWidth,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 20, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedOwner,
                          isDense: true,
                          isExpanded: true,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : const Color(0xFF334155)),
                          items: [
                            DropdownMenuItem(value: 'All Owners', child: Text('All Owners', style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87))),
                            ...widget.owners.map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87)))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedOwner = val);
                          },
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
                height: 48,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      flag,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currencyCode,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _isZaznamityMode ? const Color(0xFF9D65FF) : const Color(0xFF582F95),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LIQUID NET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatCurrency(currentLiquidNet, currencyCode),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Trend: ${monthlyTrend >= 0 ? '+' : ''}${monthlyTrend.toStringAsFixed(1)}% vs. start of month',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: monthlyTrend >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _showMetricInfo(
                      context,
                      'Net Worth Trend',
                      'Compares your current total liquid net balance against your baseline net balance recorded on the 1st day of the current month.',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (_selectedOwner != 'All Owners') ...[
          Center(
            child: Text(
              _selectedOwner.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ] else if (wrapSubtitles.isNotEmpty) ...[
          Center(
            child: Wrap(
              spacing: 14.0,
              runSpacing: 4.0,
              alignment: WrapAlignment.center,
              children: wrapSubtitles,
            ),
          ),
        ],
        const SizedBox(height: 16),

        ...poolRows.map((rowEntries) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: rowEntries.map((entry) {
                final bool isSingle = rowEntries.length == 1;
                return SizedBox(
                  width: isSingle ? fullWidth : boxWidth,
                  child: _buildMetricBox(
                    title: entry.key.toUpperCase(),
                    amount: entry.value,
                    amountColor: _getPoolColor(entry.key),
                    width: isSingle ? fullWidth : boxWidth,
                    currencyCode: currencyCode,
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double fullWidth = availableWidth - 32;
        final double boxWidth = (fullWidth - 12) / 2;

        List<String> activeCurrencies = [_primaryCurrency];
        if (_secondaryCurrency1 != null) activeCurrencies.add(_secondaryCurrency1!);
        if (_secondaryCurrency2 != null) activeCurrencies.add(_secondaryCurrency2!);
        if (_secondaryCurrency3 != null) activeCurrencies.add(_secondaryCurrency3!);

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
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'METRICS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
              const SizedBox(height: 12),

              for (int i = 0; i < activeCurrencies.length; i++) ...[
                if (i > 0) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(color: _isZaznamityMode ? Colors.white24 : const Color(0xFF582F95), thickness: 1.5),
                  ),
                ],
                _buildCurrencySection(activeCurrencies[i], availableWidth, boxWidth, fullWidth),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricBox({
    required String title,
    required double amount,
    required Color amountColor,
    required double width,
    required String currencyCode,
  }) {
    String lowerTitle = title.toLowerCase();
    String infoTitle = title;
    String infoExplanation;

    if (lowerTitle == 'checking') {
      infoExplanation = 'Checking Pool: Represents your everyday transactional funds and bank accounts used for immediate income deposits, bill payments, and daily expenses.';
    } else if (lowerTitle == 'savings') {
      infoExplanation = 'Savings Pool: Tracks funds set aside for emergency reserves, future security, or intermediate holding separate from everyday spending.';
    } else if (lowerTitle == 'goals') {
      infoExplanation = 'Goals Pool: Dedicated funds earmarked for specific targeted milestones, purchases, or dedicated financial projects.';
    } else {
      infoExplanation = 'Custom user created pool.';
    }

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade600,
                        letterSpacing: 0.6,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _showMetricInfo(context, infoTitle, infoExplanation),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(Icons.info_outline_rounded, size: 13, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatCurrency(amount, currencyCode),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: amountColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}