import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_settings_model.dart';

class NotificationSettingsService {
  static const _settingsKey = 'notification_settings';

  Future<NotificationSettingsModel> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);

    if (raw == null || raw.isEmpty) {
      return NotificationSettingsModel.defaults();
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return NotificationSettingsModel.fromJson(decoded);
  }

  Future<void> saveSettings(NotificationSettingsModel settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}