// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

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
  // Storing pool key -> currency code mapping locally inside the modal state
  // (e.g., {'checking': 'USD', 'savings': 'EUR'})
  late Map<String, bool> _pools;
  final Map<String, String> _poolCurrencies = {};
  
  final TextEditingController _poolController = TextEditingController();
  String _selectedCurrencyForNewPool = 'USD';

  // Top 10 popular currencies list with flag emojis
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
    _pools = Map.from(widget.initialPools);
    
    // Initialize default currency bindings for existing pools (defaulting to USD if unassigned)
    for (var key in _pools.keys) {
      _poolCurrencies[key] = 'USD';
    }
  }

  @override
  void dispose() {
    _poolController.dispose();
    super.dispose();
  }

  void _addPool() {
    final poolName = _poolController.text.trim().toLowerCase();
    if (poolName.isNotEmpty && !_pools.containsKey(poolName)) {
      setState(() {
        _pools[poolName] = true;
        _poolCurrencies[poolName] = _selectedCurrencyForNewPool;
        _poolController.clear();
      });
      widget.onSavePools(_pools);
    }
  }

  void _deletePool(String key) {
    if (_pools.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must keep at least one pool.')),
      );
      return;
    }
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pools Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add custom transaction pools and bind specific currencies to them.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          
          // Row to add new pool & select its currency
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _poolController,
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
                  backgroundColor: const Color.fromARGB(255, 88, 47, 149),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onPressed: _addPool,
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // List of existing pools with currency dropdown selector
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _pools.keys.length,
              itemBuilder: (context, index) {
                String poolKey = _pools.keys.elementAt(index);
                String currentCurrency = _poolCurrencies[poolKey] ?? 'USD';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          poolKey.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 130,
                        child: DropdownButtonFormField<String>(
                          initialValue: currentCurrency,
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
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
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