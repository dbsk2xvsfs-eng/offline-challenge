class ProfileModel {
  final String nickname;
  final String city;
  final String country;

  const ProfileModel({
    required this.nickname,
    required this.city,
    required this.country,
  });

  ProfileModel copyWith({
    String? nickname,
    String? city,
    String? country,
  }) {
    return ProfileModel(
      nickname: nickname ?? this.nickname,
      city: city ?? this.city,
      country: country ?? this.country,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'city': city,
      'country': country,
    };
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      nickname: json['nickname'] ?? '',
      city: json['city'] ?? '',
      country: json['country'] ?? '',
    );
  }

  bool get isComplete =>
      nickname.trim().isNotEmpty &&
          city.trim().isNotEmpty &&
          country.trim().isNotEmpty;
}