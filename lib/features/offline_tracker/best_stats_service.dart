import 'session_model.dart';
import 'best_stats_model.dart';

class BestStatsService {
  BestStatsModel calculate(List<SessionModel> sessions) {
    final Map<String, int> dayMap = {};
    final Map<String, int> weekMap = {};
    final Map<String, int> monthMap = {};

    for (final s in sessions) {
      final d = s.startedAt;

      final dayKey = '${d.year}-${d.month}-${d.day}';
      final weekKey = _weekKey(d);
      final monthKey = '${d.year}-${d.month}';

      dayMap[dayKey] = (dayMap[dayKey] ?? 0) + s.durationMinutes;
      weekMap[weekKey] = (weekMap[weekKey] ?? 0) + s.durationMinutes;
      monthMap[monthKey] = (monthMap[monthKey] ?? 0) + s.durationMinutes;
    }

    int bestDay = _max(dayMap);
    int bestWeek = _max(weekMap);
    int bestMonth = _max(monthMap);

    int streak = _calculateStreak(dayMap);

    return BestStatsModel(
      bestDayMinutes: bestDay,
      bestWeekMinutes: bestWeek,
      bestMonthMinutes: bestMonth,
      streakDays: streak,
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

  int _calculateStreak(Map<String, int> dayMap) {
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
      ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime current = DateTime.now();

    for (final d in dates) {
      final day = DateTime(d.year, d.month, d.day);
      final today = DateTime(current.year, current.month, current.day);

      if (day == today || day == today.subtract(const Duration(days: 1))) {
        streak++;
        current = day.subtract(const Duration(days: 1));
      } else if (day == today.subtract(Duration(days: streak))) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }
}