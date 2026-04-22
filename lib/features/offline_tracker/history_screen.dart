import 'package:flutter/material.dart';

import 'history_filter.dart';
import 'offline_tracker_controller.dart';
import 'session_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final controller = OfflineTrackerController();

  bool loading = true;
  List<SessionModel> allSessions = [];

  HistoryPeriod selectedPeriod = HistoryPeriod.all;
  HistorySort selectedSort = HistorySort.byDateDesc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await controller.loadHistory();
    setState(() {
      allSessions = history;
      loading = false;
    });
  }

  String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours == 0) return '$mins min';
    if (mins == 0) return '$hours h';
    return '$hours h $mins min';
  }

  String formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }

  List<SessionModel> get filteredSessions {
    final now = DateTime.now();

    List<SessionModel> result = allSessions.where((s) {
      final ref = s.startedAt;

      switch (selectedPeriod) {
        case HistoryPeriod.all:
          return true;
        case HistoryPeriod.week:
          return ref.isAfter(now.subtract(const Duration(days: 7)));
        case HistoryPeriod.month:
          return ref.isAfter(DateTime(now.year, now.month - 1, now.day));
        case HistoryPeriod.year:
          return ref.isAfter(DateTime(now.year - 1, now.month, now.day));
      }
    }).toList();

    switch (selectedSort) {
      case HistorySort.byDateDesc:
        result.sort((a, b) => b.startedAt.compareTo(a.startedAt));
        break;
      case HistorySort.byDateAsc:
        result.sort((a, b) => a.startedAt.compareTo(b.startedAt));
        break;
      case HistorySort.byDurationDesc:
        result.sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
        break;
      case HistorySort.byDurationAsc:
        result.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
        break;
    }

    return result;
  }

  int get totalMinutesInFilter {
    return filteredSessions.fold(0, (sum, s) => sum + s.durationMinutes);
  }

  String periodLabel(HistoryPeriod p) {
    switch (p) {
      case HistoryPeriod.all:
        return 'All';
      case HistoryPeriod.week:
        return 'Week';
      case HistoryPeriod.month:
        return 'Month';
      case HistoryPeriod.year:
        return 'Year';
    }
  }

  String sortLabel(HistorySort s) {
    switch (s) {
      case HistorySort.byDateDesc:
        return 'Date ↓';
      case HistorySort.byDateAsc:
        return 'Date ↑';
      case HistorySort.byDurationDesc:
        return 'Time ↓';
      case HistorySort.byDurationAsc:
        return 'Time ↑';
    }
  }

  Future<void> _clearHistory() async {
    await controller.clearHistory();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = filteredSessions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: HistoryPeriod.values.map((p) {
                    return ChoiceChip(
                      label: Text(periodLabel(p)),
                      selected: selectedPeriod == p,
                      onSelected: (_) {
                        setState(() {
                          selectedPeriod = p;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                DropdownButton<HistorySort>(
                  value: selectedSort,
                  isExpanded: true,
                  items: HistorySort.values.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(sortLabel(s)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      selectedSort = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sessions: ${sessions.length}'),
                        const SizedBox(height: 6),
                        Text('Total time: ${formatMinutes(totalMinutesInFilter)}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: sessions.isEmpty
                ? const Center(child: Text('No sessions found'))
                : ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final item = sessions[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatMinutes(item.durationMinutes),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Date: ${formatDate(item.startedAt)}'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}