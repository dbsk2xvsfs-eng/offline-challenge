class BestStatsModel {
  final int bestDayMinutes;
  final int bestWeekMinutes;
  final int bestMonthMinutes;

  final int streakDays;
  final int bestStreakDays;
  final int dailyGoalMinutes;

  const BestStatsModel({
    required this.bestDayMinutes,
    required this.bestWeekMinutes,
    required this.bestMonthMinutes,
    required this.streakDays,
    required this.bestStreakDays,
    required this.dailyGoalMinutes,
  });
}