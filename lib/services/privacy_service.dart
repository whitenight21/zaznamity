// services/privacy_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyService {
  static final PrivacyService instance = PrivacyService._internal();
  PrivacyService._internal();

  final ValueNotifier<bool> isPrivacyModeEnabled = ValueNotifier<bool>(false);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isPrivacyModeEnabled.value = prefs.getBool('discretionary_privacy_mode') ?? false;
  }

  Future<void> togglePrivacyMode() async {
    isPrivacyModeEnabled.value = !isPrivacyModeEnabled.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('discretionary_privacy_mode', isPrivacyModeEnabled.value);
  }
}