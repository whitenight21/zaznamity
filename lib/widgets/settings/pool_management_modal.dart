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
  late Map<String, bool> _pools;
  final TextEditingController _newPoolController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pools = Map.from(widget.initialPools);
  }

  void _addPool() {
    final poolKey = _newPoolController.text.trim().toLowerCase();
    if (poolKey.isNotEmpty && !_pools.containsKey(poolKey)) {
      setState(() {
        _pools[poolKey] = true;
        _newPoolController.clear();
      });
      widget.onSavePools(_pools);
    }
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
            'Edit Pools',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newPoolController,
                  decoration: const InputDecoration(
                    hintText: 'Add new custom pool...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 88, 47, 149)),
                onPressed: _addPool,
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView(
              shrinkWrap: true,
              children: _pools.keys.map((key) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
                  value: _pools[key] ?? true,
                  onChanged: (val) {
                    setState(() => _pools[key] = val);
                    widget.onSavePools(_pools);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}