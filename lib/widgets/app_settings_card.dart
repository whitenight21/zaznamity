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
    
    // Normalize to 3 items per side ensuring fixed slots
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
    // Ensure strict preservation of locked slots before saving
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
              // Header & Window Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'APP SETTINGS',
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

              // Navigation Bar Customization Section (3 Left, 3 Right with locked endpoints)
              _buildCollapsibleSection(
                title: 'Navigation Bar',
                subtitle: 'Configure 3 items left and 3 items right (Settings & Card Stack are fixed)',
                children: [
                  // Left Slot 1 (Fixed Settings)
                  const Text('Left Slot 1 (Most Left)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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

                  // Left Slot 2
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

                  // Left Slot 3
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
                  const SizedBox(height: 16),

                  // Right Slot 1
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

                  // Right Slot 2
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

                  // Right Slot 3 (Fixed Card Stack Manager)
                  const Text('Right Slot 3 (Most Right)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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

              // Other settings sections...
              _buildCollapsibleSection(
                title: 'Manage Labels',
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

              _buildCollapsibleSection(
                title: 'Liquid Net Counting Pools',
                subtitle: 'Choose which pools are counted toward liquid net',
                children: {'checking', 'cash', 'savings', 'loan', 'loans'}.map((poolKey) {
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
                title: 'Prognosis Counting Pools',
                subtitle: 'Configure which pools update prognosis metrics',
                children: ['cash', 'savings', 'loans'].map((poolKey) {
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
                title: 'Add / Edit / Delete Owner',
                subtitle: 'Manage wallet owners via modular manager',
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
                title: 'Edit Pools',
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
                title: 'Biometrics',
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
                title: 'About Zaznamity',
                subtitle: 'App version, credits, and details',
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Zaznamity v1.0.0\nYour robust personal financial companion.',
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