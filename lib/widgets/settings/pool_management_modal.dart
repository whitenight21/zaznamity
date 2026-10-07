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
  final TextEditingController _poolController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pools = Map.from(widget.initialPools);
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
            'Add or remove custom transaction pools (e.g., crypto, wallet).',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _poolController,
                  decoration: const InputDecoration(
                    hintText: 'New pool name...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 88, 47, 149),
                  foregroundColor: Colors.white,
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
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    poolKey.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Color(0xFFDC2626)),
                    onPressed: () => _deletePool(poolKey),
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