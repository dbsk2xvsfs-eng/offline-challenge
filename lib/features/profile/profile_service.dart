import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'profile_model.dart';

class ProfileService {
  static const _profileKey = 'user_profile';

  Future<ProfileModel> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);

    if (raw == null || raw.isEmpty) {
      return const ProfileModel(
        nickname: '',
        city: '',
        country: '',
        showInRankings: true, // 🔥 default
      );
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    return ProfileModel(
      nickname: decoded['nickname'] ?? '',
      city: decoded['city'] ?? '',
      country: decoded['country'] ?? '',
      showInRankings: decoded['showInRankings'] ?? true,
    );
  }

  Future<void> saveProfile(ProfileModel profile) async {
    final prefs = await SharedPreferences.getInstance();

    final map = {
      'nickname': profile.nickname,
      'city': profile.city,
      'country': profile.country,
      'showInRankings': profile.showInRankings,
    };

    await prefs.setString(_profileKey, jsonEncode(map));
  }

  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
  }
}