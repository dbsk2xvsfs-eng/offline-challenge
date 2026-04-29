import 'package:flutter/material.dart';

class StatsDetailScreen extends StatelessWidget {
  final String title;
  final String currentLabel;
  final int currentMinutes;
  final int averageMinutes;
  final List<int> chartValues;

  const StatsDetailScreen({
    super.key,
    required this.title,
    required this.currentLabel,
    required this.currentMinutes,
    required this.averageMinutes,
    required this.chartValues,
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
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[index];
    }

    if (count == 4) return 'W${index + 1}';
    if (count == 6) return 'M${index + 1}';

    return '${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final values = chartValues.isEmpty ? List<int>.filled(7, 0) : chartValues;

    final maxValue = values.fold<int>(
      1,
          (max, value) => value > max ? value : max,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _InfoCard(
                      title: currentLabel,
                      value: _formatMinutes(currentMinutes),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoCard(
                      title: 'Average',
                      value: _formatMinutes(averageMinutes),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'Progress',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: values.asMap().entries.map((entry) {
                      final index = entry.key;
                      final value = entry.value;
                      final isZero = value == 0;

                      final heightFactor =
                      isZero ? 0.015 : (value / maxValue).clamp(0.08, 1.0);

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor: heightFactor,
                                    child: AnimatedContainer(
                                      duration:
                                      const Duration(milliseconds: 350),
                                      curve: Curves.easeOutCubic,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: isZero
                                            ? Colors.grey.shade300
                                            : Colors.blue,
                                        borderRadius:
                                        BorderRadius.circular(10),
                                      ),
                                      child: isZero
                                          ? null
                                          : Center(
                                        child: RotatedBox(
                                          quarterTurns: 3,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              _formatMinutes(value),
                                              maxLines: 1,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight:
                                                FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                _bottomLabel(index, values.length),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
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
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;

  const _InfoCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 12,
        ),
        child: Column(
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}