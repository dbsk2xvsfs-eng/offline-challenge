import 'package:flutter/material.dart';

import 'leaderboard_filter.dart';
import 'leaderboard_service.dart';
import 'leaderboard_user_model.dart';
import '../profile/profile_service.dart';
import '../profile/profile_model.dart';

String flagEmoji(String countryCode) {
  final code = countryCode.toUpperCase();

  if (code.length != 2) return '🏳️';

  return code.codeUnits
      .map((c) => String.fromCharCode(127397 + c))
      .join();
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardService service = LeaderboardService();

  LeaderboardScope selectedScope = LeaderboardScope.global;
  LeaderboardPeriod selectedPeriod = LeaderboardPeriod.week;

  final ProfileService _profileService = ProfileService();

  ProfileModel? _profile;
  bool _loadingProfile = true;

  String get yourCountry => (_profile?.country.trim().isEmpty ?? true)
      ? 'UN'
      : _profile!.country.trim().toUpperCase();

  String get yourCity => (_profile?.city.trim().isEmpty ?? true)
      ? 'unknown'
      : _profile!.city.trim().toLowerCase();



  String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours == 0) return '$mins min';
    if (mins == 0) return '$hours h';
    return '$hours h $mins min';
  }

  String scopeLabel(LeaderboardScope scope) {
    switch (scope) {
      case LeaderboardScope.global:
        return 'Global';
      case LeaderboardScope.country:
        return 'Country';
      case LeaderboardScope.city:
        return 'City';
      case LeaderboardScope.friends:
        return 'Friends';
    }
  }

  String periodLabel(LeaderboardPeriod period) {
    switch (period) {
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

  String resetLabel(LeaderboardPeriod period) {
    switch (period) {
      case LeaderboardPeriod.day:
        return 'Resets at midnight';
      case LeaderboardPeriod.week:
        return 'Resets Monday';
      case LeaderboardPeriod.month:
        return 'Resets on the 1st';
      case LeaderboardPeriod.all:
        return 'Never resets';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.loadProfile();

    if (!mounted) return;

    setState(() {
      _profile = profile;
      _loadingProfile = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final originalMedia = MediaQuery.of(context);
    final h = originalMedia.size.height;
    final w = originalMedia.size.width;

    final compact = h < 860;
    final veryCompact = h < 780;

    final pagePadding = w < 380 ? 10.0 : 12.0;
    final gap = veryCompact ? 5.0 : 7.0;

    if (_loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return MediaQuery(
      data: originalMedia.copyWith(
        textScaler: const TextScaler.linear(0.88),
      ),
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: veryCompact ? 42 : 46,
          title: const Text('Rankings'),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pagePadding, 4, pagePadding, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chipSection(
                  children: LeaderboardScope.values.map((scope) {
                    return ChoiceChip(
                      label: Text(
                        scopeLabel(scope),
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: selectedScope == scope,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      onSelected: (_) {
                        setState(() {
                          selectedScope = scope;
                        });
                      },
                    );
                  }).toList(),
                ),

                SizedBox(height: gap),

                _chipSection(
                  children: LeaderboardPeriod.values.map((period) {
                    return ChoiceChip(
                      label: Text(
                        periodLabel(period),
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: selectedPeriod == period,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      onSelected: (_) {
                        setState(() {
                          selectedPeriod = period;
                        });
                      },
                    );
                  }).toList(),
                ),

                SizedBox(height: veryCompact ? 8 : 10),

                Text(
                  'Leaderboard',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                SizedBox(height: gap),

                Expanded(
                  child: StreamBuilder<List<LeaderboardUserModel>>(
                    stream: service.watchUsers(
                      scope: selectedScope,
                      period: selectedPeriod,
                      yourCountry: yourCountry,
                      yourCity: yourCity,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Leaderboard error: ${snapshot.error}'),
                        );
                      }

                      final rawUsers = snapshot.data ?? [];

                      final users = (_profile?.showInRankings ?? true)
                          ? rawUsers
                          : rawUsers.where((u) => !u.isYou).toList();

                      if (users.isEmpty) {
                        return const Center(
                          child: Text(
                            'Showing in rankings is off. For change go to profile.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      final youIndex = users.indexWhere((u) => u.isYou);
                      final yourRank = youIndex >= 0 ? youIndex + 1 : null;

                      final yourMinutes = youIndex >= 0
                          ? service.minutesForPeriod(
                        users[youIndex],
                        selectedPeriod,
                      )
                          : 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (yourRank != null)
                            Padding(
                              padding: EdgeInsets.only(bottom: gap),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.emoji_events_outlined,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Your rank: #$yourRank of ${users.length}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatMinutes(yourMinutes),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final user = users[index];
                                final rank = index + 1;
                                final minutes = service.minutesForPeriod(
                                  user,
                                  selectedPeriod,
                                );

                                return _LeaderboardUserTile(
                                  rank: rank,
                                  name: user.nickname,
                                  location: '${user.city}, ${user.country}',
                                  time: formatMinutes(minutes),
                                  isYou: user.isYou,
                                  compact: compact,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipSection({
    required List<Widget> children,
  }) {
    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: children,
      ),
    );
  }
}



class _LeaderboardUserTile extends StatelessWidget {
  final int rank;
  final String name;
  final String location;
  final String time;
  final bool isYou;
  final bool compact;

  const _LeaderboardUserTile({
    required this.rank,
    required this.name,
    required this.location,
    required this.time,
    required this.isYou,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isYou
        ? Theme.of(context).colorScheme.primaryContainer
        : Colors.grey.shade100;

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 6 : 8),
      padding: EdgeInsets.symmetric(
        vertical: compact ? 8 : 10,
        horizontal: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: compact ? 18 : 20,
            backgroundColor:
            rank <= 3 ? Colors.blue.shade100 : Colors.grey.shade200,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: compact ? 9 : 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${flagEmoji(location.split(', ').last)} $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: isYou ? FontWeight.w900 : FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}