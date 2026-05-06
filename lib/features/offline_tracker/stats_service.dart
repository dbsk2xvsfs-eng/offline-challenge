import 'session_model.dart';
import 'stats_model.dart';
import 'offline_counting_settings_service.dart';
import 'offline_counting_service.dart';

class StatsService {
  final OfflineCountingSettingsService _settingsService =
  OfflineCountingSettingsService();

  final OfflineCountingService _countingService = OfflineCountingService();

  Future<StatsModel> calculate(List<SessionModel> sessions) async {
    final excludeSleep = await _settingsService.loadExcludeSleepTime();
    final sleepStart = await _settingsService.loadSleepStart();
    final sleepEnd = await _settingsService.loadSleepEnd();

    final now = DateTime.now();

    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    int todayMinutes = 0;
    int weekMinutes = 0;
    int monthMinutes = 0;

    for (final session in sessions) {
      final date = session.startedAt;

      final countedMinutes = _countingService.countedMinutes(
        session: session,
        excludeSleep: excludeSleep,
        sleepStartHour: sleepStart.hour,
        sleepStartMinute: sleepStart.minute,
        sleepEndHour: sleepEnd.hour,
        sleepEndMinute: sleepEnd.minute,
      );

      if (!date.isBefore(todayStart)) {
        todayMinutes += countedMinutes;
      }

      if (!date.isBefore(weekStart)) {
        weekMinutes += countedMinutes;
      }

      if (!date.isBefore(monthStart)) {
        monthMinutes += countedMinutes;
      }
    }

    return StatsModel(
      todayMinutes: todayMinutes,
      weekMinutes: weekMinutes,
      monthMinutes: monthMinutes,
    );
  }
}