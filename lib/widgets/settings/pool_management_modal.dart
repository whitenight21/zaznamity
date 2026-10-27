// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PoolManagementModal extends StatefulWidget {
  final Map<String, bool> initialPools;
  final Function(Map<String, bool>) onSavePools;

  const PoolManagementModal({
    super.key,
    required this.initialPools,
    required this.onSavePools,
  });

  @override
  State<PoolManagementModal> createState() => _PoolManagementModalState();
}

class _PoolManagementModalState extends State<PoolManagementModal> {
  late Map<String, bool> _pools;
  final Map<String, String> _poolCurrencies = {};
  final TextEditingController _poolController = TextEditingController();
  
  String _primaryCurrency = 'USD';
  String _selectedCurrencyForNewPool = 'USD';
  bool _isZaznamityMode = true;

  final List<Map<String, String>> _availableCurrencies = [
    {'code': 'USD', 'name': '🇺🇸 USD (\$)'},
    {'code': 'EUR', 'name': '🇪🇺 EUR (€)'},
    {'code': 'JPY', 'name': '🇯🇵 JPY (¥)'},
    {'code': 'GBP', 'name': '🇬🇧 GBP (£)'},
    {'code': 'CNY', 'name': '🇨🇳 CNY (¥)'},
    {'code': 'AUD', 'name': '🇦🇺 AUD (A\$)'},
    {'code': 'CAD', 'name': '🇨🇦 CAD (C\$)'},
    {'code': 'CHF', 'name': '🇨🇭 CHF (CHF)'},
    {'code': 'HKD', 'name': '🇭🇰 HKD (HK\$)'},
    {'code': 'SGD', 'name': '🇸🇬 SGD (S\$)'},
  ];

  @override
  void initState() {
    super.initState();
    // Default pools on first start: checking, cash, savings
    _pools = widget.initialPools.isNotEmpty
        ? Map.from(widget.initialPools)
        : {'checking': true, 'cash': true, 'savings': true};
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    final primary = prefs.getString('primaryCurrency') ?? 'USD';

    for (var key in _pools.keys) {
      _poolCurrencies[key] = prefs.getString('pool_currency_$key') ?? primary;
    }

    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
        _primaryCurrency = primary;
        _selectedCurrencyForNewPool = primary;
      });
    }
  }

  Future<void> _savePoolCurrency(String poolKey, String currencyCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pool_currency_$poolKey', currencyCode);
  }

  @override
  void dispose() {
    _poolController.dispose();
    super.dispose();
  }

  void _addPool() async {
    final poolName = _poolController.text.trim().toLowerCase();
    if (poolName.isNotEmpty && !_pools.containsKey(poolName)) {
      setState(() {
        _pools[poolName] = true;
        _poolCurrencies[poolName] = _selectedCurrencyForNewPool;
        _poolController.clear();
      });
      await _savePoolCurrency(poolName, _selectedCurrencyForNewPool);
      widget.onSavePools(_pools);
    }
  }

  void _editPool(String oldKey) async {
    final nameController = TextEditingController(text: oldKey);
    String currentCurrency = _poolCurrencies[oldKey] ?? _primaryCurrency;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Pool',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Pool Name', isDense: true, border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: currentCurrency,
                dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                decoration: const InputDecoration(labelText: 'Bound Currency', isDense: true, border: OutlineInputBorder()),
                items: _availableCurrencies.map((c) => DropdownMenuItem(value: c['code'], child: Text(c['name']!))).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => currentCurrency = val);
                },
              ),
            ],
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
                final newKey = nameController.text.trim().toLowerCase();
                if (newKey.isNotEmpty) {
                  setState(() {
                    bool enabledState = _pools[oldKey] ?? true;
                    _pools.remove(oldKey);
                    _pools[newKey] = enabledState;
                    _poolCurrencies[newKey] = currentCurrency;
                  });
                  await _savePoolCurrency(newKey, currentCurrency);
                  widget.onSavePools(_pools);
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

  void _deletePool(String key) async {
    if (_pools.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must keep at least one pool.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pool_currency_$key');

    setState(() {
      _pools.remove(key);
      _poolCurrencies.remove(key);
    });
    widget.onSavePools(_pools);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: _isZaznamityMode ? const Color(0xFF1E1333) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
              const SizedBox(width: 8),
              Text(
                'POOLS MANAGEMENT',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Default pools: Checking, Cash, Savings. Goals and custom pools can be created as needed.',
            style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _poolController,
                  style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'New pool name...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCurrencyForNewPool,
                  dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                  style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 12),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                  items: _availableCurrencies.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['code'],
                      child: Text(c['code']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCurrencyForNewPool = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onPressed: _addPool,
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _pools.keys.length,
              itemBuilder: (context, index) {
                String poolKey = _pools.keys.elementAt(index);
                String currentCurrency = _poolCurrencies[poolKey] ?? _primaryCurrency;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          poolKey.toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<String>(
                          initialValue: currentCurrency,
                          dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                          style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 11),
                          isExpanded: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                          ),
                          items: _availableCurrencies.map((c) {
                            return DropdownMenuItem<String>(
                              value: c['code'],
                              child: Text(c['name']!, style: const TextStyle(fontSize: 11)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _poolCurrencies[poolKey] = val;
                              });
                              _savePoolCurrency(poolKey, val);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit, size: 18, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
                        onPressed: () => _editPool(poolKey),
                        tooltip: 'Edit Pool',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: Color(0xFFDC2626)),
                        onPressed: () => _deletePool(poolKey),
                        tooltip: 'Delete Pool',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}