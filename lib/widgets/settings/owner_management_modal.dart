// ignore_for_file: deprecated_member_use

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
  bool _isZaznamityMode = true;

  @override
  void initState() {
    super.initState();
    // Default to 'Owner 1' if no initial owners exist
    _owners = widget.initialOwners.isNotEmpty ? List.from(widget.initialOwners) : ['Owner 1'];
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
      });
    }
  }

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
        backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Owner',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
          ),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
          decoration: const InputDecoration(labelText: 'Owner Name', isDense: true, border: OutlineInputBorder()),
          autofocus: true,
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
    if (_owners.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one owner must remain.')),
      );
      return;
    }
    setState(() {
      _owners.removeAt(index);
    });
    await _persistAndSave(_owners);
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
              Icon(Icons.people_outline_rounded, color: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95)),
              const SizedBox(width: 8),
              Text(
                'OWNER MANAGEMENT',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Info Banner 1: Multiple Owners Info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF582F95)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Multiple owners can be managed within Zaznamity for shared or individual household tracking.',
                    style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Info Banner 2: Avatar Picture Info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isZaznamityMode ? const Color(0xFF2D1B4E) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                Icon(Icons.account_circle_outlined, size: 16, color: _isZaznamityMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Note: Each owner\'s avatar image can be uploaded and customized in the Title Card.',
                    style: TextStyle(fontSize: 11, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newOwnerController,
                  style: TextStyle(color: _isZaznamityMode ? Colors.white : Colors.black87, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'New owner name...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isZaznamityMode ? const Color(0xFF582F95) : const Color(0xFF582F95),
                  foregroundColor: Colors.white,
                ),
                onPressed: _addOwner,
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _owners.length,
              itemBuilder: (context, index) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _owners[index],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, size: 18, color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
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