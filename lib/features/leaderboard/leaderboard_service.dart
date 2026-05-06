import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'leaderboard_filter.dart';
import 'leaderboard_user_model.dart';

class LeaderboardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> getOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();

    var id = prefs.getString('leaderboard_user_id');

    if (id == null) {
      id = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('leaderboard_user_id', id);
    }

    return id;
  }

  Future<void> updateMyLeaderboardProfile({
    required String nickname,
    required String country,
    required String city,
  }) async {
    final userId = await getOrCreateUserId();

    await _db.collection('leaderboard').doc(userId).set({
      'nickname': nickname.trim().isEmpty ? 'Anonymous' : nickname.trim(),
      'country': country.trim().isEmpty ? 'UN' : country.trim().toUpperCase(),
      'city': city.trim().isEmpty ? 'unknown' : city.trim().toLowerCase(),
    }, SetOptions(merge: true));
  }

  Future<void> removeMeFromLeaderboard() async {
    final userId = await getOrCreateUserId();
    await _db.collection('leaderboard').doc(userId).delete();
  }

  Future<LeaderboardRankResult?> getMyRank({
    required LeaderboardScope scope,
    required LeaderboardPeriod period,
    required String yourCountry,
    required String yourCity,
  }) async {
    final myUserId = await getOrCreateUserId();

    final myDoc = await _db.collection('leaderboard').doc(myUserId).get();

    if (!myDoc.exists) return null;

    final myData = myDoc.data();
    if (myData == null) return null;

    String field;
    switch (period) {
      case LeaderboardPeriod.day:
        field = 'dayMinutes';
        break;
      case LeaderboardPeriod.week:
        field = 'weekMinutes';
        break;
      case LeaderboardPeriod.month:
        field = 'monthMinutes';
        break;
      case LeaderboardPeriod.all:
        field = 'allMinutes';
        break;
    }

    final myMinutes = (myData[field] ?? 0) as int;

    Query betterQuery = _db.collection('leaderboard');
    Query totalQuery = _db.collection('leaderboard');

    switch (scope) {
      case LeaderboardScope.global:
        break;

      case LeaderboardScope.country:
        betterQuery = betterQuery.where('country', isEqualTo: yourCountry);
        totalQuery = totalQuery.where('country', isEqualTo: yourCountry);
        break;

      case LeaderboardScope.city:
        betterQuery = betterQuery.where('city', isEqualTo: yourCity);
        totalQuery = totalQuery.where('city', isEqualTo: yourCity);
        break;

      case LeaderboardScope.friends:
        betterQuery = betterQuery.where(FieldPath.documentId, isEqualTo: myUserId);
        totalQuery = totalQuery.where(FieldPath.documentId, isEqualTo: myUserId);
        break;
    }

    betterQuery = betterQuery.where(field, isGreaterThan: myMinutes);

    final betterCount = await betterQuery.count().get();
    final totalCount = await totalQuery.count().get();

    final betterPlayers = betterCount.count ?? 0;
    final totalPlayers = totalCount.count ?? 0;

    return LeaderboardRankResult(
      rank: betterPlayers + 1,
      totalPlayers: totalPlayers,
      myMinutes: myMinutes,
    );
  }

  Future<void> uploadMyStats({
    required String nickname,
    required String country,
    required String city,
    required int dayMinutes,
    required int weekMinutes,
    required int monthMinutes,
    required int allMinutes,
  }) async {
    final userId = await getOrCreateUserId();

    await _db.collection('leaderboard').doc(userId).set({
      'nickname': nickname,
      'country': country,
      'city': city.trim().toLowerCase(),
      'dayMinutes': dayMinutes,
      'weekMinutes': weekMinutes,
      'monthMinutes': monthMinutes,
      'allMinutes': allMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<LeaderboardUserModel>> watchUsers({
    required LeaderboardScope scope,
    required LeaderboardPeriod period,
    required String yourCountry,
    required String yourCity,
  }) async* {
    final myUserId = await getOrCreateUserId();

    String field;
    switch (period) {
      case LeaderboardPeriod.day:
        field = 'dayMinutes';
        break;
      case LeaderboardPeriod.week:
        field = 'weekMinutes';
        break;
      case LeaderboardPeriod.month:
        field = 'monthMinutes';
        break;
      case LeaderboardPeriod.all:
        field = 'allMinutes';
        break;
    }

    Query query = _db.collection('leaderboard');

    // 🔥 FIRESTORE FILTRY
    switch (scope) {
      case LeaderboardScope.global:
        break;

      case LeaderboardScope.country:
        query = query.where('country', isEqualTo: yourCountry);
        break;

      case LeaderboardScope.city:
        query = query.where('city', isEqualTo: yourCity);
        break;

      case LeaderboardScope.friends:
      // zatím jen ty
        query = query.where('userId', isEqualTo: myUserId);
        break;
    }

    query = query.orderBy(field, descending: true).limit(50);

    yield* query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        return LeaderboardUserModel(
          userId: doc.id,
          nickname: data['nickname'] ?? 'Anonymous',
          country: data['country'] ?? '',
          city: data['city'] ?? '',
          dayMinutes: data['dayMinutes'] ?? 0,
          weekMinutes: data['weekMinutes'] ?? 0,
          monthMinutes: data['monthMinutes'] ?? 0,
          allMinutes: data['allMinutes'] ?? 0,
          isYou: doc.id == myUserId,
        );
      }).toList();
    });
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
      case LeaderboardScope.friends:
        result = result.where((u) => u.isYou).toList();
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

class LeaderboardRankResult {
  final int rank;
  final int totalPlayers;
  final int myMinutes;

  const LeaderboardRankResult({
    required this.rank,
    required this.totalPlayers,
    required this.myMinutes,
  });
}