// widgets/masked_amount.dart
import 'package:flutter/material.dart';
import '../services/privacy_service.dart';

class MaskedAmount extends StatelessWidget {
  final String formattedAmount;
  final TextStyle? style;

  const MaskedAmount({
    super.key,
    required this.formattedAmount,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PrivacyService.instance.isPrivacyModeEnabled,
      builder: (context, isPrivate, child) {
        // If privacy mode is active, replace digits with bullet/asterisk placeholders
        final displayText = isPrivate ? '••••••' : formattedAmount;

        return Text(
          displayText,
          style: style,
        );
      },
    );
  }
}