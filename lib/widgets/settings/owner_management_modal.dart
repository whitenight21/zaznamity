import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OwnerManagementModal extends StatefulWidget {
  final List<String> initialOwners;
  final Function(List<String>) onSaveOwners;

  const OwnerManagementModal({
    super.key,
    required this.initialOwners,
    required this.onSaveOwners,
  });

  @override
  State<OwnerManagementModal> createState() => _OwnerManagementModalState();
}

class _OwnerManagementModalState extends State<OwnerManagementModal> {
  late List<String> _owners;
  final TextEditingController _newOwnerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _owners = List.from(widget.initialOwners);
  }

  // Helper method to save to SharedPreferences and update parent
  Future<void> _persistAndSave(List<String> updatedOwners) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('savedOwners', updatedOwners);
    widget.onSaveOwners(updatedOwners);
  }

  void _addOwner() async {
    final name = _newOwnerController.text.trim();
    if (name.isNotEmpty && !_owners.contains(name)) {
      setState(() {
        _owners.add(name);
        _newOwnerController.clear();
      });
      await _persistAndSave(_owners);
    }
  }

  void _editOwner(int index) async {
    final controller = TextEditingController(text: _owners[index]);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Owner'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Owner Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                setState(() => _owners[index] = val);
                await _persistAndSave(_owners);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteOwner(int index) async {
    setState(() {
      _owners.removeAt(index);
    });
    await _persistAndSave(_owners);
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
            'Manage Owners',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newOwnerController,
                  decoration: const InputDecoration(
                    hintText: 'New owner name...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 88, 47, 149)),
                onPressed: _addOwner,
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _owners.length,
              itemBuilder: (context, index) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_owners[index], style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18, color: Color(0xFF64748B)),
                        onPressed: () => _editOwner(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: Color(0xFFDC2626)),
                        onPressed: () => _deleteOwner(index),
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