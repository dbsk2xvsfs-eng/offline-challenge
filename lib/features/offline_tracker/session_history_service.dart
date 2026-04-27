import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'session_model.dart';

class SessionHistoryService {
  static const _historyKey = 'session_history';

  Future<List<SessionModel>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final rawList = prefs.getStringList(_historyKey) ?? [];

    final normalSessions = rawList
        .map((item) => SessionModel.fromJson(jsonDecode(item)))
        .toList();

    final nativeRaw = prefs.getString('native_session_history') ?? '[]';
    final decodedNative = jsonDecode(nativeRaw) as List;

    final nativeSessions = decodedNative
        .map((item) => SessionModel.fromJson(item as Map<String, dynamic>))
        .toList();

    return [
      ...normalSessions,
      ...nativeSessions,
    ];
  }

  Future<void> saveHistory(List<SessionModel> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = sessions.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_historyKey, encoded);
  }

  Future<void> addSession(SessionModel session) async {
    final current = await loadHistory();
    current.add(session);
    await saveHistory(current);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}