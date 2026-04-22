import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'active_session.dart';

class LocalStorageService {
  static const _currentSessionKey = 'current_session';

  Future<void> saveCurrentSession(ActiveSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentSessionKey, jsonEncode(session.toJson()));
  }

  Future<ActiveSession> loadCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_currentSessionKey);

    if (raw == null || raw.isEmpty) {
      return const ActiveSession(
        isRunning: false,
      );
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return ActiveSession.fromJson(decoded);
  }

  Future<void> clearCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentSessionKey);
  }
}