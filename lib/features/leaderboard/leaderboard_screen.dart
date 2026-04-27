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
    }
  }

  String periodLabel(LeaderboardPeriod period) {
    switch (period) {
      case LeaderboardPeriod.day:
        return 'Day';
      case LeaderboardPeriod.week:
        return 'Week';
      case LeaderboardPeriod.month:
        return 'Month';
      case LeaderboardPeriod.all:
        return 'All';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rankings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your rank: #$yourRank',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        formatMinutes(
                          service.minutesForPeriod(
                            users[youIndex],
                            selectedPeriod,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final rank = index + 1;
                  final minutes = service.minutesForPeriod(user, selectedPeriod);

                  return Card(
                    color: user.isYou
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('$rank'),
                      ),
                      title: Text(
                        user.nickname,
                        style: TextStyle(
                          fontWeight: user.isYou
                              ? FontWeight.bold
                              : FontWeight.w600,
                        ),
                      ),
                      subtitle: Text('${user.city}, ${user.country}'),
                      trailing: Text(
                        formatMinutes(minutes),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}