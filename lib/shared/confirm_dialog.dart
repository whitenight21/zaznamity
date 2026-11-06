import 'package:flutter/material.dart';
import 'zaznamity_palette.dart';

/// Generic confirmation dialog. Returns true only if the user confirms.
///
/// Set [typeToConfirm] for dangerous actions: the confirm button stays disabled
/// until the user types that text (case-insensitive).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  List<String> details = const [],
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  String? typeToConfirm,
  IconData? icon,
  ZPalette? palette,
}) async {
  final pal = palette ?? await ZPalette.load();
  if (!context.mounted) return false;

  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _ConfirmDialog(
      pal: pal,
      title: title,
      message: message,
      details: details,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      typeToConfirm: typeToConfirm,
      icon: icon,
    ),
  );
  return result ?? false;
}

/// Ready-made delete confirmation.
///
///   final ok = await showDeleteConfirmation(
///     context,
///     itemName: liability.name,
///     itemType: 'liability',
///     consequences: [
///       'The "${liability.name} (L)" label',
///       'All scheduled installments for it',
///     ],
///     requireTypedName: true,
///   );
///   if (ok) widget.onDeleteLiability(liability.id, liability.name);
Future<bool> showDeleteConfirmation(
  BuildContext context, {
  required String itemName,
  String itemType = 'item',
  List<String> consequences = const [],
  bool requireTypedName = false,
  ZPalette? palette,
}) {
  return showConfirmDialog(
    context,
    title: 'Delete $itemType?',
    message: 'Delete "$itemName"? This cannot be undone.',
    details: consequences,
    confirmLabel: 'Delete',
    destructive: true,
    typeToConfirm: requireTypedName ? itemName : null,
    palette: palette,
  );
}

class _ConfirmDialog extends StatefulWidget {
  final ZPalette pal;
  final String title;
  final String message;
  final List<String> details;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final String? typeToConfirm;
  final IconData? icon;

  const _ConfirmDialog({
    required this.pal,
    required this.title,
    required this.message,
    required this.details,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    required this.typeToConfirm,
    required this.icon,
  });

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final TextEditingController _controller = TextEditingController();

  bool get _typedOk {
    final needed = widget.typeToConfirm;
    if (needed == null) return true;
    return _controller.text.trim().toLowerCase() == needed.trim().toLowerCase();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    final actionColor = widget.destructive ? pal.danger : pal.accent;

    return AlertDialog(
      backgroundColor: pal.dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            widget.icon ??
                (widget.destructive ? Icons.delete_outline_rounded : Icons.help_outline_rounded),
            color: actionColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(color: pal.strong, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message, style: TextStyle(fontSize: 13, height: 1.4, color: pal.muted)),
            if (widget.details.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'This will also remove:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pal.muted),
              ),
              const SizedBox(height: 4),
              for (final d in widget.details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(fontSize: 13, color: pal.muted)),
                      Expanded(
                        child: Text(d, style: TextStyle(fontSize: 13, height: 1.3, color: pal.text)),
                      ),
                    ],
                  ),
                ),
            ],
            if (widget.typeToConfirm != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: pal.text, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Type "${widget.typeToConfirm}" to confirm',
                  hintStyle: TextStyle(color: pal.muted, fontSize: 12),
                  filled: true,
                  fillColor: pal.fieldBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: pal.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: pal.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: actionColor, width: 1.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(widget.cancelLabel, style: TextStyle(color: pal.muted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: actionColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: actionColor.withValues(alpha: 0.3),
            disabledForegroundColor: Colors.white54,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _typedOk ? () => Navigator.pop(context, true) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
