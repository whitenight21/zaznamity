/// Parses an amount typed by a user.
///
/// Accepts both decimal separators and common grouping styles:
///   "12,50"  "12.50"  "1,234.56"  "1.234,56"  "1 234,56"  "EUR 1 234,5"
///
/// Rules:
///  * Currency symbols, letters and spaces (including non-breaking ones) are ignored.
///  * If both "." and "," appear, the LAST one is the decimal separator.
///  * If only one kind appears once, it is the decimal separator ("1,234" -> 1.234).
///  * If one kind appears several times, they are thousands separators and must
///    group by exactly three digits ("1,234,567" ok, "1.5.3" -> null).
///  * Returns null for empty or invalid input, and for negatives unless
///    [allowNegative] is true. "-5" and "(5)" both count as negative.
double? parseAmount(String? input, {bool allowNegative = false}) {
  if (input == null) return null;
  final raw = input.trim();
  if (raw.isEmpty) return null;

  final negative = raw.startsWith('-') ||
      raw.startsWith('\u2212') ||
      (raw.startsWith('(') && raw.endsWith(')'));

  var s = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
  if (s.isEmpty || !RegExp(r'[0-9]').hasMatch(s)) return null;

  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  var decimalSep = '';

  if (lastDot != -1 && lastComma != -1) {
    decimalSep = lastDot > lastComma ? '.' : ',';
  } else if (lastDot != -1 || lastComma != -1) {
    final sep = lastDot != -1 ? '.' : ',';
    if (sep.allMatches(s).length == 1) {
      decimalSep = sep;
    } else {
      // Repeated separator: must be valid thousands grouping.
      final parts = s.split(sep);
      if (parts.first.isEmpty ||
          parts.first.length > 3 ||
          parts.skip(1).any((p) => p.length != 3)) {
        return null;
      }
    }
  }

  if (decimalSep.isEmpty) {
    s = s.replaceAll('.', '').replaceAll(',', '');
  } else {
    final thousands = decimalSep == '.' ? ',' : '.';
    s = s.replaceAll(thousands, '').replaceAll(decimalSep, '.');
  }

  final value = double.tryParse(s);
  if (value == null || !value.isFinite) return null;
  if (value == 0) return 0.0;

  final signed = negative ? -value : value;
  if (signed < 0 && !allowNegative) return null;
  return signed;
}

/// Parses a whole number (for example a due day). Returns null if invalid.
int? parseInt(String? input) {
  if (input == null) return null;
  return int.tryParse(input.trim());
}

/// Turns a number into text for an input box, without float noise:
/// 1234.5 -> "1234.5", 1000.0 -> "1000", 3.125 -> "3.125".
String amountToInputText(double value) {
  var s = value.toStringAsFixed(4);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  s = s.replaceFirst(RegExp(r'\.$'), '');
  return s;
}
