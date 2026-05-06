import 'session_model.dart';
import 'best_stats_model.dart';
import 'daily_goal_service.dart';
import 'offline_counting_settings_service.dart';
import 'offline_counting_service.dart';

class BestStatsService {
  final DailyGoalService _goalService = DailyGoalService();

  final OfflineCountingSettingsService _settingsService =
  OfflineCountingSettingsService();

  final OfflineCountingService _countingService = OfflineCountingService();

  Future<BestStatsModel> calculate(List<SessionModel> sessions) async {
    final goal = await _goalService.loadGoalMinutes();

    final excludeSleep = await _settingsService.loadExcludeSleepTime();
    final sleepStart = await _settingsService.loadSleepStart();
    final sleepEnd = await _settingsService.loadSleepEnd();

    final Map<String, int> dayMap = {};
    final Map<String, int> weekMap = {};
    final Map<String, int> monthMap = {};

    for (final s in sessions) {
      final d = s.startedAt;

      final countedMinutes = _countingService.countedMinutes(
        session: s,
        excludeSleep: excludeSleep,
        sleepStartHour: sleepStart.hour,
        sleepStartMinute: sleepStart.minute,
        sleepEndHour: sleepEnd.hour,
        sleepEndMinute: sleepEnd.minute,
      );

      final dayKey = '${d.year}-${d.month}-${d.day}';
      final weekKey = _weekKey(d);
      final monthKey = '${d.year}-${d.month}';

      dayMap[dayKey] = (dayMap[dayKey] ?? 0) + countedMinutes;
      weekMap[weekKey] = (weekMap[weekKey] ?? 0) + countedMinutes;
      monthMap[monthKey] = (monthMap[monthKey] ?? 0) + countedMinutes;
    }

    final bestDay = _max(dayMap);
    final bestWeek = _max(weekMap);
    final bestMonth = _max(monthMap);

    final streak = _calculateCurrentStreak(dayMap, goal);
    final bestStreak = _calculateBestStreak(dayMap, goal);

    return BestStatsModel(
      bestDayMinutes: bestDay,
      bestWeekMinutes: bestWeek,
      bestMonthMinutes: bestMonth,
      streakDays: streak,
      bestStreakDays: bestStreak,
      dailyGoalMinutes: goal,
    );
  }

  int _max(Map<String, int> map) {
    if (map.isEmpty) return 0;
    return map.values.reduce((a, b) => a > b ? a : b);
  }

  String _weekKey(DateTime d) {
    final weekStart = d.subtract(Duration(days: d.weekday - 1));
    return '${weekStart.year}-${weekStart.month}-${weekStart.day}';
  }

  int _calculateCurrentStreak(Map<String, int> dayMap, int goal) {
    int streak = 0;
    DateTime current = DateTime.now();

    while (true) {
      final key = '${current.year}-${current.month}-${current.day}';
      final minutes = dayMap[key] ?? 0;

      if (minutes >= goal) {
        streak++;
        current = current.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  int _calculateBestStreak(Map<String, int> dayMap, int goal) {
    if (dayMap.isEmpty) return 0;

    final dates = dayMap.keys
        .map((k) {
      final parts = k.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    })
        .toList()
      ..sort();

    int best = 0;
    int current = 0;
    DateTime? prev;

    for (final d in dates) {
      final key = '${d.year}-${d.month}-${d.day}';
      final minutes = dayMap[key] ?? 0;

      if (minutes >= goal) {
        if (prev != null && d.difference(prev).inDays == 1) {
          current++;
        } else {
          current = 1;
        }

        if (current > best) best = current;
      } else {
        current = 0;
      }

      prev = d;
    }

    return best;
  }
}