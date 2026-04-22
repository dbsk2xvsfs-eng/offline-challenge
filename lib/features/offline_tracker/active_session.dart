class ActiveSession {
  final bool isRunning;
  final DateTime? startedAt;

  const ActiveSession({
    required this.isRunning,
    this.startedAt,
  });

  ActiveSession copyWith({
    bool? isRunning,
    DateTime? startedAt,
    bool clearStartedAt = false,
  }) {
    return ActiveSession(
      isRunning: isRunning ?? this.isRunning,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isRunning': isRunning,
      'startedAt': startedAt?.toIso8601String(),
    };
  }

  factory ActiveSession.fromJson(Map<String, dynamic> json) {
    return ActiveSession(
      isRunning: json['isRunning'] ?? false,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'])
          : null,
    );
  }
}