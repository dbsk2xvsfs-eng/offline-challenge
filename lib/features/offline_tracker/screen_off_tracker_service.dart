import 'package:shared_preferences/shared_preferences.dart';

import 'session_history_service.dart';
import 'session_model.dart';

class ScreenOffTrackerService {
  static const _screenOffStartedAtKey = 'screen_off_started_at';
  static const int minimumSessionMinutes = 0;

  final SessionHistoryService _historyService = SessionHistoryService();

  Future<void> onScreenOff() async {
    final prefs = await SharedPreferences.getInstance();

    final alreadyStarted = prefs.getString(_screenOffStartedAtKey);
    if (alreadyStarted != null && alreadyStarted.isNotEmpty) return;

    await prefs.setString(
      _screenOffStartedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<bool> onScreenOn() async {
    final prefs = await SharedPreferences.getInstance();
    final rawStart = prefs.getString(_screenOffStartedAtKey);

    if (rawStart == null || rawStart.isEmpty) {
      return false;
    }

    await prefs.remove(_screenOffStartedAtKey);

    final startedAt = DateTime.tryParse(rawStart);
    if (startedAt == null) return false;

    final now = DateTime.now();
    final durationMinutes = now.difference(startedAt).inMinutes;

    if (durationMinutes < minimumSessionMinutes) {
      return false;
    }

    final session = SessionModel(
      startedAt: startedAt,
      durationMinutes: durationMinutes,
    );

    await _historyService.addSession(session);
    return true;
  }

  Future<DateTime?> getCurrentScreenOffStartedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final rawStart = prefs.getString(_screenOffStartedAtKey);

    if (rawStart == null || rawStart.isEmpty) return null;

    return DateTime.tryParse(rawStart);
  }

  Future<void> clearCurrentScreenOff() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_screenOffStartedAtKey);
  }
}