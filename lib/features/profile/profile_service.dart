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
      );
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return ProfileModel.fromJson(decoded);
  }

  Future<void> saveProfile(ProfileModel profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
  }
}