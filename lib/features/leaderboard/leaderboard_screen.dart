import 'package:flutter/material.dart';

import 'leaderboard_filter.dart';
import 'leaderboard_service.dart';
import 'leaderboard_user_model.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardService service = LeaderboardService();

  LeaderboardScope selectedScope = LeaderboardScope.global;
  LeaderboardPeriod selectedPeriod = LeaderboardPeriod.week;

  final String yourCountry = 'CZ';
  final String yourCity = 'Prague';

  late List<LeaderboardUserModel> allUsers;

  @override
  void initState() {
    super.initState();
    allUsers = service.loadFakeUsers(
      yourNickname: 'You',
      yourCity: yourCity,
      yourCountry: yourCountry,
    );
  }

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
  Widget build(BuildContext context) {
    final users = service.filterUsers(
      users: allUsers,
      scope: selectedScope,
      period: selectedPeriod,
      yourCountry: yourCountry,
      yourCity: yourCity,
    );

    final youIndex = users.indexWhere((u) => u.isYou);
    final yourRank = youIndex >= 0 ? youIndex + 1 : null;

    final yourMinutes = youIndex >= 0
        ? service.minutesForPeriod(users[youIndex], selectedPeriod)
        : 0;

    final bestMinutes = users.isNotEmpty
        ? service.minutesForPeriod(users.first, selectedPeriod)
        : 0;

    final diffMinutes = bestMinutes - yourMinutes;
    final percentBehind = bestMinutes <= 0
        ? 0
        : ((diffMinutes / bestMinutes) * 100).round();

    final isLeading = yourRank == 1;

    final statusText = isLeading
        ? '🏆 You are leading'
        : diffMinutes <= 60
        ? '🔥 Close to #1'
        : '💪 Keep pushing';

    final diffText = isLeading
        ? 'You are #1'
        : '${formatMinutes(diffMinutes)} behind #1 • -$percentBehind%';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rankings'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chipSection(
              children: LeaderboardScope.values.map((scope) {
                return ChoiceChip(
                  label: Text(scopeLabel(scope)),
                  selected: selectedScope == scope,
                  onSelected: (_) {
                    setState(() {
                      selectedScope = scope;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 10),

            _chipSection(
              children: LeaderboardPeriod.values.map((period) {
                return ChoiceChip(
                  label: Text(periodLabel(period)),
                  selected: selectedPeriod == period,
                  onSelected: (_) {
                    setState(() {
                      selectedPeriod = period;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            if (yourRank != null)
              _YourRankCard(
                scope: scopeLabel(selectedScope),
                period: periodLabel(selectedPeriod),
                rank: yourRank,
                count: users.length,
                yourTime: formatMinutes(yourMinutes),
                statusText: statusText,
                diffText: diffText,
                resetText: resetLabel(selectedPeriod),
              ),

            const SizedBox(height: 14),

            Text(
              'Leaderboard',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
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
                  );
                },
              ),
            ),
          ],
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

class _YourRankCard extends StatelessWidget {
  final String scope;
  final String period;
  final int rank;
  final int count;
  final String yourTime;
  final String statusText;
  final String diffText;
  final String resetText;

  const _YourRankCard({
    required this.scope,
    required this.period,
    required this.rank,
    required this.count,
    required this.yourTime,
    required this.statusText,
    required this.diffText,
    required this.resetText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$scope • $period',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your rank: #$rank of $count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Your time',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    yourTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$diffText\n$resetText',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            ),
          ),
        ],
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

  const _LeaderboardUserTile({
    required this.rank,
    required this.name,
    required this.location,
    required this.time,
    required this.isYou,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isYou
        ? Theme.of(context).colorScheme.primaryContainer
        : Colors.grey.shade100;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 14,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: rank <= 3
                ? Colors.blue.shade100
                : Colors.grey.shade200,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isYou ? 'You' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isYou ? FontWeight.w900 : FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}