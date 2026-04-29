import 'package:shared_preferences/shared_preferences.dart';

class DailyGoalService {
  static const String _key = 'daily_goal_minutes';

  Future<int> loadGoalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 120; // default 2 h
  }

  Future<void> saveGoalMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, minutes);
  }
}