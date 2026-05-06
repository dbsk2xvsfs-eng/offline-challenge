import 'dart:async';

import 'active_session.dart';
import 'local_storage_service.dart';
import 'session_history_service.dart';
import 'session_model.dart';

import 'stats_model.dart';
import 'stats_service.dart';

import 'best_stats_model.dart';
import 'best_stats_service.dart';

import 'offline_counting_settings_service.dart';
import 'offline_counting_service.dart';

class OfflineTrackerController {
  final LocalStorageService _storage = LocalStorageService();
  final SessionHistoryService _historyService = SessionHistoryService();
  final BestStatsService _bestStatsService = BestStatsService();

  final StatsService _statsService = StatsService();

  final OfflineCountingSettingsService _countingSettingsService =
  OfflineCountingSettingsService();

  final OfflineCountingService _countingService = OfflineCountingService();

  ActiveSession session = const ActiveSession(
    isRunning: false,
  );

  Timer? _ticker;

  List<SessionModel> _cachedHistory = const [];

  List<SessionModel> loadHistorySync() {
    return _cachedHistory;
  }

  bool _excludeSleep = false;
  int _sleepStartHour = 22;
  int _sleepStartMinute = 0;
  int _sleepEndHour = 7;
  int _sleepEndMinute = 0;

  Future<void> init() async {
    session = await _storage.loadCurrentSession();
    await _loadCountingSettings();
  }

  Future<void> _loadCountingSettings() async {
    _excludeSleep = await _countingSettingsService.loadExcludeSleepTime();

    final sleepStart = await _countingSettingsService.loadSleepStart();
    final sleepEnd = await _countingSettingsService.loadSleepEnd();

    _sleepStartHour = sleepStart.hour;
    _sleepStartMinute = sleepStart.minute;
    _sleepEndHour = sleepEnd.hour;
    _sleepEndMinute = sleepEnd.minute;
  }

  int _countedMinutes(SessionModel session) {
    return _countingService.countedMinutes(
      session: session,
      excludeSleep: _excludeSleep,
      sleepStartHour: _sleepStartHour,
      sleepStartMinute: _sleepStartMinute,
      sleepEndHour: _sleepEndHour,
      sleepEndMinute: _sleepEndMinute,
    );
  }

  Future<StatsModel> loadStats() async {
    final history = await _historyService.loadHistory();

    _cachedHistory = history;
    await _loadCountingSettings();

    return await _statsService.calculate(history);
  }

  Future<BestStatsModel> loadBestStats() async {
    final history = await _historyService.loadHistory();
    return await _bestStatsService.calculate(history);
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

  int get dailyAverageMinutes {
    if (_cachedHistory.isEmpty) return 0;

    final total = _cachedHistory.fold<int>(
      0,
          (sum, s) => sum + _countedMinutes(s),
    );

    final days = _cachedHistory
        .map((s) {
      final d = s.startedAt.toLocal();
      return '${d.year}-${d.month}-${d.day}';
    })
        .toSet()
        .length;

    if (days == 0) return 0;
    return (total / days).round();
  }

  int get weeklyAverageMinutes {
    if (_cachedHistory.isEmpty) return 0;

    final total = _cachedHistory.fold<int>(
      0,
          (sum, s) => sum + _countedMinutes(s),
    );

    final weeks = _cachedHistory
        .map((s) {
      final d = s.startedAt.toLocal();
      final weekStart = d.subtract(Duration(days: d.weekday - 1));
      return '${weekStart.year}-${weekStart.month}-${weekStart.day}';
    })
        .toSet()
        .length;

    if (weeks == 0) return 0;
    return (total / weeks).round();
  }

  int get monthlyAverageMinutes {
    if (_cachedHistory.isEmpty) return 0;

    final total = _cachedHistory.fold<int>(
      0,
          (sum, s) => sum + _countedMinutes(s),
    );

    final months = _cachedHistory
        .map((s) {
      final d = s.startedAt.toLocal();
      return '${d.year}-${d.month}';
    })
        .toSet()
        .length;

    if (months == 0) return 0;
    return (total / months).round();
  }

  int get dailyAverageUntilNowMinutes {
    if (_cachedHistory.isEmpty) return 0;

    final now = DateTime.now();
    final todayMinutesFromMidnight = now.hour * 60 + now.minute;

    final totalsByDay = <String, int>{};

    for (final s in _cachedHistory) {
      final start = s.startedAt.toLocal();
      final dayKey = '${start.year}-${start.month}-${start.day}';

      final sessionMinuteOfDay = start.hour * 60 + start.minute;

      if (sessionMinuteOfDay <= todayMinutesFromMidnight) {
        totalsByDay[dayKey] =
            (totalsByDay[dayKey] ?? 0) + _countedMinutes(s);
      }
    }

    if (totalsByDay.isEmpty) return 0;

    final total = totalsByDay.values.fold<int>(0, (a, b) => a + b);
    return (total / totalsByDay.length).round();
  }

  int get weeklyAverageUntilNowMinutes {
    if (_cachedHistory.isEmpty) return 0;

    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final nowMinutes = now.hour * 60 + now.minute;

    final totalsByWeek = <String, int>{};

    for (final s in _cachedHistory) {
      final d = s.startedAt.toLocal();
      final weekStart = d.subtract(Duration(days: d.weekday - 1));
      final weekKey = '${weekStart.year}-${weekStart.month}-${weekStart.day}';

      final include =
          d.weekday < currentWeekday ||
              (d.weekday == currentWeekday &&
                  (d.hour * 60 + d.minute) <= nowMinutes);

      if (include) {
        totalsByWeek[weekKey] =
            (totalsByWeek[weekKey] ?? 0) + _countedMinutes(s);
      }
    }

    if (totalsByWeek.isEmpty) return 0;

    final total = totalsByWeek.values.fold<int>(0, (a, b) => a + b);
    return (total / totalsByWeek.length).round();
  }

  int get monthlyAverageUntilNowMinutes {
    if (_cachedHistory.isEmpty) return 0;

    final now = DateTime.now();
    final currentDay = now.day;
    final nowMinutes = now.hour * 60 + now.minute;

    final totalsByMonth = <String, int>{};

    for (final s in _cachedHistory) {
      final d = s.startedAt.toLocal();
      final monthKey = '${d.year}-${d.month}';

      final include =
          d.day < currentDay ||
              (d.day == currentDay &&
                  (d.hour * 60 + d.minute) <= nowMinutes);

      if (include) {
        totalsByMonth[monthKey] =
            (totalsByMonth[monthKey] ?? 0) + _countedMinutes(s);
      }
    }

    if (totalsByMonth.isEmpty) return 0;

    final total = totalsByMonth.values.fold<int>(0, (a, b) => a + b);
    return (total / totalsByMonth.length).round();
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

  List<int> get dailyChartValues {
    if (_cachedHistory.isEmpty) return List.filled(7, 0);

    final now = DateTime.now();

    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));

      final total = _cachedHistory
          .where((s) {
        final d = s.startedAt.toLocal();
        return d.year == day.year &&
            d.month == day.month &&
            d.day == day.day;
      })
          .fold<int>(0, (sum, s) => sum + _countedMinutes(s));

      return total;
    });
  }

  List<int> get weeklyChartValues {
    if (_cachedHistory.isEmpty) return List.filled(4, 0);

    final now = DateTime.now();

    return List.generate(4, (i) {
      final weekStart = now
          .subtract(Duration(days: now.weekday - 1))
          .subtract(Duration(days: (3 - i) * 7));

      final weekEnd = weekStart.add(const Duration(days: 6));

      final total = _cachedHistory
          .where((s) {
        final d = s.startedAt.toLocal();
        return !d.isBefore(weekStart) && !d.isAfter(weekEnd);
      })
          .fold<int>(0, (sum, s) => sum + _countedMinutes(s));

      return total;
    });
  }

  List<int> get monthlyChartValues {
    if (_cachedHistory.isEmpty) return List.filled(6, 0);

    final now = DateTime.now();

    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - (5 - i), 1);

      final total = _cachedHistory
          .where((s) {
        final d = s.startedAt.toLocal();
        return d.year == month.year && d.month == month.month;
      })
          .fold<int>(0, (sum, s) => sum + _countedMinutes(s));

      return total;
    });
  }
}