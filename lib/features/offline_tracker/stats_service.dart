import 'session_model.dart';
import 'stats_model.dart';

class StatsService {
  StatsModel calculate(List<SessionModel> sessions) {
    final now = DateTime.now();

    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    int todayMinutes = 0;
    int weekMinutes = 0;
    int monthMinutes = 0;

    for (final session in sessions) {
      final date = session.startedAt;

      if (!date.isBefore(todayStart)) {
        todayMinutes += session.durationMinutes;
      }

      if (!date.isBefore(weekStart)) {
        weekMinutes += session.durationMinutes;
      }

      if (!date.isBefore(monthStart)) {
        monthMinutes += session.durationMinutes;
      }
    }

    return StatsModel(
      todayMinutes: todayMinutes,
      weekMinutes: weekMinutes,
      monthMinutes: monthMinutes,
    );
  }
}