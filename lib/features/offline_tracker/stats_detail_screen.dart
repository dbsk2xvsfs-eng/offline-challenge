import 'package:flutter/material.dart';
import 'session_model.dart';
import 'offline_counting_settings_service.dart';
import 'dart:math' as math;

class StatsDetailScreen extends StatelessWidget {
  final String title;
  final String currentLabel;
  final int currentMinutes;
  final int averageMinutes;
  final List<int> chartValues;
  final List<SessionModel> sessions;

  const StatsDetailScreen({
    super.key,
    required this.title,
    required this.currentLabel,
    required this.currentMinutes,
    required this.averageMinutes,
    required this.chartValues,
    required this.sessions,
  });

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;

    if (h == 0) return '$m min';
    if (m == 0) return '$h h';
    return '$h h $m min';
  }

  String _bottomLabel(int index, int count) {
    if (count == 7) {
      final today = DateTime.now();
      final date = today.subtract(Duration(days: 6 - index));

      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    }

    if (count == 4) {
      return 'W${index + 1}';
    }

    if (count == 6) {
      return 'M${index + 1}';
    }

    return '${index + 1}';
  }

  int _maxForPeriod(int count) {
    if (count == 7) return 24 * 60;
    if (count == 4) return 7 * 24 * 60;
    if (count == 6) return 30 * 24 * 60;
    return 24 * 60;
  }

  Future<_SleepWindow> _loadSleepWindow() async {
    final service = OfflineCountingSettingsService();

    final start = await service.loadSleepStart();
    final end = await service.loadSleepEnd();

    return _SleepWindow(
      startMinute: start.hour * 60 + start.minute,
      endMinute: end.hour * 60 + end.minute,
    );
  }

  _PiePeriod _periodForTitle(String title) {
    final now = DateTime.now();
    final lower = title.toLowerCase();

    if (lower.contains('weekly')) {
      final start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));

      return _PiePeriod(
        start: start,
        end: start.add(const Duration(days: 7)),
        label: '7 d',
      );
    }

    if (lower.contains('monthly')) {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 1);
      final days = end.difference(start).inDays;

      return _PiePeriod(
        start: start,
        end: end,
        label: '$days d',
      );
    }

    final start = DateTime(now.year, now.month, now.day);

    return _PiePeriod(
      start: start,
      end: start.add(const Duration(days: 1)),
      label: '24 h',
    );
  }

  @override
  Widget build(BuildContext context) {
    final originalMedia = MediaQuery.of(context);
    final h = originalMedia.size.height;
    final w = originalMedia.size.width;

    final veryCompact = h < 780;
    final compact = h < 860;

    final values = chartValues.isEmpty ? List<int>.filled(7, 0) : chartValues;
    final maxMinutes = _maxForPeriod(values.length);

    final pagePadding = w < 380 ? 10.0 : 12.0;
    final pieSize = veryCompact ? 210.0 : (compact ? 230.0 : 250.0);
    final topCardHeight = veryCompact ? 82.0 : 92.0;
    final legendFont = veryCompact ? 10.0 : 11.0;
    final barPaddingTop = veryCompact ? 10.0 : 12.0;
    final barWidth = veryCompact ? 34.0 : 38.0;

    return MediaQuery(
      data: originalMedia.copyWith(
        textScaler: const TextScaler.linear(0.88),
      ),
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: veryCompact ? 42 : 46,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pagePadding, 6, pagePadding, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: topCardHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          title: currentLabel,
                          value: _formatMinutes(currentMinutes),
                          compact: compact,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoCard(
                          title: 'Average',
                          value: _formatMinutes(averageMinutes),
                          compact: compact,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: veryCompact ? 8 : 10),

                Text(
                  'Progress',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: veryCompact ? 19 : 21,
                  ),
                ),

                const SizedBox(height: 3),

                Wrap(
                  spacing: 8,
                  runSpacing: 3,
                  children: [
                    _LegendDot(color: Colors.green, label: 'Offline'),
                    _LegendDot(color: Colors.redAccent, label: 'Online'),
                    _LegendDot(color: Colors.deepPurple, label: 'Sleep'),
                    _LegendDot(color: Colors.blueGrey, label: 'Future'),
                  ],
                ),

                SizedBox(height: veryCompact ? 2 : 4),

                Center(
                  child: FutureBuilder<_SleepWindow>(
                    future: _loadSleepWindow(),
                    builder: (context, snapshot) {
                      final sleep = snapshot.data ??
                          const _SleepWindow(
                            startMinute: 22 * 60,
                            endMinute: 7 * 60,
                          );

                      final period = _periodForTitle(title);

                      return SizedBox(
                        width: pieSize,
                        height: pieSize,
                        child: _TimePieChart(
                          sessions: sessions,
                          periodStart: period.start,
                          periodEnd: period.end,
                          totalLabel: period.label,
                          sleepStartMinute: sleep.startMinute,
                          sleepEndMinute: sleep.endMinute,
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(height: veryCompact ? 6 : 8),

                SizedBox(
                  height: veryCompact ? 180 : 200,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      8,
                      barPaddingTop,
                      8,
                      veryCompact ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: values.asMap().entries.map((entry) {
                        final index = entry.key;
                        final offline = entry.value.clamp(0, maxMinutes);
                        final remaining = maxMinutes - offline;

                        final minVisibleOffline = (maxMinutes * 0.06).round();

                        final visibleOffline = offline <= 0
                            ? 1
                            : (offline < minVisibleOffline
                            ? minVisibleOffline
                            : offline);

                        final visibleRemaining =
                        (maxMinutes - visibleOffline).clamp(1, maxMinutes);

                        final offlineFlex = visibleOffline;
                        final remainingFlex = visibleRemaining;

                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: veryCompact ? 4 : 6,
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          flex: remainingFlex,
                                          child: Container(
                                            width: barWidth,
                                            color: Colors.red.withOpacity(0.55),
                                            child: remaining > 0
                                                ? Center(
                                              child: RotatedBox(
                                                quarterTurns: 3,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    _formatMinutes(
                                                      remaining,
                                                    ),
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize:
                                                      veryCompact
                                                          ? 10
                                                          : 11,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                                : null,
                                          ),
                                        ),
                                        Expanded(
                                          flex: offlineFlex,
                                          child: Container(
                                            width: barWidth,
                                            color: offline == 0
                                                ? Colors.grey.shade300
                                                : Colors.green,
                                            child: offline > 0
                                                ? Center(
                                              child: RotatedBox(
                                                quarterTurns: 3,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    _formatMinutes(offline),
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize:
                                                      veryCompact
                                                          ? 11
                                                          : 12,
                                                      fontWeight:
                                                      FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _bottomLabel(index, values.length),
                                  style: TextStyle(
                                    fontSize: veryCompact ? 10 : 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final bool compact;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.2,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 8 : 10,
          horizontal: 10,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: compact ? 13 : 14),
            ),
            const SizedBox(height: 5),
            FittedBox(
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 24 : 27,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepWindow {
  final int startMinute;
  final int endMinute;

  const _SleepWindow({
    required this.startMinute,
    required this.endMinute,
  });
}

class _PiePeriod {
  final DateTime start;
  final DateTime end;
  final String label;

  const _PiePeriod({
    required this.start,
    required this.end,
    required this.label,
  });
}

class _TimePieChart extends StatelessWidget {
  final List<SessionModel> sessions;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String totalLabel;
  final int sleepStartMinute;
  final int sleepEndMinute;

  const _TimePieChart({
    required this.sessions,
    required this.periodStart,
    required this.periodEnd,
    required this.totalLabel,
    required this.sleepStartMinute,
    required this.sleepEndMinute,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PiePainter(
        sessions: sessions,
        periodStart: periodStart,
        periodEnd: periodEnd,
        totalLabel: totalLabel,
        sleepStartMinute: sleepStartMinute,
        sleepEndMinute: sleepEndMinute,
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<SessionModel> sessions;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String totalLabel;
  final int sleepStartMinute;
  final int sleepEndMinute;

  _PiePainter({
    required this.sessions,
    required this.periodStart,
    required this.periodEnd,
    required this.totalLabel,
    required this.sleepStartMinute,
    required this.sleepEndMinute,
  });

  static const double _pi = 3.141592653589793;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.width < size.height ? size.width : size.height;
    final center = Offset(size.width / 2, size.height / 2);

    final strokeWidth = shortest * 0.11;
    final radius = shortest * 0.30;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final totalMinutes = periodEnd.difference(periodStart).inMinutes;
    final now = DateTime.now();

    Paint paint(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = color;

    final onlinePaint = paint(Colors.redAccent.withOpacity(0.72));
    final futurePaint = paint(Colors.blueGrey.withOpacity(0.35));
    final offlinePaint = paint(Colors.green);
    final sleepPaint = paint(Colors.deepPurple);

    double angleForMinute(int minute) {
      return -_pi / 2 + (minute / totalMinutes) * 2 * _pi;
    }

    double sweepForMinutes(int minutes) {
      return (minutes / totalMinutes) * 2 * _pi;
    }

    void drawRange(DateTime start, DateTime end, Paint p) {
      final s = start.isBefore(periodStart) ? periodStart : start;
      final e = end.isAfter(periodEnd) ? periodEnd : end;

      if (!e.isAfter(s)) return;

      final offset = s.difference(periodStart).inMinutes;
      final duration = e.difference(s).inMinutes;

      if (duration <= 0) return;

      canvas.drawArc(
        rect,
        angleForMinute(offset),
        sweepForMinutes(duration),
        false,
        p,
      );
    }

    // Weekly / monthly = aggregate chart, not day-by-day slices
    if (totalMinutes > 24 * 60) {
      final totalDays = periodEnd.difference(periodStart).inDays;

      int sleepMinutesPerDay;
      if (sleepStartMinute > sleepEndMinute) {
        sleepMinutesPerDay = (24 * 60 - sleepStartMinute) + sleepEndMinute;
      } else {
        sleepMinutesPerDay = sleepEndMinute - sleepStartMinute;
      }

      final sleepTotal = sleepMinutesPerDay * totalDays;

      final currentEnd = now.isBefore(periodEnd) ? now : periodEnd;
      final elapsedTotal = currentEnd.difference(periodStart).inMinutes.clamp(
        0,
        totalMinutes,
      );

      int offlineTotal = 0;

      for (final s in sessions) {
        final start = s.startedAt;
        final end = start.add(Duration(minutes: s.durationMinutes));

        final clippedStart = start.isBefore(periodStart) ? periodStart : start;
        final clippedEnd = end.isAfter(periodEnd) ? periodEnd : end;

        if (clippedEnd.isAfter(clippedStart)) {
          offlineTotal += clippedEnd.difference(clippedStart).inMinutes;
        }
      }

      offlineTotal = offlineTotal.clamp(0, totalMinutes - sleepTotal);

      final sleepElapsed = ((elapsedTotal / totalMinutes) * sleepTotal).round();

      int onlineTotal = elapsedTotal - sleepElapsed - offlineTotal;
      if (onlineTotal < 0) onlineTotal = 0;

      int futureTotal = totalMinutes - sleepTotal - offlineTotal - onlineTotal;
      if (futureTotal < 0) futureTotal = 0;

      double startAngle = -_pi / 2;

      void drawPart(int minutes, Paint p) {
        if (minutes <= 0) return;

        final sweep = sweepForMinutes(minutes);

        canvas.drawArc(
          rect,
          startAngle,
          sweep,
          false,
          p,
        );

        startAngle += sweep;
      }

      drawPart(sleepTotal, sleepPaint);
      drawPart(futureTotal, futurePaint);
      drawPart(onlineTotal, onlinePaint);
      drawPart(offlineTotal, offlinePaint);

      _drawCenterText(canvas, center);
      return;
    }

    // základ = budoucnost
    drawRange(periodStart, periodEnd, futurePaint);

    // proběhlý čas = online
    final currentEnd = now.isBefore(periodEnd) ? now : periodEnd;
    drawRange(periodStart, currentEnd, onlinePaint);

    // offline úseky
    for (final s in sessions) {
      final start = s.startedAt;
      final end = start.add(Duration(minutes: s.durationMinutes));
      drawRange(start, end, offlinePaint);
    }

    // sleep musí být navrchu: 00:00–wake up + sleep start–24:00
    DateTime day = DateTime(periodStart.year, periodStart.month, periodStart.day);

    while (day.isBefore(periodEnd)) {
      final sleepMorningStart = day;
      final sleepMorningEnd = day.add(Duration(minutes: sleepEndMinute));

      final sleepEveningStart = day.add(Duration(minutes: sleepStartMinute));
      final sleepEveningEnd = day.add(const Duration(days: 1));

      drawRange(sleepMorningStart, sleepMorningEnd, sleepPaint);
      drawRange(sleepEveningStart, sleepEveningEnd, sleepPaint);

      day = day.add(const Duration(days: 1));
    }

    _drawCenterText(canvas, center);

  }

  void _drawCenterText(Canvas canvas, Offset center) {
    final main = TextPainter(
      text: TextSpan(
        text: totalLabel,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 30,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    main.paint(
      canvas,
      Offset(center.dx - main.width / 2, center.dy - main.height / 2 - 12),
    );

    final sub = TextPainter(
      text: const TextSpan(
        text: 'Total time',
        style: TextStyle(
          color: Colors.black54,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    sub.paint(
      canvas,
      Offset(center.dx - sub.width / 2, center.dy - sub.height / 2 + 20),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

