import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaznamity/models/card_config.dart';
import 'package:zaznamity/models/label.dart';
import 'package:zaznamity/services/notification_service.dart';
import 'package:zaznamity/widgets/settings/owner_management_modal.dart';
import 'package:zaznamity/widgets/settings/pool_management_modal.dart';

class AppSettingsCard extends StatefulWidget {
  final Map<String, bool> initialPools;
  final Map<String, bool> initialLiquidNetPools;
  final Map<String, bool> initialPrognosisPools;
  final List<String> initialOwners;
  final List<String> initialLeftNavItems;
  final List<String> initialRightNavItems;
  final List<LabelModel> labels;
  final List<CardConfig> cards;
  final Function(bool)? onThemeChanged;
  final Function(bool, String)? onPinSettingsChanged;
  final Function(Map<String, bool>) onSavePools;
  final Function(Map<String, bool>) onSaveLiquidNetPools;
  final Function(Map<String, bool>) onSavePrognosisPools;
  final Function(List<String>) onSaveOwners;
  final Function(List<String>, List<String>) onSaveNavItems;
  final Function(List<CardConfig>) onSaveCardOrder;
  final Function(String) onAddLabel;
  final Function(int, String) onUpdateLabel;
  final Function(int) onDeleteLabel;
  final VoidCallback? onImportCsv;
  final Function(String, {int? year, int? month}) onDeleteBulkTransactions;
  final Function(String, String) onBulkUpdateTransactionsLabel; // Added bulk update label callback
  final bool isWide;
  final VoidCallback? onToggleWidth;
  final VoidCallback? onHide;

  const AppSettingsCard({
    super.key,
    required this.initialPools,
    required this.initialLiquidNetPools,
    required this.initialPrognosisPools,
    required this.initialOwners,
    required this.initialLeftNavItems,
    required this.initialRightNavItems,
    required this.labels,
    required this.cards,
    this.onThemeChanged,
    this.onPinSettingsChanged,
    required this.onSavePools,
    required this.onSaveLiquidNetPools,
    required this.onSavePrognosisPools,
    required this.onSaveOwners,
    required this.onSaveNavItems,
    required this.onSaveCardOrder,
    required this.onAddLabel,
    required this.onUpdateLabel,
    required this.onDeleteLabel,
    this.onImportCsv,
    required this.onDeleteBulkTransactions,
    required this.onBulkUpdateTransactionsLabel,
    required this.isWide,
    this.onToggleWidth,
    this.onHide,
  });

  @override
  State<AppSettingsCard> createState() => _AppSettingsCardState();
}

class _AppSettingsCardState extends State<AppSettingsCard> {
  late Map<String, bool> _pools;
  late Map<String, bool> _liquidNetPools;
  late Map<String, bool> _prognosisPools;
  late List<String> _owners;
  late List<String> _leftNavItems;
  late List<String> _rightNavItems;
  
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  int _notifyDaysBefore = 1;
  int _notifyHoursBefore = 9;
  
  bool _biometricsEnabled = false;
  String _biometricType = 'PIN';
  String _savedPin = "1234";
  
  final TextEditingController _newLabelController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pools = Map.from(widget.initialPools);
    _liquidNetPools = Map.from(widget.initialLiquidNetPools);
    _prognosisPools = Map.from(widget.initialPrognosisPools);
    _owners = List.from(widget.initialOwners);
    
    _leftNavItems = [
      'settings',
      widget.initialLeftNavItems.length > 1 ? widget.initialLeftNavItems[1] : 'metrics',
      widget.initialLeftNavItems.length > 2 ? widget.initialLeftNavItems[2] : 'budget',
    ];
    _rightNavItems = [
      widget.initialRightNavItems.isNotEmpty ? widget.initialRightNavItems[0] : 'history',
      widget.initialRightNavItems.length > 1 ? widget.initialRightNavItems[1] : 'calendar',
      'manager',
    ];
    
    _loadPrefs();
  }

  @override
  void didUpdateWidget(covariant AppSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialOwners != oldWidget.initialOwners) {
      _owners = List.from(widget.initialOwners);
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _biometricsEnabled = prefs.getBool('biometricsEnabled') ?? false;
      _savedPin = prefs.getString('savedPin') ?? "1234";
      _pinController.text = _savedPin;

      final leftSaved = prefs.getStringList('leftNavItems');
      if (leftSaved != null && leftSaved.length >= 3) {
        _leftNavItems = ['settings', leftSaved[1], leftSaved[2]];
      }
      final rightSaved = prefs.getStringList('rightNavItems');
      if (rightSaved != null && rightSaved.length >= 3) {
        _rightNavItems = [rightSaved[0], rightSaved[1], 'manager'];
      }
    });
  }

  Future<void> _saveNavPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _leftNavItems[0] = 'settings';
    _rightNavItems[2] = 'manager';

    await prefs.setStringList('leftNavItems', _leftNavItems);
    await prefs.setStringList('rightNavItems', _rightNavItems);
    widget.onSaveNavItems(_leftNavItems, _rightNavItems);
  }

  List<DropdownMenuItem<String>> _buildNavDropdownItems() {
    final Map<String, String> uniqueItems = {};
    for (var card in widget.cards) {
      uniqueItems[card.id] = card.title;
    }
    return uniqueItems.entries.map((entry) {
      return DropdownMenuItem(
        value: entry.key,
        child: Text(entry.value, style: const TextStyle(fontSize: 13)),
      );
    }).toList();
  }

  void _editLabelDialog(LabelModel label) {
    final controller = TextEditingController(text: label.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Label Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                widget.onUpdateLabel(label.id, controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBulkDeleteDialog() {
    int selectedYear = DateTime.now().year;
    int selectedMonth = DateTime.now().month;
    String mode = 'month';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Text('Bulk Delete Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select scope for deletion:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text('By Specific Month', style: TextStyle(fontSize: 13)),
                value: 'month',
                groupValue: mode,
                onChanged: (val) => setStateModal(() => mode = val!),
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text('By Specific Year', style: TextStyle(fontSize: 13)),
                value: 'year',
                groupValue: mode,
                onChanged: (val) => setStateModal(() => mode = val!),
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text('All Transactions (Wipe All)', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                value: 'all',
                groupValue: mode,
                onChanged: (val) => setStateModal(() => mode = val!),
              ),
              if (mode == 'month' || mode == 'year') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedYear,
                        decoration: const InputDecoration(labelText: 'Year', isDense: true),
                        items: List.generate(11, (i) => 2020 + i).map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                        onChanged: (val) => setStateModal(() => selectedYear = val ?? selectedYear),
                      ),
                    ),
                    if (mode == 'month') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedMonth,
                          decoration: const InputDecoration(labelText: 'Month', isDense: true),
                          items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text('$m'))).toList(),
                          onChanged: (val) => setStateModal(() => selectedMonth = val ?? selectedMonth),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                if (mode == 'month') {
                  widget.onDeleteBulkTransactions('month', year: selectedYear, month: selectedMonth);
                } else if (mode == 'year') {
                  widget.onDeleteBulkTransactions('year', year: selectedYear);
                } else {
                  widget.onDeleteBulkTransactions('all');
                }
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkEditLabelDialog() {
    String? oldLabelName = widget.labels.isNotEmpty ? widget.labels.first.name : null;
    final newLabelController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Text('Bulk Edit Transactions by Label', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Change all Zaznams labeled:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              const Text('currently:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: oldLabelName,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                items: widget.labels.map((l) => DropdownMenuItem(value: l.name, child: Text(l.name))).toList(),
                onChanged: (val) => setStateModal(() => oldLabelName = val),
              ),
              const SizedBox(height: 16),
              const Text('to new label:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              TextField(
                controller: newLabelController,
                decoration: const InputDecoration(
                  hintText: 'Enter new label name...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 88, 47, 149), foregroundColor: Colors.white),
              onPressed: () {
                final newLabel = newLabelController.text.trim();
                if (oldLabelName != null && newLabel.isNotEmpty) {
                  Navigator.pop(ctx);
                  widget.onBulkUpdateTransactionsLabel(oldLabelName!, newLabel);
                }
              },
              child: const Text('Apply Changes'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'ZAZNAMITY SETTINGS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 88, 47, 149),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onToggleWidth != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: SizedBox(
                            height: 32,
                            width: 32,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFF1F5F9),
                                foregroundColor: const Color(0xFF64748B),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: widget.onToggleWidth,
                              icon: Icon(
                                widget.isWide ? Icons.fullscreen_exit : Icons.fullscreen,
                                size: 18,
                              ),
                              tooltip: widget.isWide ? 'Narrow' : 'Wide',
                            ),
                          ),
                        ),
                      if (widget.onHide != null)
                        SizedBox(
                          height: 32,
                          width: 32,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF64748B),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: widget.onHide,
                            icon: const Icon(
                              Icons.visibility_off_outlined,
                              size: 16,
                            ),
                            tooltip: 'Hide',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 8),

              _buildCollapsibleSection(
                title: 'Dark Mode',
                subtitle: 'Toggle light or dark theme appearance',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Dark Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    value: _isDarkMode,
                    onChanged: (val) async {
                      setState(() => _isDarkMode = val);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isDarkMode', val);
                      if (widget.onThemeChanged != null) {
                        widget.onThemeChanged!(val);
                      }
                    },
                  ),
                ],
              ),
              
              _buildCollapsibleSection(
                title: 'Navigation Bar',
                subtitle: 'Configure 3 items left and 3 items right (Settings, New Zaznam & Card Stack are fixed)',
                children: [
                  const Text('Left Slot 1 (Fixed)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 18, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Text('Settings (Fixed)', style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Left Slot 2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _leftNavItems.length > 1 && _buildNavDropdownItems().any((item) => item.value == _leftNavItems[1]) ? _leftNavItems[1] : 'metrics',
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                    items: _buildNavDropdownItems(),
                    onChanged: (val) async {
                      if (val != null) {
                        setState(() {
                          _leftNavItems[1] = val;
                        });
                        await _saveNavPrefs();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Left Slot 3', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _leftNavItems.length > 2 && _buildNavDropdownItems().any((item) => item.value == _leftNavItems[2]) ? _leftNavItems[2] : 'budget',
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                    items: _buildNavDropdownItems(),
                    onChanged: (val) async {
                      if (val != null) {
                        setState(() {
                          _leftNavItems[2] = val;
                        });
                        await _saveNavPrefs();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Center Slot (Fixed)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/ZaznamityLogoFULL.jpg',
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('New Zaznam (Fixed)', style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Right Slot 1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _rightNavItems.isNotEmpty && _buildNavDropdownItems().any((item) => item.value == _rightNavItems[0]) ? _rightNavItems[0] : 'history',
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                    items: _buildNavDropdownItems(),
                    onChanged: (val) async {
                      if (val != null) {
                        setState(() {
                          _rightNavItems[0] = val;
                        });
                        await _saveNavPrefs();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Right Slot 2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _rightNavItems.length > 1 && _buildNavDropdownItems().any((item) => item.value == _rightNavItems[1]) ? _rightNavItems[1] : 'calendar',
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
                    items: _buildNavDropdownItems(),
                    onChanged: (val) async {
                      if (val != null) {
                        setState(() {
                          _rightNavItems[1] = val;
                        });
                        await _saveNavPrefs();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Right Slot 3 (Fixed)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.layers_outlined, size: 18, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Text('Cards Stack Manager (Fixed)', style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),

              _buildCollapsibleSection(
                title: 'Labels Management',
                subtitle: 'Add, edit, or remove transaction labels',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newLabelController,
                          decoration: const InputDecoration(
                            hintText: 'New label name...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 88, 47, 149)),
                        onPressed: () {
                          if (_newLabelController.text.trim().isNotEmpty) {
                            widget.onAddLabel(_newLabelController.text.trim());
                            _newLabelController.clear();
                          }
                        },
                        child: const Text('Add', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.labels.length,
                      itemBuilder: (context, index) {
                        final label = widget.labels[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(label.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 16, color: Color(0xFF64748B)),
                                onPressed: () => _editLabelDialog(label),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 16, color: Color(0xFFDC2626)),
                                onPressed: () => widget.onDeleteLabel(label.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // Bulk Edit Transactions by Label Section
              _buildCollapsibleSection(
                title: 'Bulk Edit Transactions by Label',
                subtitle: 'Change all transactions labeled "x" to "y"',
                children: [
                  const Text(
                    'Reassign all existing transactions from one label to another in batch.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 88, 47, 149),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _showBulkEditLabelDialog,
                      icon: const Icon(Icons.edit_note, size: 18),
                      label: const Text('Bulk Edit Labels (x -> y)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),

              _buildCollapsibleSection(
                title: 'Liquid Net Counting Pools',
                subtitle: 'Choose which pools are counted toward liquid net',
                children: {'checking', 'cash', 'savings', 'loan'}.map((poolKey) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(poolKey.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    value: _liquidNetPools[poolKey] ?? (poolKey == 'checking' || poolKey == 'cash'),
                    onChanged: (val) {
                      setState(() {
                        _liquidNetPools[poolKey] = val ?? false;
                      });
                      widget.onSaveLiquidNetPools(_liquidNetPools);
                    },
                  );
                }).toList(),
              ),

              _buildCollapsibleSection(
                title: 'Future Metrics Counting Pools',
                subtitle: 'Configure which pools update future metrics',
                children: ['checking', 'cash', 'savings', 'loan'].map((poolKey) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(poolKey.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    value: _prognosisPools[poolKey] ?? false,
                    onChanged: (val) {
                      setState(() {
                        _prognosisPools[poolKey] = val ?? false;
                      });
                      widget.onSavePrognosisPools(_prognosisPools);
                    },
                  );
                }).toList(),
              ),

              _buildCollapsibleSection(
                title: 'Notifications',
                subtitle: 'Setup advance reminders for upcoming Zaznams',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Reminders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    value: _notificationsEnabled,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('notificationsEnabled', val);
                      setState(() => _notificationsEnabled = val);
                      if (val) {
                        NotificationService.showInstantNotification(
                          title: 'Zaznamity',
                          body: 'Push notifications are now enabled!',
                        );
                      } else {
                        NotificationService.cancelNotifications();
                      }
                    },
                  ),
                  if (_notificationsEnabled) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Days before: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        DropdownButton<int>(
                          value: _notifyDaysBefore,
                          items: [0, 1, 2, 3, 5, 7].map((d) => DropdownMenuItem(value: d, child: Text('$d day(s)'))).toList(),
                          onChanged: (val) => setState(() => _notifyDaysBefore = val ?? 1),
                        ),
                        const SizedBox(width: 20),
                        const Text('Hours: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        DropdownButton<int>(
                          value: _notifyHoursBefore,
                          items: [8, 9, 10, 12, 18, 20].map((h) => DropdownMenuItem(value: h, child: Text('$h:00'))).toList(),
                          onChanged: (val) => setState(() => _notifyHoursBefore = val ?? 9),
                        ),
                      ],
                    ),
                  ]
                ],
              ),

              _buildCollapsibleSection(
                title: 'Owner Management',
                subtitle: 'Add / edit / delete Zaznamity owners',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Open Owner Management', style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (ctx) => OwnerManagementModal(
                          initialOwners: _owners,
                          onSaveOwners: (updatedOwners) {
                            setState(() => _owners = updatedOwners);
                            widget.onSaveOwners(updatedOwners);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),

              _buildCollapsibleSection(
                title: 'Pools Management',
                subtitle: 'Manage custom transaction pools',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Open Pool Manager', style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (ctx) => PoolManagementModal(
                          initialPools: _pools,
                          onSavePools: (updatedPools) {
                            setState(() => _pools = updatedPools);
                            widget.onSavePools(updatedPools);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),

              _buildCollapsibleSection(
                title: 'Security',
                subtitle: 'Secure app access with PIN or Face biometrics',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Security Lock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                    value: _biometricsEnabled,
                    onChanged: (val) async {
                      setState(() => _biometricsEnabled = val);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('biometricsEnabled', val);
                      if (widget.onPinSettingsChanged != null) {
                        widget.onPinSettingsChanged!(val, _savedPin);
                      }
                    },
                  ),
                  if (_biometricsEnabled) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Set 4-Digit PIN',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        isDense: true,
                      ),
                      onChanged: (val) async {
                        if (val.length == 4) {
                          setState(() => _savedPin = val);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('savedPin', val);
                          if (widget.onPinSettingsChanged != null) {
                            widget.onPinSettingsChanged!(_biometricsEnabled, val);
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _biometricType,
                      items: const [
                        DropdownMenuItem(value: 'PIN', child: Text('Open on PIN Code')),
                        DropdownMenuItem(value: 'Face', child: Text('Face Biometrics / Touch ID')),
                      ],
                      onChanged: (val) => setState(() => _biometricType = val ?? 'PIN'),
                      decoration: const InputDecoration(labelText: 'Authentication Method', isDense: true),
                    ),
                  ],
                ],
              ),

              _buildCollapsibleSection(
                title: 'Import CSV / Excel XLS',
                subtitle: 'Import transactions with required matching columns',
                children: [
                  const Text(
                    'Configure your CSV or XLS file to include these 9 columns:\n'
                    '1. ID\n'
                    '2. Date (ISO timestamp)\n'
                    '3. Description\n'
                    '4. Amount\n'
                    '5. Type (income/expense)\n'
                    '6. Owner (must exist in the app)\n'
                    '7. Pool (checking/cash/savings/loan)\n'
                    '8. Label (must exist in the app)\n'
                    '9. Confirmed (1 (yes) or 0 (no))',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 88, 47, 149),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: widget.onImportCsv,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Select & Import CSV / XLS File', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),

              _buildCollapsibleSection(
                title: 'Delete Zaznams - DANGER ZONE',
                subtitle: 'Delete Zaznams in bulk by month, year, or all',
                children: [
                  const Text(
                    'Permanently delete multiple records based on time range.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _showBulkDeleteDialog,
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      label: const Text('Bulk Delete Zaznams', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),

              _buildCollapsibleSection(
                title: 'About Zaznamity',
                subtitle: 'App version, credits, and details',
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Welcome to Zaznamity v1.0.0!\n\n'
                      '"Zaznam" in Slovak means record or transaction. Keep track of all your Zaznams and keep them secure on your phone—no cloud, no subscriptions.\n\n'
                      'Local-first (SQLite): Full privacy and ownership. Your financial data stays entirely on your device.\n\n'
                      'Features of this app:\n',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        children: children,
      ),
    );
  }
}