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
import 'tracking_settings_service.dart';
import 'screen_off_tracker_service.dart';
import 'native_tracking_service.dart';
import '../notifications/notification_settings_screen.dart';
import '../notifications/local_notification_service.dart';
import 'stats_detail_screen.dart';

import 'daily_goal_service.dart';

class OfflineHomeScreen extends StatefulWidget {
  const OfflineHomeScreen({super.key});

  @override
  State<OfflineHomeScreen> createState() => _OfflineHomeScreenState();
}

class _OfflineHomeScreenState extends State<OfflineHomeScreen>
    with WidgetsBindingObserver {
  final controller = OfflineTrackerController();
  final LeaderboardService _leaderboardService = LeaderboardService();

  final NativeTrackingService _nativeTrackingService = NativeTrackingService();
  final DailyGoalService _dailyGoalService = DailyGoalService();

  final ProfileService _profileService = ProfileService();
  final ScreenOffTrackerService _screenOffTrackerService =
  ScreenOffTrackerService();

  final TrackingSettingsService _trackingSettingsService =
  TrackingSettingsService();

  bool _trackingEnabled = false;

  ProfileModel _profile = const ProfileModel(
    nickname: '',
    city: 'Prague',
    country: 'CZ',
  );

  int? _yourRank;
  int _participantCount = 0;
  int _yourRankMinutes = 0;
  int _bestRankMinutes = 0;

  LeaderboardScope _leaderboardScope = LeaderboardScope.city;
  LeaderboardPeriod _leaderboardPeriod = LeaderboardPeriod.week;

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
    bestStreakDays: 0,
    dailyGoalMinutes: 120,
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

    final latestProfile = await _profileService.loadProfile();
    _profile = latestProfile;

    if (latestProfile.showInRankings) {
      await _leaderboardService.uploadMyStats(
        nickname: latestProfile.nickname.trim().isEmpty
            ? 'Anonymous'
            : latestProfile.nickname.trim(),
        country: latestProfile.country.trim().isEmpty
            ? 'UN'
            : latestProfile.country.trim().toUpperCase(),
        city: latestProfile.city.trim().isEmpty
            ? 'unknown'
            : latestProfile.city.trim().toLowerCase(),
        dayMinutes: _stats.todayMinutes,
        weekMinutes: _stats.weekMinutes,
        monthMinutes: _stats.monthMinutes,
        allMinutes: _stats.monthMinutes,
      );
    } else {
      await _leaderboardService.removeMeFromLeaderboard();
    }
  }

  Future<void> _refreshBestStats() async {
    _bestStats = await controller.loadBestStats();
  }

  Future<void> _showGoalPicker() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Set daily offline goal',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Choose how much offline time you want per day'),
              ),
              ListTile(
                title: const Text('30 min / day'),
                onTap: () => Navigator.pop(context, 30),
              ),
              ListTile(
                title: const Text('1 h / day'),
                onTap: () => Navigator.pop(context, 60),
              ),
              ListTile(
                title: const Text('2 h / day'),
                onTap: () => Navigator.pop(context, 120),
              ),
              ListTile(
                title: const Text('3 h / day'),
                onTap: () => Navigator.pop(context, 180),
              ),
              ListTile(
                title: const Text('4 h / day'),
                onTap: () => Navigator.pop(context, 240),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;

    await _dailyGoalService.saveGoalMinutes(selected);

    await _refreshBestStats();

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Daily goal set to ${formatMinutes(selected)} / day'),
      ),
    );
  }


  Future<void> _refreshRankingPreview() async {
    final users = await _leaderboardService.watchUsers(
      scope: _leaderboardScope,
      period: _leaderboardPeriod,
      yourCountry: _profile.country.isEmpty ? 'CZ' : _profile.country,
      yourCity: _profile.city.isEmpty ? 'Prague' : _profile.city,
    ).first;



    final youIndex = users.indexWhere((u) => u.isYou);

    _participantCount = users.length;

    _bestRankMinutes = users.isEmpty
        ? 0
        : _leaderboardService.minutesForPeriod(
      users.first,
      _leaderboardPeriod,
    );

    if (youIndex >= 0) {
      _yourRank = youIndex + 1;
      _yourRankMinutes = _leaderboardService.minutesForPeriod(
        users[youIndex],
        _leaderboardPeriod,
      );
    } else {
      _yourRank = null;
      _yourRankMinutes = 0;
    }

    if (mounted) {
      setState(() {});
    }
  }

  String _scopeLabel() {
    switch (_leaderboardScope) {
      case LeaderboardScope.city:
        return _profile.city;
      case LeaderboardScope.country:
        return _profile.country;
      case LeaderboardScope.global:
        return 'Global';
      case LeaderboardScope.friends:
        return 'Friends';
    }
  }

  String _periodLabel() {
    switch (_leaderboardPeriod) {
      case LeaderboardPeriod.day:
        return 'Today';
      case LeaderboardPeriod.week:
        return 'This week';
      case LeaderboardPeriod.month:
        return 'This month';
      case LeaderboardPeriod.all:
        return 'All time';
    }
  }

  Future<void> _showScopePicker() async {
    final selected = await showModalBottomSheet<LeaderboardScope>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Choose leaderboard',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.location_city),
              title: Text('City • ${_profile.city}'),
              onTap: () => Navigator.pop(context, LeaderboardScope.city),
            ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: Text('Country • ${_profile.country}'),
              onTap: () => Navigator.pop(context, LeaderboardScope.country),
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Friends'),
              subtitle: const Text('Private group'),
              onTap: () => Navigator.pop(context, LeaderboardScope.friends),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;

    setState(() {
      _leaderboardScope = selected;
    });

    await _refreshRankingPreview();

    if (mounted) setState(() {});
  }

  Future<void> _showPeriodPicker() async {
    final selected = await showModalBottomSheet<LeaderboardPeriod>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Choose period',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Today'),
              onTap: () => Navigator.pop(context, LeaderboardPeriod.day),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_week),
              title: const Text('This week'),
              onTap: () => Navigator.pop(context, LeaderboardPeriod.week),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('This month'),
              onTap: () => Navigator.pop(context, LeaderboardPeriod.month),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;

    setState(() {
      _leaderboardPeriod = selected;
    });

    await _refreshRankingPreview();

    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _testScreenOff() async {
    await _screenOffTrackerService.onScreenOff();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test: screen off started'),
      ),
    );
  }

  Future<void> _testScreenOn() async {
    final saved = await _screenOffTrackerService.onScreenOn();

    await _refreshStats();
    await _refreshBestStats();
    await _refreshRankingPreview();

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Test: session saved'
              : 'Test: session ignored, shorter than 60 min',
        ),
      ),
    );
  }

  Future<void> _startCollecting() async {
    await _trackingSettingsService.setTrackingEnabled(true);
    print("STARTING ANDROID SERVICE...");
    await _nativeTrackingService.startTrackingService();

    if (!mounted) return;

    setState(() {
      _trackingEnabled = true;
    });
  }

  Future<void> _stopCollecting() async {
    await _trackingSettingsService.setTrackingEnabled(false);
    await _nativeTrackingService.stopTrackingService();

    if (!mounted) return;

    setState(() {
      _trackingEnabled = false;
    });
  }

  Future<void> _refreshAll() async {
    await _refreshStats();
    await _refreshRankingPreview();
    await _refreshBestStats();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _init() async {
    await controller.init();

    _trackingEnabled = await _trackingSettingsService.isTrackingEnabled();

    if (_trackingEnabled) {
      await _nativeTrackingService.startTrackingService();
    }

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
      int currentMinutes,
      int averageMinutes, {
        required double titleFont,
        required double valueFont,
        required bool isVerySmallPhone,
      }) {
    final diff = currentMinutes - averageMinutes;
    final isUp = diff >= 0;

    final percent = averageMinutes == 0
        ? 0
        : ((diff / averageMinutes) * 100).round();

    final arrowIcon = isUp ? Icons.arrow_upward : Icons.arrow_downward;
    final arrowColor = isUp ? Colors.green : Colors.red;

    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      scale: 1.0,
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
            SizedBox(height: isVerySmallPhone ? 4 : 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  arrowIcon,
                  color: arrowColor,
                  size: isVerySmallPhone ? 18 : 20,
                ),
                const SizedBox(width: 4),
                Text(
                  formatMinutes(currentMinutes),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: valueFont,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 3),

            Text(
              averageMinutes == 0
                  ? 'vs avg: -'
                  : 'vs avg: ${formatMinutes(averageMinutes)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isVerySmallPhone ? 9 : 10,
                color: Colors.grey.shade600,
              ),
            ),

            if (averageMinutes > 0)
              Text(
                '${percent >= 0 ? '+' : ''}$percent%',
                maxLines: 1,
                style: TextStyle(
                  fontSize: isVerySmallPhone ? 9 : 10,
                  color: arrowColor,
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
    final rankingOff = !_profile.showInRankings;

    if (_yourRank == null && !rankingOff) {
      return const SizedBox.shrink();
    }

    final isLeading = _yourRank == 1;
    final diffMinutes = _bestRankMinutes - _yourRankMinutes;

    final percentBehind = _bestRankMinutes <= 0
        ? 0
        : ((diffMinutes / _bestRankMinutes) * 100).round();

    final statusText = isLeading
        ? '🏆 You are leading'
        : diffMinutes <= 60
        ? '🔥 Close to #1'
        : '💪 Keep pushing';

    final resetText = switch (_leaderboardPeriod) {
      LeaderboardPeriod.day => 'Today • resets at midnight',
      LeaderboardPeriod.week => 'This week • resets Monday',
      LeaderboardPeriod.month => 'This month • resets on the 1st',
      LeaderboardPeriod.all => 'All time • never resets',
    };

    final diffText = isLeading
        ? 'You are #1'
        : '${formatMinutes(diffMinutes)} behind #1 • -$percentBehind%';

    return Container(
      padding: EdgeInsets.all(isVerySmallPhone ? 12 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _showScopePicker,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.public,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${_scopeLabel()} ▼',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isVerySmallPhone ? 13 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: _showPeriodPicker,
                child: Text(
                  '${_periodLabel()} ▼',
                  style: TextStyle(
                    fontSize: isVerySmallPhone ? 12 : 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: isVerySmallPhone ? 24 : 28,
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your rank: #$_yourRank of $_participantCount',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isVerySmallPhone ? 15 : 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      rankingOff ? 'Show rankings is off' : statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isVerySmallPhone ? 12 : 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Your time',
                    style: TextStyle(
                      fontSize: isVerySmallPhone ? 10 : 11,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    formatMinutes(_yourRankMinutes),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isVerySmallPhone ? 15 : 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 7,
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              rankingOff
                  ? 'You are not visible in public rankings\n$resetText'
                  : '$diffText\n$resetText',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isVerySmallPhone ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestStatsCompactCard({
    required bool isVerySmallPhone,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(isVerySmallPhone ? 12 : 14),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.orange.withOpacity(0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔥 Streak',
                  style: TextStyle(
                    fontSize: isVerySmallPhone ? 14 : 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_bestStats.streakDays} days',
                  style: TextStyle(
                    fontSize: isVerySmallPhone ? 20 : 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _showGoalPicker,
                  child: Text(
                    'Goal: ${formatMinutes(_bestStats.dailyGoalMinutes)} / day',
                    style: TextStyle(
                      fontSize: isVerySmallPhone ? 11 : 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Best: ${_bestStats.bestStreakDays} days',
                  style: TextStyle(
                    fontSize: isVerySmallPhone ? 11 : 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Container(
            padding: EdgeInsets.all(isVerySmallPhone ? 12 : 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⭐ Best',
                  style: TextStyle(
                    fontSize: isVerySmallPhone ? 14 : 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                _bestRow(
                  'Day',
                  formatMinutes(_bestStats.bestDayMinutes),
                  isVerySmallPhone,
                ),
                const SizedBox(height: 5),

                _bestRow(
                  'Week',
                  formatMinutes(_bestStats.bestWeekMinutes),
                  isVerySmallPhone,
                ),
                const SizedBox(height: 5),

                _bestRow(
                  'Month',
                  formatMinutes(_bestStats.bestMonthMinutes),
                  isVerySmallPhone,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bestRow(
      String label,
      String value,
      bool isVerySmallPhone,
      ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isVerySmallPhone ? 11 : 12,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isVerySmallPhone ? 11 : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

    final dailyAverageMinutes = controller.dailyAverageUntilNowMinutes;
    final weeklyAverageMinutes = controller.weeklyAverageUntilNowMinutes;
    final monthlyAverageMinutes = controller.monthlyAverageUntilNowMinutes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Challenge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),


          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final rankText = _yourRank != null
                  ? '#$_yourRank in Prague this week'
                  : 'tracking my offline time';

              final timeText = formatMinutes(_yourRankMinutes);

              final message =
                  'I am $rankText with $timeText offline.\n\n'
                  'Can you beat me? 🔥\n\n'
                  'Join Offline Challenge.';

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
                'Offline today',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: titleFont,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _trackingEnabled ? 'Tracking automatically' : 'Start tracking',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isVerySmallPhone ? 11 : 12,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: sectionSpacing),
              Text(
                formatMinutes(_stats.todayMinutes),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: timerFont,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: sectionSpacing),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StatsDetailScreen(
                              title: 'Daily offline time',
                              currentLabel: 'Today',
                              currentMinutes: _stats.todayMinutes,
                              averageMinutes: dailyAverageMinutes,
                              chartValues: controller.dailyChartValues,
                              sessions: controller.loadHistorySync(),
                            ),
                          ),
                        );
                      },
                      child: _buildStatCard(
                        'Today',
                        _stats.todayMinutes,
                        dailyAverageMinutes,
                        titleFont: statTitleFont,
                        valueFont: statValueFont,
                        isVerySmallPhone: isVerySmallPhone,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StatsDetailScreen(
                              title: 'Weekly offline time',
                              currentLabel: 'This week',
                              currentMinutes: _stats.weekMinutes,
                              averageMinutes: weeklyAverageMinutes,
                              chartValues: controller.weeklyChartValues,
                              sessions: controller.loadHistorySync(),
                            ),
                          ),
                        );
                      },
                      child: _buildStatCard(
                        'Week',
                        _stats.weekMinutes,
                        weeklyAverageMinutes,
                        titleFont: statTitleFont,
                        valueFont: statValueFont,
                        isVerySmallPhone: isVerySmallPhone,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StatsDetailScreen(
                              title: 'Monthly offline time',
                              currentLabel: 'This month',
                              currentMinutes: _stats.monthMinutes,
                              averageMinutes: monthlyAverageMinutes,
                              chartValues: controller.monthlyChartValues,
                              sessions: controller.loadHistorySync(),
                            ),
                          ),
                        );
                      },
                      child: _buildStatCard(
                        'Month',
                        _stats.monthMinutes,
                        monthlyAverageMinutes,
                        titleFont: statTitleFont,
                        valueFont: statValueFont,
                        isVerySmallPhone: isVerySmallPhone,
                      ),
                    ),
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
                  onPressed: _trackingEnabled ? null : _startCollecting,
                  child: Text(
                    _trackingEnabled ? 'COLLECTING ENABLED' : 'START COLLECTING',
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                _trackingEnabled
                    ? 'Offline time will be collected automatically when your screen is off.'
                    : 'Start once. Then the app will collect screen-off offline time automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isVerySmallPhone ? 11 : 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}