enum DailySummaryPeriod {
  today,
  yesterday,
}

class NotificationSettingsModel {
  final bool dailyEnabled;
  final DailySummaryPeriod dailyPeriod;
  final int dailyHour;
  final int dailyMinute;

  final bool weeklyEnabled;
  final int weeklyDay; // 1 = Monday, 7 = Sunday
  final int weeklyHour;
  final int weeklyMinute;

  final bool monthlyEnabled;
  final int monthlyDay; // 1-28 for now
  final int monthlyHour;
  final int monthlyMinute;

  const NotificationSettingsModel({
    required this.dailyEnabled,
    required this.dailyPeriod,
    required this.dailyHour,
    required this.dailyMinute,
    required this.weeklyEnabled,
    required this.weeklyDay,
    required this.weeklyHour,
    required this.weeklyMinute,
    required this.monthlyEnabled,
    required this.monthlyDay,
    required this.monthlyHour,
    required this.monthlyMinute,
  });

  factory NotificationSettingsModel.defaults() {
    return const NotificationSettingsModel(
      dailyEnabled: false,
      dailyPeriod: DailySummaryPeriod.yesterday,
      dailyHour: 21,
      dailyMinute: 0,
      weeklyEnabled: false,
      weeklyDay: 7,
      weeklyHour: 18,
      weeklyMinute: 0,
      monthlyEnabled: false,
      monthlyDay: 1,
      monthlyHour: 20,
      monthlyMinute: 0,
    );
  }

  NotificationSettingsModel copyWith({
    bool? dailyEnabled,
    DailySummaryPeriod? dailyPeriod,
    int? dailyHour,
    int? dailyMinute,
    bool? weeklyEnabled,
    int? weeklyDay,
    int? weeklyHour,
    int? weeklyMinute,
    bool? monthlyEnabled,
    int? monthlyDay,
    int? monthlyHour,
    int? monthlyMinute,
  }) {
    return NotificationSettingsModel(
      dailyEnabled: dailyEnabled ?? this.dailyEnabled,
      dailyPeriod: dailyPeriod ?? this.dailyPeriod,
      dailyHour: dailyHour ?? this.dailyHour,
      dailyMinute: dailyMinute ?? this.dailyMinute,
      weeklyEnabled: weeklyEnabled ?? this.weeklyEnabled,
      weeklyDay: weeklyDay ?? this.weeklyDay,
      weeklyHour: weeklyHour ?? this.weeklyHour,
      weeklyMinute: weeklyMinute ?? this.weeklyMinute,
      monthlyEnabled: monthlyEnabled ?? this.monthlyEnabled,
      monthlyDay: monthlyDay ?? this.monthlyDay,
      monthlyHour: monthlyHour ?? this.monthlyHour,
      monthlyMinute: monthlyMinute ?? this.monthlyMinute,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dailyEnabled': dailyEnabled,
      'dailyPeriod': dailyPeriod.name,
      'dailyHour': dailyHour,
      'dailyMinute': dailyMinute,
      'weeklyEnabled': weeklyEnabled,
      'weeklyDay': weeklyDay,
      'weeklyHour': weeklyHour,
      'weeklyMinute': weeklyMinute,
      'monthlyEnabled': monthlyEnabled,
      'monthlyDay': monthlyDay,
      'monthlyHour': monthlyHour,
      'monthlyMinute': monthlyMinute,
    };
  }

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    return NotificationSettingsModel(
      dailyEnabled: json['dailyEnabled'] ?? false,
      dailyPeriod: json['dailyPeriod'] == 'today'
          ? DailySummaryPeriod.today
          : DailySummaryPeriod.yesterday,
      dailyHour: json['dailyHour'] ?? 21,
      dailyMinute: json['dailyMinute'] ?? 0,
      weeklyEnabled: json['weeklyEnabled'] ?? false,
      weeklyDay: json['weeklyDay'] ?? 7,
      weeklyHour: json['weeklyHour'] ?? 18,
      weeklyMinute: json['weeklyMinute'] ?? 0,
      monthlyEnabled: json['monthlyEnabled'] ?? false,
      monthlyDay: json['monthlyDay'] ?? 1,
      monthlyHour: json['monthlyHour'] ?? 20,
      monthlyMinute: json['monthlyMinute'] ?? 0,
    );
  }
}