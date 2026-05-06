import 'package:shared_preferences/shared_preferences.dart';

class OfflineCountingSettingsService {
  static const _excludeSleepKey = 'exclude_sleep_time';
  static const _sleepStartHourKey = 'sleep_start_hour';
  static const _sleepStartMinuteKey = 'sleep_start_minute';
  static const _sleepEndHourKey = 'sleep_end_hour';
  static const _sleepEndMinuteKey = 'sleep_end_minute';

  Future<bool> loadExcludeSleepTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_excludeSleepKey) ?? false;
  }

  Future<void> saveExcludeSleepTime(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_excludeSleepKey, value);
  }

  Future<({int hour, int minute})> loadSleepStart() async {
    final prefs = await SharedPreferences.getInstance();
    return (
    hour: prefs.getInt(_sleepStartHourKey) ?? 22,
    minute: prefs.getInt(_sleepStartMinuteKey) ?? 0,
    );
  }

  Future<({int hour, int minute})> loadSleepEnd() async {
    final prefs = await SharedPreferences.getInstance();
    return (
    hour: prefs.getInt(_sleepEndHourKey) ?? 7,
    minute: prefs.getInt(_sleepEndMinuteKey) ?? 0,
    );
  }

  Future<void> saveSleepStart(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sleepStartHourKey, hour);
    await prefs.setInt(_sleepStartMinuteKey, minute);
  }

  Future<void> saveSleepEnd(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sleepEndHourKey, hour);
    await prefs.setInt(_sleepEndMinuteKey, minute);
  }
}