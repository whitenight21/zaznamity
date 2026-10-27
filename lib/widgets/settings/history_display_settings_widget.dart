import 'package:flutter/material.dart';
import '../../models/history_display_prefs.dart';

class HistoryDisplaySettingsWidget extends StatefulWidget {
  final bool isZaznamityMode;
  final VoidCallback? onPrefsChanged;

  const HistoryDisplaySettingsWidget({
    super.key,
    required this.isZaznamityMode,
    this.onPrefsChanged,
  });

  @override
  State<HistoryDisplaySettingsWidget> createState() => _HistoryDisplaySettingsWidgetState();
}

class _HistoryDisplaySettingsWidgetState extends State<HistoryDisplaySettingsWidget> {
  HistoryDisplayPrefs _prefs = HistoryDisplayPrefs();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final loaded = await HistoryDisplayPrefs.load();
    if (mounted) {
      setState(() {
        _prefs = loaded;
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePref(Function(HistoryDisplayPrefs) updateFn) async {
    setState(() {
      updateFn(_prefs);
    });
    await _prefs.save();
    if (widget.onPrefsChanged != null) {
      widget.onPrefsChanged!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();

    final textColor = widget.isZaznamityMode ? Colors.white : const Color(0xFF1E293B);
    final subColor = widget.isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B);
    final activeColor = widget.isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMPACT ALL ZAZNAM DISPLAY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: activeColor,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Select the fields to display',
                  style: TextStyle(fontSize: 10, color: subColor),
                ),
              ],
            ),
            Switch(
              value: _prefs.isCustomFilterEnabled,
              activeColor: activeColor,
              onChanged: (val) {
                _updatePref((p) => p.isCustomFilterEnabled = val);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        Opacity(
          opacity: _prefs.isCustomFilterEnabled ? 1.0 : 0.4,
          child: IgnorePointer(
            ignoring: !_prefs.isCustomFilterEnabled,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildChip('Description', _prefs.showDescription, (v) => _updatePref((p) => p.showDescription = v)),
                _buildChip('Date', _prefs.showDate, (v) => _updatePref((p) => p.showDate = v)),
                _buildChip('Label', _prefs.showLabel, (v) => _updatePref((p) => p.showLabel = v)),
                _buildChip('Owner', _prefs.showOwner, (v) => _updatePref((p) => p.showOwner = v)),
                _buildChip('Amount', _prefs.showAmount, (v) => _updatePref((p) => p.showAmount = v)),
                _buildChip('Pool', _prefs.showPool, (v) => _updatePref((p) => p.showPool = v)),
                _buildChip('Currency', _prefs.showCurrency, (v) => _updatePref((p) => p.showCurrency = v)),
                _buildChip('Edit', _prefs.showEdit, (v) => _updatePref((p) => p.showEdit = v)),
                _buildChip('Delete', _prefs.showDelete, (v) => _updatePref((p) => p.showDelete = v)),
                _buildChip('Status', _prefs.showConfirmStatus, (v) => _updatePref((p) => p.showConfirmStatus = v)),
                _buildChip('Attachments', _prefs.showAttachments, (v) => _updatePref((p) => p.showAttachments = v)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: widget.isZaznamityMode ? Colors.white : Colors.black87)),
      selected: value,
      selectedColor: const Color(0xFF582F95),
      backgroundColor: widget.isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFE2E8F0),
      onSelected: onChanged,
    );
  }
}