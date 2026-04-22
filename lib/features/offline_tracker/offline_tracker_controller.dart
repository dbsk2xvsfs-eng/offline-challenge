import 'dart:async';

import 'active_session.dart';
import 'local_storage_service.dart';
import 'session_history_service.dart';
import 'session_model.dart';

import 'stats_model.dart';
import 'stats_service.dart';

class OfflineTrackerController {
  final LocalStorageService _storage = LocalStorageService();
  final SessionHistoryService _historyService = SessionHistoryService();

  ActiveSession session = const ActiveSession(
    isRunning: false,
  );

  final StatsService _statsService = StatsService();

  Timer? _ticker;

  Future<void> init() async {
    session = await _storage.loadCurrentSession();
  }

  Future<StatsModel> loadStats() async {
    final history = await _historyService.loadHistory();
    return _statsService.calculate(history);
  }

  Future<void> start() async {
    if (session.isRunning) return;

    session = session.copyWith(
      isRunning: true,
      startedAt: DateTime.now(),
    );

    await _saveCurrent();
  }

  Future<void> stop() async {
    if (!session.isRunning) return;

    final now = DateTime.now();
    final start = session.startedAt ?? now;
    final minutes = now.difference(start).inMinutes;

    if (minutes >= 1) {
      final finishedSession = SessionModel(
        startedAt: start,
        durationMinutes: minutes,
      );

      await _historyService.addSession(finishedSession);
    }

    session = const ActiveSession(
      isRunning: false,
    );

    await _saveCurrent();
  }

  Future<void> reset() async {
    session = const ActiveSession(
      isRunning: false,
    );
    await _saveCurrent();
  }

  Future<List<SessionModel>> loadHistory() async {
    return _historyService.loadHistory();
  }

  Future<void> clearHistory() async {
    await _historyService.clearHistory();
  }

  int get currentElapsedMinutes {
    if (!session.isRunning || session.startedAt == null) return 0;
    return DateTime.now().difference(session.startedAt!).inMinutes;
  }

  Future<void> _saveCurrent() async {
    await _storage.saveCurrentSession(session);
  }

  void dispose() {
    _ticker?.cancel();
  }
}