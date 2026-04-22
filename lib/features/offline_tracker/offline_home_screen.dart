import 'dart:async';

import 'package:flutter/material.dart';
import 'history_screen.dart';
import 'offline_tracker_controller.dart';

import 'stats_model.dart';

import '../leaderboard/leaderboard_screen.dart';

import '../leaderboard/leaderboard_filter.dart';
import '../leaderboard/leaderboard_service.dart';
import '../leaderboard/leaderboard_user_model.dart';

import 'best_stats_model.dart';


class OfflineHomeScreen extends StatefulWidget {
  const OfflineHomeScreen({super.key});

  @override
  State<OfflineHomeScreen> createState() => _OfflineHomeScreenState();
}

class _OfflineHomeScreenState extends State<OfflineHomeScreen> {
  final controller = OfflineTrackerController();
  final LeaderboardService _leaderboardService = LeaderboardService();
  List<LeaderboardUserModel> _leaderboardUsers = [];
  int? _yourRank;
  int _participantCount = 0;
  int _yourRankMinutes = 0;
  Timer? _uiTimer;
  bool _loading = true;

  StatsModel _stats = const StatsModel(
    todayMinutes: 0,
    weekMinutes: 0,
    monthMinutes: 0,
  );

  BestStatsModel _bestStats = const BestStatsModel(
    bestDayMinutes: 0,
    bestWeekMinutes: 0,
    bestMonthMinutes: 0,
    streakDays: 0,
  );

  Future<void> _refreshStats() async {
    _stats = await controller.loadStats();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshBestStats() async {
    _bestStats = await controller.loadBestStats();
  }

  Future<void> _refreshRankingPreview() async {
    final users = _leaderboardService.filterUsers(
      users: _leaderboardService.loadFakeUsers(),
      scope: LeaderboardScope.city, // můžeš změnit na country
      period: LeaderboardPeriod.week,
      yourCountry: 'CZ',
      yourCity: 'Prague',
    );

    final youIndex = users.indexWhere((u) => u.isYou);

    _leaderboardUsers = users;
    _participantCount = users.length;

    if (youIndex >= 0) {
      _yourRank = youIndex + 1;
      _yourRankMinutes = _leaderboardService.minutesForPeriod(
        users[youIndex],
        LeaderboardPeriod.week,
      );
    } else {
      _yourRank = null;
      _yourRankMinutes = 0;
    }
  }

  Widget _buildBestStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your best',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Best day'),
                Text(formatMinutes(_bestStats.bestDayMinutes)),
              ],
            ),
            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Best week'),
                Text(formatMinutes(_bestStats.bestWeekMinutes)),
              ],
            ),
            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Best month'),
                Text(formatMinutes(_bestStats.bestMonthMinutes)),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange),
                const SizedBox(width: 6),
                Text(
                  'Streak: ${_bestStats.streakDays} days',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingPreviewCard() {
    if (_yourRank == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade600,
            Colors.blue.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.white, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your rank: #$_yourRank',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Out of $_participantCount participants',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'This week • Prague',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatMinutes(_yourRankMinutes),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await controller.init();
    _stats = await controller.loadStats();
    await _refreshRankingPreview();
    await _refreshBestStats();

    _uiTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });

    setState(() {
      _loading = false;
    });
  }

  String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours == 0) return '$mins min';
    if (mins == 0) return '$hours h';
    return '$hours h $mins min';
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = controller.session;
    final currentMinutes = controller.currentElapsedMinutes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Challenge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LeaderboardScreen(),
                ),
              );
              if (mounted) {
                await _refreshRankingPreview();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistoryScreen(),
                ),
              );
              if (mounted) {
                await _refreshStats();
                await _refreshRankingPreview();
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              session.isRunning ? 'You are offline 🚀' : 'Start your challenge',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,

              ),
            ),
            const SizedBox(height: 24),
            Text(
              formatMinutes(currentMinutes),
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                _buildStatCard('Today', formatMinutes(_stats.todayMinutes)),
                const SizedBox(width: 8),
                _buildStatCard('Week', formatMinutes(_stats.weekMinutes)),
                const SizedBox(width: 8),
                _buildStatCard('Month', formatMinutes(_stats.monthMinutes)),
              ],
            ),

            const SizedBox(height: 16),
            _buildRankingPreviewCard(),

            const SizedBox(height: 16),
            _buildBestStatsCard(),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: session.isRunning
                    ? null
                    : () async {
                  await controller.start();
                  setState(() {});
                },
                child: const Text('Start offline'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: session.isRunning
                    ? () async {
                  await controller.stop();
                  await _refreshStats();
                  await _refreshRankingPreview();
                  await _refreshBestStats();
                  setState(() {});
                }
                    : null,
                child: const Text('Stop'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await controller.reset();
                  await _refreshStats();
                  await _refreshRankingPreview();
                  setState(() {});
                },
                child: const Text('Reset current'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}