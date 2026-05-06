import 'session_model.dart';

class OfflineCountingService {
  int countedMinutes({
    required SessionModel session,
    required bool excludeSleep,
    required int sleepStartHour,
    required int sleepStartMinute,
    required int sleepEndHour,
    required int sleepEndMinute,
  }) {
    if (!excludeSleep) return session.durationMinutes;

    final start = session.startedAt;
    final end = start.add(Duration(minutes: session.durationMinutes));

    int counted = 0;
    DateTime cursor = start;

    while (cursor.isBefore(end)) {
      final next = cursor.add(const Duration(minutes: 1));

      if (!_isInsideSleepWindow(
        cursor,
        sleepStartHour,
        sleepStartMinute,
        sleepEndHour,
        sleepEndMinute,
      )) {
        counted++;
      }

      cursor = next;
    }

    return counted;
  }

  bool _isInsideSleepWindow(
      DateTime time,
      int startHour,
      int startMinute,
      int endHour,
      int endMinute,
      ) {
    final minutes = time.hour * 60 + time.minute;
    final start = startHour * 60 + startMinute;
    final end = endHour * 60 + endMinute;

    if (start < end) {
      return minutes >= start && minutes < end;
    }

    return minutes >= start || minutes < end;
  }
}