import 'package:shared_preferences/shared_preferences.dart';

class TrackingSettingsService {
  static const _trackingEnabledKey = 'tracking_enabled';

  Future<bool> isTrackingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trackingEnabledKey) ?? false;
  }

  Future<void> setTrackingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingEnabledKey, value);
  }
}