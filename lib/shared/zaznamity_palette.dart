import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The colours every card already uses, in one place.
///
/// `dark == true` is the "zaznamity" purple theme, `false` is the light theme
/// (same switch as `_isZaznamityMode` in your cards).
class ZPalette {
  final bool dark;
  const ZPalette(this.dark);

  /// Reads the saved theme (`app_theme`) from SharedPreferences.
  static Future<ZPalette> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ZPalette((prefs.getString('app_theme') ?? 'zaznamity') == 'zaznamity');
  }

  Color get dialogBg => dark ? const Color(0xFF2D1B4E) : Colors.white;
  Color get fieldBg => dark ? const Color(0xFF1E1333) : Colors.white;
  Color get border => dark ? Colors.white12 : const Color(0xFFCBD5E1);
  Color get title => dark ? Colors.white : const Color(0xFF582F95);
  Color get strong => dark ? Colors.white : const Color(0xFF1E293B);
  Color get text => dark ? Colors.white : Colors.black87;
  Color get muted => dark ? const Color(0xFFC4B5FD) : const Color(0xFF64748B);
  Color get accent => dark ? const Color(0xFFA855F7) : const Color(0xFF582F95);
  Color get danger => const Color(0xFFEF4444);
  Color get warning => const Color(0xFFF59E0B);
  Color get success => const Color(0xFF34D399);
}
