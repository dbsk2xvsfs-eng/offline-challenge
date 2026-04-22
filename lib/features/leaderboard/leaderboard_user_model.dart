class LeaderboardUserModel {
  final String nickname;
  final String country;
  final String city;
  final int dayMinutes;
  final int weekMinutes;
  final int monthMinutes;
  final int allMinutes;
  final bool isYou;

  const LeaderboardUserModel({
    required this.nickname,
    required this.country,
    required this.city,
    required this.dayMinutes,
    required this.weekMinutes,
    required this.monthMinutes,
    required this.allMinutes,
    required this.isYou,
  });
}