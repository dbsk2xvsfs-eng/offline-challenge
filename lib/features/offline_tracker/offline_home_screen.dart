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
import 'package:share_plus/share_plus.dart';

import '../profile/profile_model.dart';
import '../profile/profile_service.dart';



class OfflineHomeScreen extends StatefulWidget {
  const OfflineHomeScreen({super.key});

  @override
  State<OfflineHomeScreen> createState() => _OfflineHomeScreenState();
}

class _OfflineHomeScreenState extends State<OfflineHomeScreen> {
  final controller = OfflineTrackerController();
  final LeaderboardService _leaderboardService = LeaderboardService();

  final ProfileService _profileService = ProfileService();

  ProfileModel _profile = const ProfileModel(
    nickname: '',
    city: 'Prague',
    country: 'CZ',
  );

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

  Future<void> _refreshProfile() async {
    final profile = await _profileService.loadProfile();

    _profile = ProfileModel(
      nickname: profile.nickname.isEmpty ? 'You' : profile.nickname,
      city: profile.city.isEmpty ? 'Prague' : profile.city,
      country: profile.country.isEmpty ? 'CZ' : profile.country,
    );
  }

  Future<void> _refreshStats() async {
    _stats = await controller.loadStats();
  }

  Future<void> _refreshBestStats() async {
    _bestStats = await controller.loadBestStats();
  }

  Future<void> _refreshRankingPreview() async {
    final users = _leaderboardService.filterUsers(
      users: _leaderboardService.loadFakeUsers(),
      scope: LeaderboardScope.city,
      period: LeaderboardPeriod.week,
      yourCountry: _profile.country,
      yourCity: _profile.city,
    );

    final youIndex = users.indexWhere((u) => u.isYou);
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await controller.init();
    await _refreshProfile();
    await _refreshStats();
    await _refreshRankingPreview();
    await _refreshBestStats();

    _uiTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours == 0) return '$mins min';
    if (mins == 0) return '$hours h';
    return '$hours h $mins min';
  }

  Widget _buildStatCard(
      String title,
      String value, {
        required double titleFont,
        required double valueFont,
        required bool isVerySmallPhone,
      }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isVerySmallPhone ? 8 : 10,
          horizontal: isVerySmallPhone ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: titleFont,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: isVerySmallPhone ? 3 : 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: valueFont,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingPreviewCard({
    required bool isVerySmallPhone,
  }) {
    if (_yourRank == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(isVerySmallPhone ? 10 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade600,
            Colors.blue.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events,
            color: Colors.white,
            size: isVerySmallPhone ? 22 : 24,
          ),
          SizedBox(width: isVerySmallPhone ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your rank: #$_yourRank',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isVerySmallPhone ? 14 : 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Out of $_participantCount • ${_profile.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isVerySmallPhone ? 11 : 12,
                    color: Colors.white70,
                  ),
                ),
                if (!isVerySmallPhone) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'This week',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: isVerySmallPhone ? 8 : 10),
          Text(
            formatMinutes(_yourRankMinutes),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isVerySmallPhone ? 14 : 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestStatsCompactCard({
    required bool isVerySmallPhone,
  }) {
    return Container(
      padding: EdgeInsets.all(isVerySmallPhone ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your best',
            style: TextStyle(
              fontSize: isVerySmallPhone ? 14 : 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isVerySmallPhone ? 6 : 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Day: ${formatMinutes(_bestStats.bestDayMinutes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: isVerySmallPhone ? 12 : 13),
                ),
              ),
              Expanded(
                child: Text(
                  'Week: ${formatMinutes(_bestStats.bestWeekMinutes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: isVerySmallPhone ? 12 : 13),
                ),
              ),
            ],
          ),
          SizedBox(height: isVerySmallPhone ? 3 : 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Month: ${formatMinutes(_bestStats.bestMonthMinutes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: isVerySmallPhone ? 12 : 13),
                ),
              ),
              Expanded(
                child: Text(
                  '🔥 ${_bestStats.streakDays} day streak',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isVerySmallPhone ? 12 : 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    final isSmallPhone = height < 760;
    final isVerySmallPhone = height < 700;

    final horizontalPadding = width < 380 ? 12.0 : 16.0;
    final topSpacing = isVerySmallPhone ? 8.0 : 12.0;
    final sectionSpacing = isVerySmallPhone ? 8.0 : 12.0;

    final titleFont = isVerySmallPhone ? 18.0 : 20.0;
    final timerFont = isVerySmallPhone ? 30.0 : (isSmallPhone ? 32.0 : 34.0);
    final statTitleFont = isVerySmallPhone ? 11.0 : 12.0;
    final statValueFont = isVerySmallPhone ? 13.0 : 14.0;
    final buttonHeight = isVerySmallPhone ? 42.0 : 46.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Challenge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final rankText = _yourRank != null
                  ? '#$_yourRank in Prague this week'
                  : 'tracking my offline time';

              final timeText = formatMinutes(_yourRankMinutes);

              final message =
                  'I am $rankText with $timeText offline.\n\nCan you beat me? 🔥\n\nJoin Offline Challenge.';

              Share.share(message);
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topSpacing,
            horizontalPadding,
            12,
          ),
          child: Column(
            children: [
              Text(
                session.isRunning
                    ? 'You are offline 🚀'
                    : 'Start your challenge',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: titleFont,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: sectionSpacing),
              Text(
                formatMinutes(currentMinutes),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: timerFont,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: sectionSpacing),
              Row(
                children: [
                  _buildStatCard(
                    'Today',
                    formatMinutes(_stats.todayMinutes),
                    titleFont: statTitleFont,
                    valueFont: statValueFont,
                    isVerySmallPhone: isVerySmallPhone,
                  ),
                  const SizedBox(width: 6),
                  _buildStatCard(
                    'Week',
                    formatMinutes(_stats.weekMinutes),
                    titleFont: statTitleFont,
                    valueFont: statValueFont,
                    isVerySmallPhone: isVerySmallPhone,
                  ),
                  const SizedBox(width: 6),
                  _buildStatCard(
                    'Month',
                    formatMinutes(_stats.monthMinutes),
                    titleFont: statTitleFont,
                    valueFont: statValueFont,
                    isVerySmallPhone: isVerySmallPhone,
                  ),
                ],
              ),
              SizedBox(height: sectionSpacing),
              _buildRankingPreviewCard(
                isVerySmallPhone: isVerySmallPhone,
              ),
              SizedBox(height: sectionSpacing),
              _buildBestStatsCompactCard(
                isVerySmallPhone: isVerySmallPhone,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.fromHeight(buttonHeight),
                  ),
                  onPressed: session.isRunning
                      ? null
                      : () async {
                    await controller.start();
                    setState(() {});
                  },
                  child: const Text('START OFFLINE'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.fromHeight(buttonHeight),
                  ),
                  onPressed: session.isRunning
                      ? () async {
                    await controller.stop();
                    await _refreshStats();
                    await _refreshRankingPreview();
                    await _refreshBestStats();
                    setState(() {});
                  }
                      : null,
                  child: const Text('STOP'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.fromHeight(
                      isVerySmallPhone ? 40 : 44,
                    ),
                  ),
                  onPressed: () async {
                    await controller.reset();
                    await _refreshStats();
                    await _refreshRankingPreview();
                    await _refreshBestStats();
                    setState(() {});
                  },
                  child: const Text('Reset current'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}