// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/label.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';

class CsvImportMapperWorkflow {
  static Future<void> runCsvImportWorkflow({
    required BuildContext context,
    required List<LabelModel> labels,
    required List<String> owners,
    required List<String> pools,
    required VoidCallback onImportCompleted,
  }) async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Spreadsheets',
        extensions: <String>['csv', 'txt'],
        mimeTypes: <String>['*/*'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (file == null) return;

      String content = await file.readAsString();
      if (content.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The selected file is empty.')),
        );
        return;
      }

      List<String> lines = content.split('\n');
      if (lines.isEmpty) return;

      List<String> headers = _parseCsvRow(lines[0].trim());
      if (headers.isNotEmpty) {
        headers[0] = headers[0].replaceAll('\uFEFF', '');
      }
      if (headers.isEmpty) return;

      if (!context.mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _CsvMappingDialog(
          lines: lines,
          headers: headers,
          labels: labels,
          owners: owners,
          pools: pools,
          onImportCompleted: onImportCompleted,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading file: $e')),
      );
    }
  }

  static List<String> _parseCsvRow(String line) {
    List<String> result = [];
    bool inQuotes = false;
    StringBuffer currentVal = StringBuffer();
    
    for (int i = 0; i < line.length; i++) {
      String char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if ((char == ',' || char == ';') && !inQuotes) {
        result.add(currentVal.toString().replaceAll('"', '').trim());
        currentVal.clear();
      } else {
        currentVal.write(char);
      }
    }
    result.add(currentVal.toString().replaceAll('"', '').trim());
    return result;
  }
}

class _CsvMappingDialog extends StatefulWidget {
  final List<String> lines;
  final List<String> headers;
  final List<LabelModel> labels;
  final List<String> owners;
  final List<String> pools;
  final VoidCallback onImportCompleted;

  const _CsvMappingDialog({
    required this.lines,
    required this.headers,
    required this.labels,
    required this.owners,
    required this.pools,
    required this.onImportCompleted,
  });

  @override
  State<_CsvMappingDialog> createState() => _CsvMappingDialogState();
}

class _CsvMappingDialogState extends State<_CsvMappingDialog> {
  String? _mapDate;
  String? _mapAmount;
  String? _mapDescription;
  String? _mapType;
  String? _mapOwner;
  String? _mapPool;
  String? _mapLabel;
  String? _mapCurrency;

  bool _autoDetectFuture = true;
  bool _createMissingOwners = true;
  bool _createMissingLabels = true;
  bool _createMissingPools = true;
  bool _isProcessing = false;
  bool _isZaznamityMode = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    for (var h in widget.headers) {
      final lower = h.toLowerCase();
      if (lower.contains('date') && _mapDate == null) _mapDate = h;
      if ((lower.contains('amount') || lower.contains('sum')) && _mapAmount == null) _mapAmount = h;
      if ((lower.contains('memo') || lower.contains('desc') || lower.contains('payee')) && _mapDescription == null) _mapDescription = h;
      if (lower.contains('type') && _mapType == null) _mapType = h;
      if (lower.contains('owner') && _mapOwner == null) _mapOwner = h;
      if (lower.contains('pool') && _mapPool == null) _mapPool = h;
      if ((lower.contains('label') || lower.contains('category')) && _mapLabel == null) _mapLabel = h;
      if ((lower.contains('currency') || lower.contains('curr') || lower.contains('fx')) && _mapCurrency == null) _mapCurrency = h;
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? 'zaznamity';
    if (mounted) {
      setState(() {
        _isZaznamityMode = (savedTheme == 'zaznamity');
      });
    }
  }

  Future<void> _processImport() async {
    if (_mapDate == null || _mapAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please map at least Date and Amount columns.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final prefs = await SharedPreferences.getInstance();
    final primaryCurrency = prefs.getString('primaryCurrency') ?? 'USD';

    int importedCount = 0;
    int dateIndex = widget.headers.indexOf(_mapDate!);
    int amountIndex = widget.headers.indexOf(_mapAmount!);
    int descIndex = _mapDescription != null ? widget.headers.indexOf(_mapDescription!) : -1;
    int typeIndex = _mapType != null ? widget.headers.indexOf(_mapType!) : -1;
    int ownerIndex = _mapOwner != null ? widget.headers.indexOf(_mapOwner!) : -1;
    int poolIndex = _mapPool != null ? widget.headers.indexOf(_mapPool!) : -1;
    int labelIndex = _mapLabel != null ? widget.headers.indexOf(_mapLabel!) : -1;
    int currencyIndex = _mapCurrency != null ? widget.headers.indexOf(_mapCurrency!) : -1;

    List<String> activeOwners = List.from(widget.owners);
    List<LabelModel> activeLabels = List.from(widget.labels);
    List<String> activePools = List.from(widget.pools);

    for (int i = 1; i < widget.lines.length; i++) {
      String line = widget.lines[i].trim();
      if (line.isEmpty) continue;

      List<String> cols = CsvImportMapperWorkflow._parseCsvRow(line);
      if (cols.length <= dateIndex || cols.length <= amountIndex) continue;

      try {
        String dateStr = cols[dateIndex].trim();
        DateTime parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

        String rawAmount = cols[amountIndex]
            .replaceAll(RegExp(r'[^0-9.,\-]'), '')
            .replaceAll(',', '.')
            .trim();
        double amount = double.tryParse(rawAmount) ?? 0.0;

        String description = (descIndex != -1 && cols.length > descIndex && cols[descIndex].isNotEmpty) 
            ? cols[descIndex].trim() 
            : 'Imported transaction';

        String type = 'expense';
        if (typeIndex != -1 && cols.length > typeIndex) {
          String val = cols[typeIndex].toLowerCase();
          if (val.contains('inc') || val.contains('deposit') || val.contains('príjem') || amount > 0) {
            type = 'income';
          }
        } else if (amount > 0) {
          type = 'income';
        }
        amount = amount.abs();

        String currencyCode = primaryCurrency;
        if (currencyIndex != -1 && cols.length > currencyIndex) {
          String val = cols[currencyIndex].trim().toUpperCase();
          if (val.isNotEmpty) {
            currencyCode = val;
          }
        }

        String owner = activeOwners.isNotEmpty ? activeOwners.first : 'Shared';
        if (ownerIndex != -1 && cols.length > ownerIndex) {
          String val = cols[ownerIndex].trim();
          if (val.isNotEmpty) {
            if (activeOwners.contains(val)) {
              owner = val;
            } else if (_createMissingOwners) {
              activeOwners.add(val);
              owner = val;
            }
          }
        }

        String pool = 'checking';
        if (poolIndex != -1 && cols.length > poolIndex) {
          String val = cols[poolIndex].trim().toLowerCase();
          if (val.isNotEmpty) {
            if (activePools.contains(val)) {
              pool = val;
            } else if (_createMissingPools) {
              activePools.add(val);
              pool = val;
            }
          }
        }

        int labelId = activeLabels.isNotEmpty ? activeLabels.first.id : 1;
        if (labelIndex != -1 && cols.length > labelIndex) {
          String labelName = cols[labelIndex].trim();
          if (labelName.isNotEmpty) {
            bool found = false;
            for (var l in activeLabels) {
              if (l.name.toLowerCase() == labelName.toLowerCase()) {
                labelId = l.id;
                found = true;
                break;
              }
            }
            if (!found && _createMissingLabels) {
              await DatabaseHelper.instance.insertLabel(labelName, '#4338CA');
              final refreshedLabels = await DatabaseHelper.instance.getLabels();
              activeLabels = refreshedLabels;
              for (var l in activeLabels) {
                if (l.name.toLowerCase() == labelName.toLowerCase()) {
                  labelId = l.id;
                  break;
                }
              }
            }
          }
        }

        int confirmedValue = 1;
        if (_autoDetectFuture && parsedDate.isAfter(DateTime.now())) {
          confirmedValue = 0;
        }

        final newTx = TransactionModel(
          createdAt: parsedDate.toIso8601String(),
          description: description,
          amount: amount,
          type: type,
          labelId: labelId,
          owner: owner,
          pool: pool,
          isConfirmed: confirmedValue,
          isSavings: pool == 'savings' ? 1 : 0,
          currencyCode: currencyCode,
        );

        await DatabaseHelper.instance.insertTransaction(newTx);
        importedCount++;
      } catch (e) {
        debugPrint('Skipped row due to parse error: $e');
      }
    }

    if (!context.mounted) return;
    Navigator.pop(context);
    widget.onImportCompleted();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully imported $importedCount transactions!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Map CSV Columns',
        style: TextStyle(
          color: _isZaznamityMode ? Colors.white : const Color(0xFF582F95),
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Match your spreadsheet columns to Zaznamity fields below:',
                style: TextStyle(
                  fontSize: 12,
                  color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              _buildDropdownMapping('Date Column *', _mapDate, (val) => setState(() => _mapDate = val)),
              _buildDropdownMapping('Amount Column *', _mapAmount, (val) => setState(() => _mapAmount = val)),
              _buildDropdownMapping('Description / Memo', _mapDescription, (val) => setState(() => _mapDescription = val)),
              _buildDropdownMapping('Type (Income/Expense)', _mapType, (val) => setState(() => _mapType = val)),
              _buildDropdownMapping('Currency', _mapCurrency, (val) => setState(() => _mapCurrency = val)),
              _buildDropdownMapping('Owner', _mapOwner, (val) => setState(() => _mapOwner = val)),
              _buildDropdownMapping('Pool', _mapPool, (val) => setState(() => _mapPool = val)),
              _buildDropdownMapping('Label / Category', _mapLabel, (val) => setState(() => _mapLabel = val)),
              Text(
                'Configure Future/Pending transactions and missing elements:',
                style: TextStyle(
                  fontSize: 12,
                  color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Auto-set Future transactions',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87),
                ),
                subtitle: Text(
                  'Flag transactions with dates after today as future items.',
                  style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B)),
                ),
                value: _autoDetectFuture,
                activeColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                checkColor: Colors.white,
                onChanged: (val) => setState(() => _autoDetectFuture = val ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Auto-create missing Owners',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87),
                ),
                subtitle: Text(
                  'Create new owners found in CSV automatically.',
                  style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B)),
                ),
                value: _createMissingOwners,
                activeColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                checkColor: Colors.white,
                onChanged: (val) => setState(() => _createMissingOwners = val ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Auto-create missing Labels',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87),
                ),
                subtitle: Text(
                  'Create new labels/categories found in CSV automatically.',
                  style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B)),
                ),
                value: _createMissingLabels,
                activeColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                checkColor: Colors.white,
                onChanged: (val) => setState(() => _createMissingLabels = val ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Auto-create missing Pools',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isZaznamityMode ? Colors.white : Colors.black87),
                ),
                subtitle: Text(
                  'Create new asset pools found in CSV automatically.',
                  style: TextStyle(fontSize: 10, color: _isZaznamityMode ? Colors.white70 : const Color(0xFF64748B)),
                ),
                value: _createMissingPools,
                activeColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
                checkColor: Colors.white,
                onChanged: (val) => setState(() => _createMissingPools = val ?? true),
              ),
              Text(
                'All elements can be edited in Zaznamity Settings after the successful import.',
                style: TextStyle(
                  fontSize: 12,
                  color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: _isZaznamityMode ? const Color(0xFFC4B5FD) : const Color(0xFF64748B)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isZaznamityMode ? const Color(0xFFA855F7) : const Color(0xFF582F95),
            foregroundColor: Colors.white,
          ),
          onPressed: _isProcessing ? null : _processImport,
          child: _isProcessing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Import CSV'),
        ),
      ],
    );
  }

  Widget _buildDropdownMapping(String label, String? selectedValue, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _isZaznamityMode ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _isZaznamityMode ? const Color(0xFF1E1333) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isZaznamityMode ? Colors.white12 : const Color(0xFFCBD5E1),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedValue,
                  isDense: true,
                  isExpanded: true,
                  dropdownColor: _isZaznamityMode ? const Color(0xFF2D1B4E) : Colors.white,
                  style: TextStyle(
                    fontSize: 11,
                    color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                  ),
                  hint: Text(
                    'Select Column',
                    style: TextStyle(
                      fontSize: 10,
                      color: _isZaznamityMode ? Colors.white54 : const Color(0xFF94A3B8),
                    ),
                  ),
                  items: widget.headers.map((h) => DropdownMenuItem(
                    value: h,
                    child: Text(
                      h,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _isZaznamityMode ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  )).toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}