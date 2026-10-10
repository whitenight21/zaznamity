import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
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

  bool _autoDetectFuture = true;
  bool _createMissingOwners = true;
  bool _createMissingLabels = true;
  bool _createMissingPools = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    for (var h in widget.headers) {
      final lower = h.toLowerCase();
      if (lower.contains('date') && _mapDate == null) _mapDate = h;
      if ((lower.contains('amount') || lower.contains('sum')) && _mapAmount == null) _mapAmount = h;
      if ((lower.contains('memo') || lower.contains('desc') || lower.contains('payee')) && _mapDescription == null) _mapDescription = h;
      if (lower.contains('type') && _mapType == null) _mapType = h;
      if (lower.contains('owner') && _mapOwner == null) _mapOwner = h;
      if (lower.contains('pool') && _mapPool == null) _mapPool = h;
      if ((lower.contains('label') || lower.contains('category')) && _mapLabel == null) _mapLabel = h;
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

    int importedCount = 0;
    int dateIndex = widget.headers.indexOf(_mapDate!);
    int amountIndex = widget.headers.indexOf(_mapAmount!);
    int descIndex = _mapDescription != null ? widget.headers.indexOf(_mapDescription!) : -1;
    int typeIndex = _mapType != null ? widget.headers.indexOf(_mapType!) : -1;
    int ownerIndex = _mapOwner != null ? widget.headers.indexOf(_mapOwner!) : -1;
    int poolIndex = _mapPool != null ? widget.headers.indexOf(_mapPool!) : -1;
    int labelIndex = _mapLabel != null ? widget.headers.indexOf(_mapLabel!) : -1;

    int isSavingsIndex = widget.headers.indexWhere((h) => h.toLowerCase() == 'is_savings');
    int isLoanIndex = widget.headers.indexWhere((h) => h.toLowerCase() == 'is_loan');

    // Local mutable lists to track newly created entries during import
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

        String rawAmount = cols[amountIndex].replaceAll(RegExp(r'[^0-9.\-]'), '').trim();
        double amount = double.tryParse(rawAmount) ?? 0.0;

        String description = descIndex != -1 && cols.length > descIndex ? cols[descIndex].trim() : 'Imported transaction';

        String type = 'expense';
        if (typeIndex != -1 && cols.length > typeIndex) {
          String val = cols[typeIndex].toLowerCase();
          if (val.contains('inc') || val.contains('deposit') || amount > 0) {
            type = 'income';
          }
        } else if (amount > 0) {
          type = 'income';
        }
        amount = amount.abs();

        // Owner Handling & Auto-Creation
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

        // Pool Handling & Auto-Creation
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
        } else {
          if (isSavingsIndex != -1 && cols.length > isSavingsIndex) {
            if (cols[isSavingsIndex].trim().toLowerCase() == 'true') pool = 'savings';
          }
          if (isLoanIndex != -1 && cols.length > isLoanIndex) {
            if (cols[isLoanIndex].trim().toLowerCase() == 'true') pool = 'loan';
          }
        }

        // Label Handling & Auto-Creation
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
        );

        await DatabaseHelper.instance.insertTransaction(newTx);
        importedCount++;
      } catch (_) {}
    }

    if (!context.mounted) return;
    Navigator.pop(context);
    widget.onImportCompleted();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully imported $importedCount transactions with auto-created entities!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Map CSV Columns', style: TextStyle(color: Color(0xFF582F95), fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Match your spreadsheet columns to Zaznamity fields below:',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              _buildDropdownMapping('Date Column *', _mapDate, (val) => setState(() => _mapDate = val)),
              _buildDropdownMapping('Amount Column *', _mapAmount, (val) => setState(() => _mapAmount = val)),
              _buildDropdownMapping('Description / Memo', _mapDescription, (val) => setState(() => _mapDescription = val)),
              _buildDropdownMapping('Type (Income/Expense)', _mapType, (val) => setState(() => _mapType = val)),
              _buildDropdownMapping('Owner', _mapOwner, (val) => setState(() => _mapOwner = val)),
              _buildDropdownMapping('Pool', _mapPool, (val) => setState(() => _mapPool = val)),
              _buildDropdownMapping('Label / Category', _mapLabel, (val) => setState(() => _mapLabel = val)),
              const Divider(height: 24),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-set Future transactions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: const Text('Flag transactions with dates after today as future items.', style: TextStyle(fontSize: 10)),
                value: _autoDetectFuture,
                activeColor: const Color(0xFF582F95),
                onChanged: (val) => setState(() => _autoDetectFuture = val ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-create missing Owners', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: const Text('Create new owners found in CSV automatically.', style: TextStyle(fontSize: 10)),
                value: _createMissingOwners,
                activeColor: const Color(0xFF582F95),
                onChanged: (val) => setState(() => _createMissingOwners = val ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-create missing Labels', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: const Text('Create new labels/categories found in CSV automatically.', style: TextStyle(fontSize: 10)),
                value: _createMissingLabels,
                activeColor: const Color(0xFF582F95),
                onChanged: (val) => setState(() => _createMissingLabels = val ?? true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-create missing Pools', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: const Text('Create new asset pools found in CSV automatically.', style: TextStyle(fontSize: 10)),
                value: _createMissingPools,
                activeColor: const Color(0xFF582F95),
                onChanged: (val) => setState(() => _createMissingPools = val ?? true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF582F95), foregroundColor: Colors.white),
          onPressed: _isProcessing ? null : _processImport,
          child: _isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Import CSV'),
        ),
      ],
    );
  }

  Widget _buildDropdownMapping(String label, String? selectedValue, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedValue,
                  isDense: true,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B)),
                  hint: const Text('Select Column', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  items: widget.headers.map((h) => DropdownMenuItem(value: h, child: Text(h, overflow: TextOverflow.ellipsis))).toList(),
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