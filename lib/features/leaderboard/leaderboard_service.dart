import 'leaderboard_filter.dart';
import 'leaderboard_user_model.dart';

class LeaderboardService {
  List<LeaderboardUserModel> loadFakeUsers({
    required String yourNickname,
    required String yourCity,
    required String yourCountry,
  }) {
    return [
      const LeaderboardUserModel(
        nickname: 'Anna',
        country: 'CZ',
        city: 'Prague',
        dayMinutes: 180,
        weekMinutes: 820,
        monthMinutes: 3200,
        allMinutes: 12400,
        isYou: false,
      ),
      const LeaderboardUserModel(
        nickname: 'Tom',
        country: 'CZ',
        city: 'Brno',
        dayMinutes: 150,
        weekMinutes: 760,
        monthMinutes: 2900,
        allMinutes: 11000,
        isYou: false,
      ),
      const LeaderboardUserModel(
        nickname: 'Luca',
        country: 'IT',
        city: 'Milan',
        dayMinutes: 210,
        weekMinutes: 910,
        monthMinutes: 3500,
        allMinutes: 13200,
        isYou: false,
      ),

      // 👇 TVŮJ UŽIVATEL PODLE PROFILU
      LeaderboardUserModel(
        nickname: yourNickname,
        country: yourCountry,
        city: yourCity,
        dayMinutes: 160,
        weekMinutes: 700,
        monthMinutes: 2800,
        allMinutes: 9800,
        isYou: true,
      ),

      const LeaderboardUserModel(
        nickname: 'Emma',
        country: 'DE',
        city: 'Berlin',
        dayMinutes: 120,
        weekMinutes: 640,
        monthMinutes: 2500,
        allMinutes: 9200,
        isYou: false,
      ),
      const LeaderboardUserModel(
        nickname: 'Sara',
        country: 'CZ',
        city: 'Prague',
        dayMinutes: 90,
        weekMinutes: 500,
        monthMinutes: 2100,
        allMinutes: 8600,
        isYou: false,
      ),
      const LeaderboardUserModel(
        nickname: 'David',
        country: 'CZ',
        city: 'Ostrava',
        dayMinutes: 60,
        weekMinutes: 450,
        monthMinutes: 1800,
        allMinutes: 7900,
        isYou: false,
      ),
    ];
  }

  int minutesForPeriod(
      LeaderboardUserModel user,
      LeaderboardPeriod period,
      ) {
    switch (period) {
      case LeaderboardPeriod.day:
        return user.dayMinutes;
      case LeaderboardPeriod.week:
        return user.weekMinutes;
      case LeaderboardPeriod.month:
        return user.monthMinutes;
      case LeaderboardPeriod.all:
        return user.allMinutes;
    }
  }

  List<LeaderboardUserModel> filterUsers({
    required List<LeaderboardUserModel> users,
    required LeaderboardScope scope,
    required LeaderboardPeriod period,
    required String yourCountry,
    required String yourCity,
  }) {
    List<LeaderboardUserModel> result = [...users];

    switch (scope) {
      case LeaderboardScope.global:
        break;
      case LeaderboardScope.country:
        result = result.where((u) => u.country == yourCountry).toList();
        break;
      case LeaderboardScope.city:
        result = result.where((u) => u.city == yourCity).toList();
        break;
    }

    result.sort((a, b) {
      final aMinutes = minutesForPeriod(a, period);
      final bMinutes = minutesForPeriod(b, period);
      return bMinutes.compareTo(aMinutes);
    });

    return result;
  }
}

LeaderboardUserModel? findYou(List<LeaderboardUserModel> users) {
  try {
    return users.firstWhere((u) => u.isYou);
  } catch (_) {
    return null;
  }
}