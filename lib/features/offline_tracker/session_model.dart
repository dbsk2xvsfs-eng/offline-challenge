class SessionModel {
  final DateTime startedAt;
  final int durationMinutes;

  const SessionModel({
    required this.startedAt,
    required this.durationMinutes,
  });

  Map<String, dynamic> toJson() {
    return {
      'startedAt': startedAt.toIso8601String(),
      'durationMinutes': durationMinutes,
    };
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      startedAt: DateTime.parse(json['startedAt']),
      durationMinutes: json['durationMinutes'] ?? 0,
    );
  }
}