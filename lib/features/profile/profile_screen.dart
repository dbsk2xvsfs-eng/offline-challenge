import 'package:flutter/material.dart';

import 'profile_model.dart';
import 'profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../offline_tracker/tracking_settings_service.dart';
import '../offline_tracker/native_tracking_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();

  final _nicknameController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();

  final TrackingSettingsService _trackingSettingsService =
  TrackingSettingsService();

  final NativeTrackingService _nativeTrackingService =
  NativeTrackingService();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _stopCollecting() async {
    await _trackingSettingsService.setTrackingEnabled(false);
    await _nativeTrackingService.stopTrackingService();
  }

  Future<void> _resetAllData() async {
    await _stopCollecting();
    final prefs = await SharedPreferences.getInstance();

    // vypnout collecting
    await prefs.setBool('collecting_enabled', false);
    await prefs.setBool('automatic_collecting_started', false);

    // vynulovat statistiky
    await prefs.remove('native_session_history');
    await prefs.remove('screen_off_started_at');

    // vynulovat notifikace
    await prefs.remove('notification_last_sent_daily');
    await prefs.remove('notification_last_sent_weekly');
    await prefs.remove('notification_last_sent_monthly');

    await prefs.remove('notification_settings');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Statistics reset and collecting stopped'),
      ),
    );

    setState(() {});
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.loadProfile();

    _nicknameController.text = profile.nickname;
    _cityController.text = profile.city;
    _countryController.text = profile.country;

    setState(() {
      _loading = false;
    });
  }

  Future<void> _confirmResetAllData() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset statistics?'),
        content: const Text(
          'This will delete all offline statistics and turn off collecting. '
              'Offline time tracking will stop until you start it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset and stop'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _resetAllData();
    }
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim();
    final city = _cityController.text.trim();
    final country = _countryController.text.trim();

    if (nickname.isEmpty || city.isEmpty || country.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill nickname, city and country'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final profile = ProfileModel(
      nickname: nickname,
      city: city,
      country: country,
    );

    await _profileService.saveProfile(profile);

    if (!mounted) return;

    setState(() {
      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved'),
      ),
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Nickname',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                child: Text(_saving ? 'Saving...' : 'Save profile'),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Reset statistics',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Delete stats and stop collecting'),
              onTap: _confirmResetAllData,
            ),

          ],
        ),
      ),
    );
  }
}